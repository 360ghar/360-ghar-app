import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/presentation/property_labels.dart';
import 'package:ghar360/core/translations/app_localizations.dart';

/// One visit as a visit pass: a tear-off date stub, a column of punched
/// holes, then the home, the time and status as text, and the actions.
/// Passes lie flat on the sheet; space separates them, never a rule.
class VisitCard extends StatelessWidget {
  const VisitCard({
    super.key,
    required this.visit,
    required this.isUpcoming,
    required this.onReschedule,
    required this.onCancel,
    this.onTap,
    this.selected = false,
    this.showActions = true,
  });
  final VisitModel visit;
  final bool isUpcoming;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;
  final VoidCallback? onTap;

  /// The pass shown in the detail pane. It gets the quiet `slip` fill.
  final bool selected;

  /// False in the two-pane layout, where the pane carries the actions.
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final palette = context.design;
    final text = Theme.of(context).textTheme;
    final date = visit.scheduledDate.toLocal();
    final property = visit.property;
    final facts = [
      // A listing with no price for its purpose has no price to show.
      if (property != null && property.effectivePrice != null) property.localizedPrice(context),
      if (property != null) context.l10n.text(property.listingTranslationKey),
      if (property?.bedrooms != null) '${property!.bedrooms} BHK',
      if (property?.bathrooms != null) '${property!.bathrooms} ${context.l10n.text('bathrooms')}',
      if (property?.areaSqft != null)
        '${property!.areaSqft!.toStringAsFixed(0)} ${context.l10n.text('sqft')}',
    ];
    final actions = [
      if (showActions && isUpcoming && visit.canReschedule)
        OutlinedButton(
          onPressed: onReschedule,
          style: visitPaperButtonStyle(context, seed: 'reschedule-${visit.id}'),
          child: Text(context.l10n.text('reschedule')),
        ),
      if (showActions && isUpcoming && visit.canCancel)
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: palette.error,
            minimumSize: const Size(48, 48),
          ),
          child: Text(context.l10n.text('cancel')),
        ),
    ];
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          visitTitle(context, visit),
          style: text.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${TimeOfDay.fromDateTime(date).format(context)} · '),
              TextSpan(
                text: context.l10n.text(visit.statusStringKey),
                style: TextStyle(
                  color: visitStatusColor(context, visit.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          style: text.bodyMedium?.copyWith(color: palette.textPrimary),
        ),
        // The other person on a flatmate meet: name only. The backend sends no contact.
        if (visit.isFlatmateMeet && (visit.counterpartyUser?.displayName ?? '').isNotEmpty)
          Text(
            context.l10n.text(
              'meeting_with',
              params: {'name': visit.counterpartyUser!.displayName!},
            ),
            style: text.bodySmall?.copyWith(color: palette.textSecondary),
          ),
        if (property != null && property.addressDisplay.isNotEmpty)
          Text(
            property.addressDisplay,
            style: text.bodySmall?.copyWith(color: palette.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(facts.join(' · '), style: text.bodySmall?.copyWith(color: palette.textSecondary)),
        ],
        if (isUpcoming && (visit.specialRequirements?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 4),
          Text(
            visit.specialRequirements!,
            style: text.bodySmall?.copyWith(color: palette.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      ],
    );
    // Large text gives the words the full width: the stub lies across the
    // top of the pass and the tear line runs under it.
    final across = MediaQuery.textScalerOf(context).scale(14) > 21;
    // On the selected pass's mint fill the stub turns white, so it still reads.
    final stub = VisitDateBlock(
      date: date,
      seed: 'stub-${visit.id}',
      across: across,
      color: selected ? palette.raised : null,
    );
    final shape = CutBorder(seed: 'visit-${visit.id}', amp: 1.5);
    return Material(
      color: selected ? palette.slip : Colors.transparent,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: across
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [stub, const _Perforation(across: true), words],
                )
              // The stub and the holes run the full height of the pass.
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stub,
                      const _Perforation(across: false),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 6),
                          child: words,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// The white paper button of a visit: card stock with a hand-cut edge and a
/// short shadow on the sheet. Pressing tints it; it never moves.
ButtonStyle visitPaperButtonStyle(BuildContext context, {required String seed}) {
  final design = context.design;
  return OutlinedButton.styleFrom(
    foregroundColor: design.textPrimary,
    minimumSize: const Size(48, 48),
    // The card's own lip tone marks the lit top-left edge on a white sheet.
    shape: CutBorder(
      seed: seed,
      amp: 1.5,
      side: BorderSide(color: design.sheetLip),
      shadows: paperShadows(PaperElevation.low, design.shadowOn(design.surface)),
    ),
  ).copyWith(
    // Mint card stock, like the date stub: a white button on the white
    // sheet read as plain text.
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered)
          ? Color.lerp(design.slip, design.accent, 0.12)
          : design.slip,
    ),
  );
}

/// A tear-off date stub: the short month, the day in the display face and
/// the weekday on a hand-cut mint leaf.
class VisitDateBlock extends StatelessWidget {
  const VisitDateBlock({
    super.key,
    required this.date,
    this.seed = 'stub',
    this.across = false,
    this.color,
  });
  final DateTime date;

  /// Seed of the leaf's hand-cut edge.
  final String seed;

  /// A strip across the top of the pass (large text) instead of a column.
  final bool across;

  /// The leaf's stock; the mint slip when null.
  final Color? color;

  static const gap = 14.0;

  /// Grows with large text, up to 92 px; longer month labels scale down
  /// inside it instead of wrapping.
  static double widthOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(60).clamp(60, 92).toDouble();

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    Widget line(String value, TextStyle? style) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(value, style: style, maxLines: 1, textAlign: TextAlign.center),
    );
    final month = DateFormat.MMM(locale).format(date);
    final weekday = DateFormat.E(locale).format(date);
    final day = text.displaySmall?.copyWith(color: design.textPrimary);
    final quiet = text.labelMedium?.copyWith(color: design.textSecondary);
    final leaf = ShapeDecoration(
      color: color ?? design.slip,
      shape: CutBorder(seed: seed, amp: 1.5),
    );
    if (across) {
      return DecoratedBox(
        decoration: leaf,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text('${date.day}', style: day),
              const SizedBox(width: 12),
              Flexible(child: Text('$month · $weekday', style: quiet)),
            ],
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: leaf,
      child: SizedBox(
        width: widthOf(context),
        child: Padding(
          // Clear of the 1.5 px cut on every side.
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              line(month, quiet),
              line('${date.day}', day),
              line(weekday, text.labelSmall?.copyWith(color: design.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tear line of a pass: holes punched through the sheet, so the page
/// shows in them. Light falls from the top left, so each hole's top-left
/// wall is in shade.
class _Perforation extends StatelessWidget {
  const _Perforation({required this.across});

  /// Holes in a row under the stub instead of a column beside it.
  final bool across;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return SizedBox(
      width: across ? null : 24,
      height: across ? 24 : null,
      child: CustomPaint(
        painter: _HolesPainter(
          page: design.background,
          wall: Color.lerp(design.background, design.shadowOn(design.surface), 0.35)!,
        ),
      ),
    );
  }
}

class _HolesPainter extends CustomPainter {
  const _HolesPainter({required this.page, required this.wall});

  final Color page;
  final Color wall;

  static const _hole = 6.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    // The holes run along the longer side, centred on the shorter one.
    final across = size.width > size.height;
    final length = across ? size.width : size.height;
    final count = ((length - 4 + _gap) / (_hole + _gap)).floor();
    if (count <= 0) return;
    final first = (length - count * _hole - (count - 1) * _gap) / 2;
    final wallPaint = Paint()..color = wall;
    final pagePaint = Paint()..color = page;
    for (var i = 0; i < count; i++) {
      final at = first + i * (_hole + _gap);
      final hole = across
          ? Rect.fromLTWH(at, (size.height - _hole) / 2, _hole, _hole)
          : Rect.fromLTWH((size.width - _hole) / 2, at, _hole, _hole);
      canvas.save();
      canvas.clipPath(Path()..addOval(hole));
      canvas.drawOval(hole, wallPaint);
      canvas.drawOval(hole.shift(const Offset(1, 1)), pagePaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HolesPainter old) => old.page != page || old.wall != wall;
}

/// Status reads as coloured text, never a pill.
Color visitStatusColor(BuildContext context, VisitStatus? status) => switch (status) {
  VisitStatus.cancelled => context.design.error,
  VisitStatus.completed || VisitStatus.confirmed => context.design.success,
  VisitStatus.rescheduled => context.design.warning,
  _ => context.design.textSecondary,
};

/// The visit's property title, or "Property #id" when the backend sent no
/// nested property.
String visitTitle(BuildContext context, VisitModel visit) => visit.propertyTitle.isNotEmpty
    ? visit.propertyTitle
    : context.l10n.text('visit_property_fallback', params: {'id': '${visit.propertyId}'});
