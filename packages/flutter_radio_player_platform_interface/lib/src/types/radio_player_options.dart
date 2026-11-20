import 'package:flutter/foundation.dart';

import 'unset.dart';

/// Options of the shared player. They change only through `setOptions`,
/// which replaces all of them.
@immutable
class RadioPlayerOptions {
  /// Creates options; the defaults suit a typical radio app.
  const RadioPlayerOptions({
    this.wrapAround = true,
    this.reconnect = const ReconnectPolicy(),
    this.android = const AndroidOptions(),
  });

  /// Whether `next` and `previous` wrap at the ends of the list. When `false`
  /// they do nothing there and the matching lock-screen button is disabled.
  final bool wrapAround;

  /// How long to keep reconnecting after a retryable failure.
  final ReconnectPolicy reconnect;

  /// Android-only options; ignored on iOS.
  final AndroidOptions android;

  /// Returns a copy with the given fields replaced.
  RadioPlayerOptions copyWith({
    bool? wrapAround,
    ReconnectPolicy? reconnect,
    AndroidOptions? android,
  }) {
    return RadioPlayerOptions(
      wrapAround: wrapAround ?? this.wrapAround,
      reconnect: reconnect ?? this.reconnect,
      android: android ?? this.android,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadioPlayerOptions &&
          wrapAround == other.wrapAround &&
          reconnect == other.reconnect &&
          android == other.android;

  @override
  int get hashCode => Object.hash(wrapAround, reconnect, android);

  @override
  String toString() =>
      'RadioPlayerOptions(wrapAround: $wrapAround, '
      'reconnect: $reconnect, android: $android)';
}

/// Reconnect behaviour after a retryable failure (`network`, `timeout`,
/// `httpStatus` 5xx, `unknown`). The backoff is fixed: 1 s doubling to 30 s.
@immutable
class ReconnectPolicy {
  /// Keeps reconnecting for [giveUpAfter]; then the status becomes `error`.
  const ReconnectPolicy({this.giveUpAfter = const Duration(minutes: 5)});

  /// Never reconnect: a failure sets the status to `error` at once.
  static const none = ReconnectPolicy(giveUpAfter: Duration.zero);

  /// How long to keep trying. Clamped to 9 minutes on Android.
  final Duration giveUpAfter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReconnectPolicy && giveUpAfter == other.giveUpAfter;

  @override
  int get hashCode => giveUpAfter.hashCode;

  @override
  String toString() => 'ReconnectPolicy(giveUpAfter: $giveUpAfter)';
}

/// Android-only options.
@immutable
class AndroidOptions {
  /// Creates Android options.
  const AndroidOptions({this.stopOnTaskRemoved = true, this.notificationIcon});

  /// Whether swiping the app away from recents stops playback.
  final bool stopOnTaskRemoved;

  /// Drawable or mipmap resource name of the notification small icon. An
  /// unresolved name falls back to the plugin's own icon.
  final String? notificationIcon;

  /// Returns a copy with the given fields replaced. Pass `null` to clear
  /// [notificationIcon].
  AndroidOptions copyWith({
    bool? stopOnTaskRemoved,
    Object? notificationIcon = unset,
  }) {
    return AndroidOptions(
      stopOnTaskRemoved: stopOnTaskRemoved ?? this.stopOnTaskRemoved,
      notificationIcon: notificationIcon == unset
          ? this.notificationIcon
          : notificationIcon as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AndroidOptions &&
          stopOnTaskRemoved == other.stopOnTaskRemoved &&
          notificationIcon == other.notificationIcon;

  @override
  int get hashCode => Object.hash(stopOnTaskRemoved, notificationIcon);

  @override
  String toString() =>
      'AndroidOptions(stopOnTaskRemoved: $stopOnTaskRemoved, '
      'notificationIcon: $notificationIcon)';
}
