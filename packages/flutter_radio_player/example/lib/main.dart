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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Radio Player')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StreamBuilder<NowPlayingInfo>(
            stream: _player.nowPlayingStream,
            builder: (context, snapshot) {
              final title = snapshot.data?.title ?? 'No track info';
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              );
            },
          ),
          StreamBuilder<bool>(
            stream: _player.isPlayingStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 36,
                    onPressed: _player.previousSource,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton(
                    iconSize: 48,
                    onPressed: () =>
                        isPlaying ? _player.pause() : _player.play(),
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  IconButton(
                    iconSize: 36,
                    onPressed: _player.nextSource,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                const Icon(Icons.volume_down_rounded),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (value) {
                      setState(() => _volume = value);
                      _player.setVolume(value);
                    },
                  ),
                ),
                const Icon(Icons.volume_up_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
