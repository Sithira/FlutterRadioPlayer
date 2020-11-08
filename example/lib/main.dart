import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_radio_player_example/test_page.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  var playerState = FlutterRadioPlayer.flutter_radio_paused;

  var volume = 0.8;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;
  final List<Widget> _children = [
    new MyApp(),
  ];

  FlutterRadioPlayer _flutterRadioPlayer = new FlutterRadioPlayer();

  @override
  void initState() {
    super.initState();
    initRadioService();
  }

  Future<void> initRadioService() async {
    try {
      await _flutterRadioPlayer.init(
          "Flutter Radio Example", "Live", "http://perseus.shoutca.st:9899/stream?type=http&nocache=1906", "false");
    } on PlatformException {
      print("Exception occurred while trying to register the services.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Radio Player Example'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              StreamBuilder(
                  stream: _flutterRadioPlayer.isPlayingStream,
                  initialData: widget.playerState,
                  builder:
                      (BuildContext context, AsyncSnapshot<String> snapshot) {
                    String returnData = snapshot.data;
                    print("object data: " + returnData);
                    switch (returnData) {
                      case FlutterRadioPlayer.flutter_radio_stopped:
                        return RaisedButton(
                            child: Text("Start listening now"),
                            onPressed: () async {
                              await initRadioService();
                            });
                        break;
                      case FlutterRadioPlayer.flutter_radio_loading:
                        return Text("Loading stream...");
                      case FlutterRadioPlayer.flutter_radio_error:
                        return RaisedButton(
                            child: Text("Retry ?"),
                            onPressed: () async {
                              await initRadioService();
                            });
                        break;
                      default:
                        return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              IconButton(
                                  onPressed: () async {
                                    print("button press data: " +
                                        snapshot.data.toString());
                                    await _flutterRadioPlayer.playOrPause();
                                  },
                                  icon: snapshot.data ==
                                          FlutterRadioPlayer
                                              .flutter_radio_playing
                                      ? Icon(Icons.pause)
                                      : Icon(Icons.play_arrow)),
                              IconButton(
                                  onPressed: () async {
                                    await _flutterRadioPlayer.stop();
                                  },
                                  icon: Icon(Icons.stop))
                            ]);
                        break;
                    }
                  }),
              Slider(
                  value: widget.volume,
                  min: 0,
                  max: 1.0,
                  onChanged: (value) => setState(() {
                        widget.volume = value;
                        _flutterRadioPlayer.setVolume(widget.volume);
                      })),
              Text("Volume: " + (widget.volume * 100).toStringAsFixed(0)),
              SizedBox(
                height: 15,
              ),
              Text("Metadata Track "),
              StreamBuilder<String>(
                  initialData: "",
                  stream: _flutterRadioPlayer.metaDataStream,
                  builder: (context, snapshot) {
                    return Text(snapshot.data);
                  }),
              RaisedButton(child: Text("Change URL"), onPressed: () async {
                _flutterRadioPlayer.setUrl("http://209.133.216.3:7018/;stream.mp3", "false",);
              })
            ],
          ),
        ),
        bottomNavigationBar: new BottomNavigationBar(
            currentIndex: this._currentIndex,
            onTap: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              BottomNavigationBarItem(
                  icon: new Icon(Icons.home), title: new Text('Home')),
              BottomNavigationBarItem(
                  icon: new Icon(Icons.pages), title: new Text('Second Page'))
            ]),
      ),
    );
  }
}
