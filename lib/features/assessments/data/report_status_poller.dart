import 'dart:async';

/// Repeats [check] on a schedule until cancelled or capped (specs/003-report-status-states).
///
/// Default schedule: every 5 s for the first 3 minutes, then every 30 s, stopping at 30 minutes.
/// Checks never overlap: the next one is scheduled only after the previous one finishes. A check
/// that throws is reported through [onError] and the schedule continues.
class ReportStatusPoller<T> {
  ReportStatusPoller({
    required this.check,
    required this.onResult,
    this.onError,
    this.onCapped,
    Duration Function(Duration elapsed)? interval,
    this.cap = const Duration(minutes: 30),
    Timer Function(Duration, void Function())? createTimer,
    DateTime Function()? now,
  })  : _interval = interval ?? defaultInterval,
        _createTimer = createTimer ?? Timer.new,
        _now = now ?? DateTime.now;

  /// Fixed-interval variant, used for the Premium report (every 10 s for up to 5 minutes).
  ReportStatusPoller.fixed({
    required Duration every,
    required Duration cap,
    required Future<T> Function() check,
    required void Function(T) onResult,
    void Function(Object)? onError,
    void Function()? onCapped,
    Timer Function(Duration, void Function())? createTimer,
    DateTime Function()? now,
  }) : this(
          check: check,
          onResult: onResult,
          onError: onError,
          onCapped: onCapped,
          interval: (_) => every,
          cap: cap,
          createTimer: createTimer,
          now: now,
        );

  static const slowAfter = Duration(minutes: 3);

  static Duration defaultInterval(Duration elapsed) =>
      elapsed < slowAfter ? const Duration(seconds: 5) : const Duration(seconds: 30);

  final Future<T> Function() check;
  final void Function(T) onResult;
  final void Function(Object)? onError;

  /// Called once when the cap is reached without the poller being cancelled.
  final void Function()? onCapped;
  final Duration cap;
  final Duration Function(Duration elapsed) _interval;
  final Timer Function(Duration, void Function()) _createTimer;
  final DateTime Function() _now;

  DateTime? _startedAt;
  Timer? _timer;
  bool _running = false;
  bool _inFlight = false;

  bool get isRunning => _running;

  Duration get elapsed => _startedAt == null ? Duration.zero : _now().difference(_startedAt!);

  /// True once the poller has been running for [slowAfter] ("Taking longer than usual").
  bool get isSlow => _running && elapsed >= slowAfter;

  void start() {
    if (_running) return;
    _running = true;
    _startedAt = _now();
    _scheduleNext();
  }

  void cancel() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleNext() {
    if (!_running || _inFlight) return;
    final next = _interval(elapsed);
    if (elapsed + next > cap) {
      cancel();
      onCapped?.call();
      return;
    }
    _timer = _createTimer(next, _tick);
  }

  Future<void> _tick() async {
    if (!_running || _inFlight) return;
    _inFlight = true;
    try {
      final result = await check();
      if (_running) onResult(result);
    } catch (e) {
      if (_running) onError?.call(e);
    } finally {
      _inFlight = false;
    }
    _scheduleNext();
  }
}
