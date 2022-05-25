import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';

import 'events/frp_player_events.dart';

class FRPPlayerControls extends StatefulWidget {
  final FlutterRadioPlayer flutterRadioPlayer;

  const FRPPlayerControls({Key? key, required this.flutterRadioPlayer})
      : super(key: key);

  @override
  State<FRPPlayerControls> createState() => _FRPPlayerControlsState();
}

class _FRPPlayerControlsState extends State<FRPPlayerControls> {
  String latestPlaybackStatus = "flutter_radio_stopped";
  String currentPlaying = "N/A";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.flutterRadioPlayer.frpEventStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          FRPPlayerEvents frpEvent =
              FRPPlayerEvents.fromJson(jsonDecode(snapshot.data as String));
          if (frpEvent.playbackStatus != null) {
            latestPlaybackStatus = frpEvent.playbackStatus!;
          }
          if (frpEvent.icyMetaDetails != null) {
            currentPlaying = frpEvent.icyMetaDetails!;
          }
          var statusIcon = const Icon(Icons.pause_circle_filled);
          switch (frpEvent.playbackStatus) {
            case "flutter_radio_playing":
              statusIcon = const Icon(Icons.pause_circle_filled);
              break;
            case "flutter_radio_paused":
              statusIcon = const Icon(Icons.play_circle_filled);
              break;
            case "flutter_radio_loading":
              statusIcon = const Icon(Icons.refresh_rounded);
              break;
            case "flutter_radio_stopped":
              statusIcon = const Icon(Icons.play_circle_filled);
              break;
          }
          return latestPlaybackStatus == "flutter_radio_stopped"
              ? ElevatedButton(
                  onPressed: () async {
                    await FlutterRadioPlayer.addMedia();
                    await FlutterRadioPlayer.initPeriodicMetaData();
                  },
                  child: const Text("Add sources"),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                          "Now playing: $currentPlaying",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.0,
                            fontFamily: 'Roboto',
                            color: Color(0xFF212121),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () async {
                                widget.flutterRadioPlayer.previous();
                                resetNowPlayingInfo();
                              },
                              icon: const Icon(Icons.skip_previous),
                            ),
                            IconButton(
                              onPressed: () async {
                                widget.flutterRadioPlayer.playOrPause();
                                resetNowPlayingInfo();
                              },
                              icon: statusIcon,
                            ),
                            IconButton(
                              onPressed: () async {
                                widget.flutterRadioPlayer.stop();
                                resetNowPlayingInfo();
                              },
                              icon: const Icon(Icons.stop_circle_outlined),
                            ),
                            IconButton(
                              onPressed: () async {
                                widget.flutterRadioPlayer.next();
                                resetNowPlayingInfo();
                              },
                              icon: const Icon(Icons.skip_next),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
        } else if (latestPlaybackStatus == "flutter_radio_stopped") {
          return ElevatedButton(
            onPressed: () async {
              await FlutterRadioPlayer.addMedia();
              await FlutterRadioPlayer.initPeriodicMetaData();
            },
            child: const Text("Add sources"),
          );
        }
        return const Text("Determining state ...");
      },
    );
  }

  void resetNowPlayingInfo() {
    currentPlaying = "N/A";
  }
}
