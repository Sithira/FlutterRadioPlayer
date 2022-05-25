import 'package:flutter/material.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';

class FRPSourceList extends StatelessWidget {
  final FlutterRadioPlayer flutterRadioPlayer;

  const FRPSourceList({Key? key, required this.flutterRadioPlayer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
      ),
      margin: const EdgeInsets.only(top: 10),
      child: Row(
        children: [

        ],
      ),
    );
  }
}
