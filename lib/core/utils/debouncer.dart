import 'dart:async';

/// A tiny debouncer that defers [action] until [delay] has elapsed since
/// the last call. Useful for search inputs where each keystroke should not
/// trigger a full filter pass — instead the cubit is notified once the user
/// stops typing.
///
/// Usage:
///
/// ```dart
/// final _debouncer = Debouncer();
///
/// TextField(
///   onChanged: (value) => _debouncer(() => cubit.search(value)),
/// )
///
/// @override
/// void dispose() {
///   _debouncer.dispose();
///   super.dispose();
/// }
/// ```
class Debouncer {

  Debouncer({this.delay = const Duration(milliseconds: 250)});
  final Duration delay;
  Timer? _timer;

  /// Schedules [action] to run after [delay]. Each call resets the timer.
  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any pending action. Call from `State.dispose` to avoid leaks.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}