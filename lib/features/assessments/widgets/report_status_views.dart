import 'package:flutter/material.dart';

// Report status views (specs/003-report-status-states, contracts/report-states.md for the copy).

const _titleStyle = TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 18);
const _bodyStyle = TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 14);
const _slowTitle = 'Taking longer than usual — we\'re on it';

Widget _progress(String label) => Semantics(
      label: label,
      child: const CircularProgressIndicator(color: Colors.amber, strokeWidth: 3),
    );

Widget _actionButton({required String label, required VoidCallback? onPressed, bool busy = false}) {
  return ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48, minWidth: 160),
    child: OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.amber,
        side: const BorderSide(color: Colors.amber),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
            )
          : Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
    ),
  );
}

Widget _centered(List<Widget> children) => Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );

/// Shown while the assessment is still being scored.
class ReportPreparingView extends StatelessWidget {
  const ReportPreparingView({super.key, this.slow = false, this.onCheckAgain, this.checking = false});

  /// After 3 minutes: "Taking longer than usual" with a Check again button.
  final bool slow;
  final VoidCallback? onCheckAgain;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    return _centered([
      _progress('Preparing your report'),
      const SizedBox(height: 24),
      Text(slow ? _slowTitle : 'Preparing your report…', style: _titleStyle, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text(
        slow
            ? 'Your report will be ready as soon as our AI finishes. We\'ll keep checking.'
            : 'This usually takes less than a minute.',
        style: _bodyStyle,
        textAlign: TextAlign.center,
      ),
      if (slow && onCheckAgain != null) ...[
        const SizedBox(height: 24),
        _actionButton(label: 'Check again', onPressed: onCheckAgain, busy: checking),
      ],
    ]);
  }
}

/// Shown when scoring couldn't finish (status "failed"); the backend may re-queue it later.
class ReportDelayedView extends StatelessWidget {
  const ReportDelayedView({super.key, this.reason, required this.onCheckAgain, this.checking = false});

  final String? reason;
  final VoidCallback onCheckAgain;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    return _centered([
      const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 48, semanticLabel: 'Report delayed'),
      const SizedBox(height: 20),
      const Text(_slowTitle, style: _titleStyle, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      if (reason != null) ...[
        Text(reason!, style: _bodyStyle.copyWith(color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 8),
      ],
      const Text(
        'Your report will be ready as soon as our AI finishes. Check back soon.',
        style: _bodyStyle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      _actionButton(label: 'Check again', onPressed: onCheckAgain, busy: checking),
    ]);
  }
}

enum _PremiumCardKind { generating, unavailable, stillPreparing }

/// Premium section placeholder while the Premium report isn't ready.
class PremiumStatusCard extends StatelessWidget {
  const PremiumStatusCard.generating({super.key})
      : _kind = _PremiumCardKind.generating,
        onTryAgain = null;
  const PremiumStatusCard.unavailable({super.key, required VoidCallback this.onTryAgain})
      : _kind = _PremiumCardKind.unavailable;
  const PremiumStatusCard.stillPreparing({super.key, required VoidCallback this.onTryAgain})
      : _kind = _PremiumCardKind.stillPreparing;

  final _PremiumCardKind _kind;
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final text = switch (_kind) {
      _PremiumCardKind.generating => 'Preparing your Premium report…',
      _PremiumCardKind.unavailable => 'Your Premium report is temporarily unavailable.',
      _PremiumCardKind.stillPreparing => 'Your Premium report is still being prepared.',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          if (_kind == _PremiumCardKind.generating) ...[
            _progress('Preparing your Premium report'),
            const SizedBox(height: 16),
          ],
          Text(text, style: _bodyStyle.copyWith(color: Colors.white), textAlign: TextAlign.center),
          if (onTryAgain != null) ...[
            const SizedBox(height: 16),
            _actionButton(label: 'Try again', onPressed: onTryAgain),
          ],
        ],
      ),
    );
  }
}
