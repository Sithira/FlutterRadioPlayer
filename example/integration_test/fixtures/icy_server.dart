import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One request received by [IcyServer].
class IcyRequest {
  IcyRequest(this.path, this.headers, this.receivedAt);

  final String path;

  /// Request headers with lower-case names.
  final Map<String, String> headers;
  final DateTime receivedAt;
}

/// In-process Icecast-style stream server for integration tests.
///
/// Serves an endless silent MP3 (MPEG-1 Layer III, 128 kbit/s, 44.1 kHz,
/// mono) at real-time rate on `127.0.0.1`. A client that sends
/// `Icy-MetaData: 1` gets `icy-metaint` framing with the current
/// [title] as `StreamTitle`.
class IcyServer {
  IcyServer._(this._server);

  static const int bytesPerSecond = 16000;
  static const int metaInterval = 16000;
  static const Duration _tick = Duration(milliseconds: 100);

  static final Uint8List _frame = _silentFrame();

  final HttpServer _server;
  final List<Socket> _streams = [];
  final List<IcyRequest> _requests = [];
  final Stopwatch _clock = Stopwatch()..start();

  String _title = '';
  int _status = HttpStatus.ok;
  Duration _startDelay = Duration.zero;
  bool _clockTitles = false;

  /// Starts a server on a free loopback port.
  static Future<IcyServer> start({String title = 'Test Title'}) async {
    final server = IcyServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    server._title = title;
    server._server.listen(server._handle);
    return server;
  }

  int get port => _server.port;

  /// Stream URL for [path], e.g. `http://127.0.0.1:port/stream`.
  String url([String path = '/stream']) => 'http://127.0.0.1:$port$path';

  String get title => _title;

  /// Title sent in the next metadata block of every open stream.
  void setTitle(String title) => _title = title;

  /// When on, each metadata block carries `T+<seconds since start>` instead
  /// of [title], so a test can tell live audio from buffered audio.
  void setClockTitles(bool enabled) => _clockTitles = enabled;

  /// Status for new requests: 200 streams, anything else replies with that
  /// status and an empty body.
  void setStatus(int status) => _status = status;

  /// Delay before new requests get their response headers.
  void setStartDelay(Duration delay) => _startDelay = delay;

  /// Number of requests received so far.
  int get requestCount => _requests.length;

  /// Every request received, oldest first.
  List<IcyRequest> get requests => List.unmodifiable(_requests);

  /// Headers of the latest request, or an empty map before the first one.
  Map<String, String> get lastHeaders =>
      _requests.isEmpty ? const {} : _requests.last.headers;

  /// Number of streams currently being served.
  int get openStreams => _streams.length;

  /// Drops every open stream without a clean end, like a network failure.
  void dropConnections() {
    for (final socket in List.of(_streams)) {
      socket.destroy();
    }
    _streams.clear();
  }

  Future<void> close() async {
    dropConnections();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final headers = <String, String>{};
    request.headers.forEach((name, values) {
      headers[name.toLowerCase()] = values.join(', ');
    });
    _requests.add(IcyRequest(request.uri.path, headers, DateTime.now()));

    if (_startDelay > Duration.zero) await Future<void>.delayed(_startDelay);

    final response = request.response;
    if (_status != HttpStatus.ok) {
      response.statusCode = _status;
      await response.close();
      return;
    }

    final wantsMetadata = headers['icy-metadata'] == '1';
    response
      ..statusCode = HttpStatus.ok
      ..persistentConnection = false
      ..contentLength = -1;
    response.headers
      ..chunkedTransferEncoding = false
      ..contentType = ContentType('audio', 'mpeg')
      ..set('icy-name', 'IcyServer')
      ..set('cache-control', 'no-cache');
    if (wantsMetadata) response.headers.set('icy-metaint', '$metaInterval');

    final socket = await response.detachSocket();
    _streams.add(socket);
    unawaited(_pump(socket, wantsMetadata));
  }

  Future<void> _pump(Socket socket, bool withMetadata) async {
    final chunkBytes = bytesPerSecond * _tick.inMilliseconds ~/ 1000;
    var frameOffset = 0;
    var untilMetadata = metaInterval;
    var open = true;
    unawaited(
      socket.done.then((_) => open = false, onError: (_) => open = false),
    );

    while (open && _streams.contains(socket)) {
      final out = BytesBuilder(copy: false);
      var audioLeft = chunkBytes;
      while (audioLeft > 0) {
        final take = [
          audioLeft,
          _frame.length - frameOffset,
          if (withMetadata) untilMetadata,
        ].reduce((a, b) => a < b ? a : b);
        out.add(Uint8List.sublistView(_frame, frameOffset, frameOffset + take));
        frameOffset = (frameOffset + take) % _frame.length;
        audioLeft -= take;
        if (withMetadata) {
          untilMetadata -= take;
          if (untilMetadata == 0) {
            out.add(_metadataBlock());
            untilMetadata = metaInterval;
          }
        }
      }
      try {
        socket.add(out.takeBytes());
        await socket.flush();
      } catch (_) {
        break;
      }
      await Future<void>.delayed(_tick);
    }
    _streams.remove(socket);
  }

  Uint8List _metadataBlock() {
    final text = _clockTitles ? 'T+${_clock.elapsed.inSeconds}' : _title;
    final payload = utf8.encode("StreamTitle='$text';");
    final blocks = (payload.length + 15) ~/ 16;
    final block = Uint8List(1 + blocks * 16);
    block[0] = blocks;
    block.setRange(1, 1 + payload.length, payload);
    return block;
  }

  static Uint8List _silentFrame() {
    const frameLength = 144 * 128000 ~/ 44100;
    return Uint8List(frameLength)
      ..[0] = 0xFF
      ..[1] = 0xFB
      ..[2] = 0x90
      ..[3] = 0xC4;
  }
}
