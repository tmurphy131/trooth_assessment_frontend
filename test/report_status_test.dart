import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trooth_assessment/features/assessments/data/report_status_poller.dart';
import 'package:trooth_assessment/features/assessments/models/report_status.dart';

/// Timer factory the test drives by hand.
class FakeTimers {
  final scheduled = <Duration>[];
  final _pending = <void Function()>[];
  Timer create(Duration d, void Function() cb) {
    scheduled.add(d);
    _pending.add(cb);
    return _FakeTimer(() => _pending.remove(cb));
  }

  bool get hasPending => _pending.isNotEmpty;

  /// Fire the next scheduled callback and let its async work finish.
  Future<void> fire() async {
    final cb = _pending.removeAt(0);
    cb();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this._onCancel);
  final void Function() _onCancel;
  bool _active = true;
  @override
  void cancel() {
    _active = false;
    _onCancel();
  }

  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
}

void main() {
  group('ReportStatus.fromJson', () {
    ReportPhase phase(Map<String, dynamic> j) => ReportStatus.fromJson(j).phase;

    test('maps status values', () {
      expect(phase({'status': 'done'}), ReportPhase.done);
      expect(phase({'status': 'processing', 'has_scores': true}), ReportPhase.preparing);
      expect(phase({'status': 'queued'}), ReportPhase.preparing);
    });

    test('failed carries a trimmed reason, blank becomes null', () {
      final s = ReportStatus.fromJson({'status': 'failed', 'reason': ' AI provider unavailable '});
      expect(s.phase, ReportPhase.delayed);
      expect(s.reason, 'AI provider unavailable');
      expect(ReportStatus.fromJson({'status': 'failed', 'reason': '  '}).reason, isNull);
    });

    test('older backends without status fall back to has_scores', () {
      expect(phase({'has_scores': true}), ReportPhase.done);
      expect(phase({'has_scores': false}), ReportPhase.preparing);
      expect(phase({}), ReportPhase.preparing);
    });

    test('garbled input never throws', () {
      expect(phase({'status': 42, 'reason': 7, 'health_score': 'x'}), ReportPhase.preparing);
    });

    test('parses health_score', () {
      expect(ReportStatus.fromJson({'status': 'done', 'health_score': 88}).healthScore, 88);
    });
  });

  group('ReportStatusPoller', () {
    late FakeTimers timers;
    late DateTime clock;
    setUp(() {
      timers = FakeTimers();
      clock = DateTime(2026, 10, 11, 12);
    });

    ReportStatusPoller<int> poller({
      required Future<int> Function() check,
      List<int>? results,
      List<Object>? errors,
      void Function()? onCapped,
    }) =>
        ReportStatusPoller<int>(
          check: check,
          onResult: (r) => results?.add(r),
          onError: (e) => errors?.add(e),
          onCapped: onCapped,
          createTimer: timers.create,
          now: () => clock,
        );

    test('5 s for the first 3 minutes, then 30 s; slow from 3:00', () async {
      final p = poller(check: () async => 1)..start();
      expect(timers.scheduled.last, const Duration(seconds: 5));
      clock = clock.add(const Duration(minutes: 2, seconds: 54));
      await timers.fire();
      expect(timers.scheduled.last, const Duration(seconds: 5));
      expect(p.isSlow, isFalse);
      clock = clock.add(const Duration(seconds: 6));
      await timers.fire();
      expect(timers.scheduled.last, const Duration(seconds: 30));
      expect(p.isSlow, isTrue);
    });

    test('stops at the 30 minute cap', () async {
      var capped = false;
      poller(check: () async => 1, onCapped: () => capped = true).start();
      clock = clock.add(const Duration(minutes: 29, seconds: 45));
      await timers.fire();
      expect(timers.hasPending, isFalse);
      expect(capped, isTrue);
    });

    test('never overlaps: next check waits for the in-flight one', () async {
      final gate = Completer<int>();
      final results = <int>[];
      poller(check: () => gate.future, results: results).start();
      await timers.fire();
      expect(timers.hasPending, isFalse); // in flight, nothing scheduled
      gate.complete(7);
      await Future<void>.delayed(Duration.zero);
      expect(results, [7]);
      expect(timers.hasPending, isTrue);
    });

    test('errors are reported and the schedule continues', () async {
      final errors = <Object>[];
      poller(check: () async => throw StateError('down'), errors: errors).start();
      await timers.fire();
      expect(errors, hasLength(1));
      expect(timers.hasPending, isTrue);
    });

    test('cancel stops scheduling and ignores late results', () async {
      final gate = Completer<int>();
      final results = <int>[];
      final p = poller(check: () => gate.future, results: results)..start();
      await timers.fire();
      p.cancel();
      gate.complete(3);
      await Future<void>.delayed(Duration.zero);
      expect(results, isEmpty);
      expect(timers.hasPending, isFalse);
    });

    test('fixed mode: 10 s for up to 5 minutes', () async {
      var capped = false;
      ReportStatusPoller<int>.fixed(
        every: const Duration(seconds: 10),
        cap: const Duration(minutes: 5),
        check: () async => 1,
        onResult: (_) {},
        onCapped: () => capped = true,
        createTimer: timers.create,
        now: () => clock,
      ).start();
      expect(timers.scheduled.last, const Duration(seconds: 10));
      clock = clock.add(const Duration(minutes: 4, seconds: 55));
      await timers.fire();
      expect(capped, isTrue);
    });
  });
}
