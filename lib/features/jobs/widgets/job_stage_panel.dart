// lib/features/jobs/widgets/job_stage_panel.dart
//
// Shared pieces of the Ride, Delivery and Gas tracking screens, so every
// job looks and behaves the same way:
//
//   JobStageHeader   progress ("Step 2 of 4") + one plain instruction
//   JobStageActions  one dominant primary action, at most one secondary
//   JobCancelLink    cancellation, kept apart from the actions
//   showJobConfirm   a confirmation dialog with its own context
//   JobOutcomeHeader / JobFooterButton  the completed and ended screens
//
// Colours come from AppTheme (CTSGo): primary actions are primaryDark with
// white text (as the theme's filled buttons), primaryDark is also the green
// for text and icons, textPrimary / textSecondary for other text.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_theme.dart';
import '../domain/job_stage_plan.dart';

/// Progress through a job's phases, with the current one highlighted.
class JobStepProgress extends StatelessWidget {
  final List<String> steps;
  final int current;

  /// Shows "STEP n OF m" above the bars.
  final bool showCaption;

  const JobStepProgress({
    super.key,
    required this.steps,
    required this.current,
    this.showCaption = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of ${steps.length}: ${steps[current]}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCaption) ...[
            Text(
              'STEP ${current + 1} OF ${steps.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= current
                              ? AppTheme.primary
                              : AppTheme.primarySubtle,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[i],
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight:
                              i == current ? FontWeight.w800 : FontWeight.w500,
                          color: i == current
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The stage's progress and its one instruction.
class JobStageHeader extends StatelessWidget {
  final JobStagePlan plan;

  const JobStageHeader({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JobStepProgress(steps: plan.steps, current: plan.stepIndex),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            plan.title,
            style: const TextStyle(
              fontSize: 21,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          plan.hint,
          style: const TextStyle(
              fontSize: 15, height: 1.4, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

/// The stage's actions: one dominant primary button and, when the stage
/// offers navigation, one quieter secondary button.
///
/// Taps that arrive within [settleTime] of the stage appearing or changing
/// are ignored. The status button often sits where the previous stage's
/// button was, so this stops a double tap from carrying over into the next
/// stage (e.g. "I've arrived" straight into the next step).
class JobStageActions extends StatefulWidget {
  final JobStagePlan plan;

  /// A status step is being written: the step button shows progress and
  /// ignores taps.
  final bool busy;

  final VoidCallback onStep;
  final VoidCallback? onNavigate;

  static const settleTime = Duration(milliseconds: 700);

  const JobStageActions({
    super.key,
    required this.plan,
    required this.busy,
    required this.onStep,
    this.onNavigate,
  });

  @override
  State<JobStageActions> createState() => _JobStageActionsState();
}

class _JobStageActionsState extends State<JobStageActions> {
  late DateTime _shownAt;

  @override
  void initState() {
    super.initState();
    _shownAt = DateTime.now();
  }

  @override
  void didUpdateWidget(JobStageActions old) {
    super.didUpdateWidget(old);
    if (old.plan.key != widget.plan.key) _shownAt = DateTime.now();
  }

  bool get _settled =>
      DateTime.now().difference(_shownAt) >= JobStageActions.settleTime;

  void _step() {
    if (widget.busy || !_settled) return;
    widget.onStep();
  }

  void _navigate() {
    if (!_settled) return;
    HapticFeedback.selectionClick();
    widget.onNavigate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final canNavigate = plan.navigateLabel != null && widget.onNavigate != null;

    final stepButton = _JobButton(
      key: const ValueKey('job-step-action'),
      label: widget.busy ? 'Updating…' : plan.step.label,
      icon: plan.step.icon,
      primary: !(canNavigate && plan.navigatePrimary),
      busy: widget.busy,
      onTap: widget.busy ? null : _step,
    );
    final navButton = canNavigate
        ? _JobButton(
            key: const ValueKey('job-navigate-action'),
            label: plan.navigateLabel!,
            icon: Icons.navigation_rounded,
            caption: 'Opens Google Maps',
            primary: plan.navigatePrimary,
            onTap: _navigate,
          )
        : null;

    final ordered = navButton == null
        ? [stepButton]
        : plan.navigatePrimary
            ? [navButton, stepButton]
            : [stepButton, navButton];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ordered.first,
        if (ordered.length > 1) ...[
          const SizedBox(height: 12),
          ordered.last,
        ],
      ],
    );
  }
}

class _JobButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? caption;
  final bool primary;
  final bool busy;
  final VoidCallback? onTap;

  const _JobButton({
    super.key,
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
    this.caption,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? AppTheme.onPrimary : AppTheme.primaryDark;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        else
          Icon(icon, size: 22),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: primary ? 17 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primary ? fg : AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    final button = primary
        ? FilledButton(
            onPressed: onTap,
            // While busy the fill stays solid so "Updating…" keeps 5.0:1;
            // the spinner shows the wait.
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: AppTheme.onPrimary,
              disabledBackgroundColor: AppTheme.primaryDark,
              disabledForegroundColor: AppTheme.onPrimary,
              minimumSize: const Size.fromHeight(60),
              padding: padding,
              shape: shape,
              elevation: 0,
            ),
            child: content,
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryDark,
              disabledForegroundColor: AppTheme.textSecondary,
              backgroundColor: AppTheme.surface,
              minimumSize: const Size.fromHeight(56),
              padding: padding,
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              shape: shape,
            ),
            child: content,
          );

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: busy ? '$label, please wait' : label,
      excludeSemantics: true,
      onTap: onTap,
      child: button,
    );
  }
}

/// Cancellation, deliberately quiet and away from the stage's actions. It
/// still asks for confirmation before anything is written.
class JobCancelLink extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onTap;

  const JobCancelLink({
    super.key,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  static const _red = Color(0xFFB91C1C); // 6.5:1 on white

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        key: const ValueKey('job-cancel-action'),
        onPressed: busy ? null : onTap,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _red,
                ),
              )
            : const Icon(Icons.close_rounded, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: TextButton.styleFrom(
          foregroundColor: _red,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

/// A two-button confirmation. Returns true only when the driver confirms.
/// Pops with the dialog's own context, so it never closes the screen.
Future<bool> showJobConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String keepLabel = 'Go back',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: AppTheme.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
            fontSize: 15, height: 1.4, color: AppTheme.textSecondary),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            minimumSize: const Size(48, 48),
          ),
          child: Text(keepLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor:
                destructive ? AppTheme.danger : AppTheme.primaryDark,
            foregroundColor: AppTheme.onPrimary,
            minimumSize: const Size(48, 48),
          ),
          child: Text(confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result == true;
}

/// "Have you arrived?" for a step guarded by [JobGuard.arrival], asked only
/// when the driver is not near the target (or their position is unknown).
Future<bool> confirmArrival(
  BuildContext context, {
  required String place,
  required String whoIsTold,
  required double? metresToTarget,
}) {
  if (!arrivalNeedsConfirm(metresToTarget)) return Future.value(true);
  final where = metresToTarget == null
      ? ''
      : 'You seem to be about ${formatDistance(metresToTarget)} from the '
          '$place. ';
  return showJobConfirm(
    context,
    title: 'Are you at the $place?',
    message: "${where}Only confirm when you have arrived. "
        'The $whoIsTold will be told you are there.',
    confirmLabel: "Yes, I've arrived",
    keepLabel: 'Not yet',
  );
}

String formatDistance(double metres) => metres < 1000
    ? '${(metres / 10).round() * 10} m'
    : '${(metres / 1000).toStringAsFixed(1)} km';

/// Pins a job's actions to the bottom of the screen, above the system
/// navigation bar, so they are visible without scrolling or dragging.
///
/// Text in the footer scales up to [maxTextScale] (still large); beyond
/// that two wrapped buttons would not fit a small phone. The instruction
/// above it scrolls and keeps the driver's full text size.
class JobActionFooter extends StatelessWidget {
  static const maxTextScale = 1.5;

  final Widget child;
  const JobActionFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxTextScale,
        child: child,
      ),
    );
  }
}

/// The one primary action of a completed or ended screen, pinned in a
/// [JobActionFooter].
class JobFooterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Key for the button itself (tests and semantics find it by this).
  final Key? buttonKey;

  const JobFooterButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    return JobActionFooter(
      child: FilledButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: AppTheme.onPrimary,
          minimumSize: const Size.fromHeight(60),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Icon, headline and one sentence at the top of a completed or ended
/// screen. [color] tints the icon; pass a colour with 3:1 or more on white.
class JobOutcomeHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const JobOutcomeHeader({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 44),
          ),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 15, height: 1.45, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

/// A white card holding a completed job's figures.
class JobSummaryCard extends StatelessWidget {
  final List<Widget> children;
  const JobSummaryCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }
}

/// One label / value row in a [JobSummaryCard].
class JobSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;

  const JobSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    // Both sides wrap, so large text on a small phone never overflows.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: emphasis ? 18 : 15,
              height: 1.35,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
              color: emphasis ? AppTheme.primaryDark : AppTheme.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown instead of actions when the job has nothing left for the driver
/// to do (cancelled, or a status this app version does not know).
class JobEndedScreen extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final VoidCallback onDone;

  /// The one action's label; [onDone] decides where it goes.
  final String doneLabel;
  final IconData doneIcon;

  const JobEndedScreen({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.onDone,
    this.doneLabel = 'Back to home',
    this.doneIcon = Icons.home_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: JobFooterButton(
        buttonKey: const ValueKey('job-ended-done'),
        label: doneLabel,
        icon: doneIcon,
        onPressed: onDone,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: JobOutcomeHeader(
              icon: icon,
              color: color,
              title: title,
              message: message,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when a job is finished: what was done, what it paid, and one way
/// back home. Matches the tracking screens and the trip completed screen.
class JobCompletedScreen extends StatelessWidget {
  final String title;
  final String message;

  /// The headline amount, e.g. the delivery fare.
  final String amountLabel;
  final double amount;

  /// Extra label/value rows under the amount (route, parcel, ...).
  final List<(String, String)> details;

  final VoidCallback onDone;

  const JobCompletedScreen({
    super.key,
    required this.title,
    required this.message,
    required this.amountLabel,
    required this.amount,
    required this.onDone,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: JobFooterButton(
        buttonKey: const ValueKey('job-completed-done'),
        label: 'Back to home',
        icon: Icons.home_rounded,
        onPressed: onDone,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JobOutcomeHeader(
                  icon: Icons.check_rounded,
                  color: AppTheme.primaryDark,
                  title: title,
                  message: message,
                ),
                const SizedBox(height: 28),
                JobSummaryCard(
                  children: [
                    Text(
                      amountLabel.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'GH₵ ${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryDark,
                          letterSpacing: -0.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    for (final (label, value) in details) ...[
                      const Divider(height: 28, color: AppTheme.divider),
                      JobSummaryRow(label: label, value: value),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
