import 'package:flutter/material.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_radio_player/models/frp_source_modal.dart';
import 'package:flutter_radio_player_example/frp_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterRadioPlayer _flutterRadioPlayer = FlutterRadioPlayer();

  final FRPSource frpSource = FRPSource(
    mediaSources: <MediaSources>[
      MediaSources(
        url: "https://puma.streemlion.com:3540/stream",
        description: "Triple Threat FM Radio",
        isPrimary: true,
        title: "Triple Threat FM Radio",
        isAac: true,
      ),
      MediaSources(
        url: "https://radio.lotustechnologieslk.net:2020/stream/hirufmgarden",
        description: "Hiru FM Sri Lanka",
        isPrimary: false,
        title: "HiruFM",
        isAac: false,
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _flutterRadioPlayer.initPlayer();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Radio Player'),
        ),
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(5),
                child: Column(
                  children: [
                    FRPlayer(
                      flutterRadioPlayer: _flutterRadioPlayer,
                      frpSource: frpSource,
                      useIcyData: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
