import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:material_ui/material_ui.dart';

final player = FlutterRadioPlayer.instance;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  player.setSources(const [
    RadioSource(
      url: 'https://s2-webradio.antenne.de/chillout?icy=https',
      title: 'Antenne Chillout',
    ),
    RadioSource(
      url: 'https://radio.lotustechnologieslk.net:2020/stream/sunfmgarden?icy=https',
      title: 'SunFM - Sri Lanka',
    ),
  ]);
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
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Radio Player')),
        body: RadioPlayerBuilder(
          builder: (context, state) => Column(
            children: [
              if (state.isLoading) const LinearProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                state.nowPlaying?.title ?? state.currentSource?.title ?? '',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (state.error case final error?)
                Text(
                  error.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              IconButton(
                iconSize: 48,
                icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: player.playOrPause,
              ),
              Slider(value: state.volume, onChanged: player.setVolume),
              for (final (index, source) in state.sources.indexed)
                ListTile(
                  title: Text(source.title ?? source.url),
                  selected: index == state.currentIndex,
                  onTap: () => player.play(index: index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
