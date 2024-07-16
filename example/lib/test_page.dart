import 'package:flutter/material.dart';

class TestPage extends StatefulWidget {
  @override
  _TestPage createState() => _TestPage();
}

class _TestPage extends State<TestPage> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(title: const Text('Flutter Radio Player - Page Two')),
      body: Center(
        child: Text('dssas'),
      ),
    ));
  }
}
