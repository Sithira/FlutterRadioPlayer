import 'package:flutter/material.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _flutterRadioPlayerPlugin = FlutterRadioPlayer();
  double volume = 0;

  @override
  void initState() {
    super.initState();
    _flutterRadioPlayerPlugin.initialize(
      [
        {
          "url": "https://s2-webradio.antenne.de/chillout?icy=https",
        },
        {
          "title": "SunFM - Sri Lanka",
          "artwork": "images/sample-cover.jpg",
          "url":
              "https://radio.lotustechnologieslk.net:2020/stream/sunfmgarden?icy=https",
        },
        {"url": "http://stream.riverradio.com:8000/wcvofm.aac"}
      ],
      true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () async {
                      await _flutterRadioPlayerPlugin.prevSource();
                    },
                    icon: const Icon(Icons.skip_previous_sharp),
                  ),
                  StreamBuilder(
                    stream: _flutterRadioPlayerPlugin.getPlaybackStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return IconButton(
                          onPressed: () {
                            if (snapshot.data!) {
                              _flutterRadioPlayerPlugin.pause();
                            } else {
                              _flutterRadioPlayerPlugin.play();
                            }
                          },
                          icon: !snapshot.data!
                              ? Icon(Icons.play_arrow)
                              : Icon(Icons.pause),
                          iconSize: 50.0,
                        );
                      }
                      return const Text("Player unavailable");
                    },
                  ),
                  IconButton(
                    onPressed: () async {
                      await _flutterRadioPlayerPlugin.nextSource();
                    },
                    icon: const Icon(Icons.skip_next_sharp),
                  ),
                ],
              ),
              StreamBuilder(
                stream: _flutterRadioPlayerPlugin.getNowPlayingStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data?.title != null) {
                    return Text("Now playing : ${snapshot.data?.title}");
                  }
                  return Text("N/A");
                },
              ),
              StreamBuilder(
                stream:
                    _flutterRadioPlayerPlugin.getDeviceVolumeChangedStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                        "Volume = ${snapshot.data?.volume.floor()} and IsMuted = ${snapshot.data?.isMuted}");
                  }
                  return Text("No Vol data");
                },
              ),
              FutureBuilder(
                future: _flutterRadioPlayerPlugin.getVolume(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Slider(
                      value: snapshot.data ?? 0,
                      min: 0,
                      max: 1,
                      onChanged: (value) {
                        setState(() {
                          volume = value;
                          _flutterRadioPlayerPlugin.setVolume(volume);
                        });
                      },
                    );
                  }
                  return Container();
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
