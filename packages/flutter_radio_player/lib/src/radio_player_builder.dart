import 'package:flutter/widgets.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

import 'flutter_radio_player.dart';

/// Builds a widget from the state of [FlutterRadioPlayer.instance].
///
/// The first frame uses the current state, so there is never a blank frame.
/// Rebuilds on every distinct state, or only when [buildWhen] returns `true`.
class RadioPlayerBuilder extends StatefulWidget {
  /// Creates a [RadioPlayerBuilder].
  const RadioPlayerBuilder({super.key, required this.builder, this.buildWhen});

  /// Builds the widget for a state.
  final Widget Function(BuildContext context, RadioPlayerState state) builder;

  /// Decides whether a change from `previous` (the last state seen) to
  /// `current` rebuilds. Rebuilds on every change when `null`.
  final bool Function(RadioPlayerState previous, RadioPlayerState current)?
  buildWhen;

  @override
  State<RadioPlayerBuilder> createState() => _RadioPlayerBuilderState();
}

class _RadioPlayerBuilderState extends State<RadioPlayerBuilder> {
  final _player = FlutterRadioPlayer.instance;
  late RadioPlayerState _seen;
  late RadioPlayerState _built;

  @override
  void initState() {
    super.initState();
    _seen = _built = _player.state;
    _player.addListener(_onChanged);
  }

  @override
  void dispose() {
    _player.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final current = _player.state;
    final previous = _seen;
    _seen = current;
    if (widget.buildWhen?.call(previous, current) ?? true) {
      setState(() => _built = current);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _built);
}
