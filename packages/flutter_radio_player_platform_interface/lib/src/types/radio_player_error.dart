import 'radio_player_error_code.dart';

/// A playback error reported by the player.
class RadioPlayerError {
  /// Creates a [RadioPlayerError] with the given [code] and [message].
  const RadioPlayerError({required this.code, required this.message});

  /// The category of the error.
  final RadioPlayerErrorCode code;

  /// A human-readable description of the error, intended for diagnostics.
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadioPlayerError &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'RadioPlayerError(code: $code, message: $message)';
}
