import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:material_ui/material_ui.dart';

const stations = [
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

final player = FlutterRadioPlayer.instance;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    player.setSources(stations);
  }

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
      home: Scaffold(
        body: SafeArea(
          child: RadioPlayerBuilder(
            builder: (context, state) => PlayerView(state: state),
          ),
        ),
      ),
    );
  }
}

class PlayerView extends StatelessWidget {
  const PlayerView({super.key, required this.state});

  final RadioPlayerState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final station = state.currentSource?.title ?? 'Live Radio';
    final error = state.error;

    return Column(
      children: [
        SizedBox(
          height: 4,
          child: state.isLoading ? const LinearProgressIndicator() : null,
        ),
        const SizedBox(height: 28),
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(Icons.radio, size: 80, color: colors.primary),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                state.nowPlaying?.title ?? station,
                style: text.titleLarge,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                station,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.isReconnecting
                      ? 'Reconnecting: ${error.message}'
                      : '${error.code.name}: ${error.message}',
                  style: TextStyle(color: colors.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 36,
              onPressed: player.previous,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            const SizedBox(width: 16),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(20),
              ),
              onPressed: player.playOrPause,
              child: Icon(
                state.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 40,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 36,
              onPressed: player.next,
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Icon(Icons.volume_down_rounded, color: colors.onSurfaceVariant),
              Expanded(
                child: Slider(value: state.volume, onChanged: player.setVolume),
              ),
              Icon(Icons.volume_up_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  'STATIONS',
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              for (final (index, source) in state.sources.indexed)
                _StationTile(
                  source: source,
                  active: index == state.currentIndex,
                  onTap: () => player.play(index: index),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({
    required this.source,
    required this.active,
    required this.onTap,
  });

  final RadioSource source;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: active,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.3),
      leading: CircleAvatar(
        backgroundColor: active
            ? colors.primary
            : colors.surfaceContainerHighest,
        child: Icon(
          active ? Icons.equalizer_rounded : Icons.radio_rounded,
          color: active ? colors.onPrimary : colors.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(source.title ?? source.url),
      onTap: onTap,
    );
  }
}
