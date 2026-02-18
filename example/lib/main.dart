import 'package:flutter/material.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';

const _sources = [
  RadioSource(
    url: 'https://s2-webradio.antenne.de/chillout?icy=https',
    title: 'Antenne Chillout',
  ),
  RadioSource(
    url: 'https://radio.lotustechnologieslk.net:2020/stream/sunfmgarden?icy=https',
    title: 'SunFM - Sri Lanka',
    artwork: 'images/sample-cover.jpg',
  ),
  RadioSource(
    url: 'http://stream.riverradio.com:8000/wcvofm.aac',
    title: 'River Radio',
  ),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Radio Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const PlayerScreen(),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _player = FlutterRadioPlayer();
  int _currentSourceIndex = 0;
  double _volume = 0.5;

  @override
  void initState() {
    super.initState();
    _player.initialize(_sources, playWhenReady: true);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _onSourceTap(int index) {
    setState(() => _currentSourceIndex = index);
    _player.jumpToSourceAtIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Artwork
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.radio,
                size: 80,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Now playing title
            StreamBuilder<NowPlayingInfo>(
              stream: _player.nowPlayingStream,
              builder: (context, snapshot) {
                final title = snapshot.data?.title ??
                    _sources[_currentSourceIndex].title ??
                    'Unknown Station';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sources[_currentSourceIndex].title ?? 'Live Radio',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Transport controls
            StreamBuilder<bool>(
              stream: _player.isPlayingStream,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 36,
                      onPressed: () {
                        final prev = (_currentSourceIndex - 1 + _sources.length) %
                            _sources.length;
                        _onSourceTap(prev);
                      },
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(20),
                      ),
                      onPressed: () =>
                          isPlaying ? _player.pause() : _player.play(),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      iconSize: 36,
                      onPressed: () {
                        final next =
                            (_currentSourceIndex + 1) % _sources.length;
                        _onSourceTap(next);
                      },
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Volume slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Icon(Icons.volume_down_rounded,
                      color: colorScheme.onSurfaceVariant),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      onChanged: (value) {
                        setState(() => _volume = value);
                        _player.setVolume(value);
                      },
                    ),
                  ),
                  Icon(Icons.volume_up_rounded,
                      color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),

            const Spacer(),

            // Source list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      'STATIONS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                    ),
                  ),
                  ...List.generate(_sources.length, (index) {
                    final source = _sources[index];
                    final isActive = index == _currentSourceIndex;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: isActive,
                      selectedTileColor:
                          colorScheme.primaryContainer.withValues(alpha: 0.3),
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        child: Icon(
                          isActive
                              ? Icons.equalizer_rounded
                              : Icons.radio_rounded,
                          color: isActive
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                      title: Text(source.title ?? source.url),
                      subtitle: isActive
                          ? Text('Now playing',
                              style: TextStyle(color: colorScheme.primary))
                          : null,
                      onTap: () => _onSourceTap(index),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
