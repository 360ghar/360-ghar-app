import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/count_up_text.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';
import 'package:ghar360/features/profile/presentation/widgets/paper_parts.dart';

/// Shared input field for the calculators: a label above a themed numeric
/// field. The theme draws the field outline (3:1) and the error state.
class CalculatorTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final String? suffix;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const CalculatorTextField({
    super.key,
    required this.label,
    required this.controller,
    this.prefix,
    this.suffix,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CalculatorLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType ?? const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            suffixIcon: errorText == null
                ? null
                : PaperIcon(KnifeIcon.alert, color: context.design.error),
            errorMaxLines: 3,
            prefixText: prefix,
            prefixStyle: TextStyle(color: context.design.textPrimary),
            suffixText: suffix,
            suffixStyle: TextStyle(color: context.design.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// The label over a field or a slider.
class CalculatorLabel extends StatelessWidget {
  const CalculatorLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.design.textSecondary),
  );
}

/// A section heading inside a calculator.
class CalculatorSectionTitle extends StatelessWidget {
  const CalculatorSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.headlineSmall));
}

/// The one number a calculator exists to give, set large in the display
/// face. A new result counts up from the last one.
class CalculatorHeadline extends StatelessWidget {
  const CalculatorHeadline({
    super.key,
    required this.label,
    required this.value,
    required this.format,
    this.valueKey,
    this.note,
  });

  final String label;
  final num value;
  final String Function(double value) format;
  final Key? valueKey;

  /// A short qualifier after the label, such as "Long term".
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final design = context.design;
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (note != null)
                  TextSpan(
                    text: '  ·  $note',
                    style: TextStyle(color: design.textPrimary, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            style: text.bodyMedium?.copyWith(color: design.textSecondary),
          ),
          const SizedBox(height: 6),
          CountUpText(
            value,
            key: valueKey,
            format: format,
            style: text.displayMedium?.copyWith(color: design.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Label/value result row. The value uses the display face; [isHighlight]
/// sets it one step larger for the main result.
class CalculatorResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final String? caption;
  final Color? valueColor;

  const CalculatorResultRow(
    this.label,
    this.value, {
    super.key,
    this.isHighlight = false,
    this.caption,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final design = context.design;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodyLarge?.copyWith(color: design.textPrimary)),
                if (caption != null)
                  Text(caption!, style: text.bodySmall?.copyWith(color: design.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Values sit flush right, like the totals on a receipt.
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: (isHighlight ? text.headlineMedium : text.headlineSmall)?.copyWith(
                  color: valueColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet note: a bare icon and a line of text, no box behind it.
class CalculatorNote extends StatelessWidget {
  const CalculatorNote(this.text, {super.key, this.icon = KnifeIcon.info});
  final String text;
  final KnifeIcon icon;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: PaperIcon(icon, size: 18, color: design.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: design.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// A labelled slider with its current value in the display face and its
/// range underneath.
class CalculatorSlider extends StatelessWidget {
  const CalculatorSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  static const _sliderInset = 12.0;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final range = text.bodySmall?.copyWith(color: design.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: CalculatorLabel(label)),
            const SizedBox(width: 12),
            Text(format(value), style: text.headlineSmall),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: design.accent,
          inactiveColor: design.border,
          // A known inset, so the range under it starts and ends with the track.
          padding: const EdgeInsets.symmetric(horizontal: _sliderInset, vertical: 18),
          label: format(value),
          semanticFormatterCallback: format,
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _sliderInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(format(min), style: range),
              Text(format(max), style: range),
            ],
          ),
        ),
      ],
    );
  }
}

/// The frame every calculator shares: the slim skyline header with back,
/// title and reset; the inputs on the sheet under it; and, once there is
/// one, the [result] printed on a receipt below the sheet, on the sky.
class CalculatorScaffold extends StatelessWidget {
  const CalculatorScaffold({
    super.key,
    required this.screenKey,
    required this.title,
    required this.onReset,
    required this.inputs,
    this.result,
    this.resetKey,
  });

  final String screenKey;
  final String title;
  final VoidCallback onReset;
  final String? resetKey;

  /// The inputs and the one action.
  final List<Widget> inputs;

  /// The result, or null before there is one.
  final List<Widget>? result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reset = IconButton(
      key: resetKey == null ? null : ValueKey(resetKey),
      icon: const PaperIcon(KnifeIcon.retry),
      tooltip: l10n.text('reset'),
      onPressed: onReset,
    );
    final result = this.result;
    return Semantics(
      identifier: screenKey,
      child: Scaffold(
        key: ValueKey(screenKey),
        backgroundColor: context.design.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final side = paperGutter(constraints.maxWidth, 640);
            return SkySheetsScrollView(
              seed: '$screenKey.band',
              header: SceneHeaderSliver(
                title: title,
                scene: PaperSceneSpec.skyline(),
                seed: screenKey,
                leading: IconButton(
                  tooltip: l10n.text('back'),
                  icon: const PaperIcon(KnifeIcon.arrowLeft),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                actions: [
                  if (resetKey == null) reset else Semantics(identifier: resetKey, child: reset),
                ],
              ),
              slivers: [
                SheetSliver(
                  padding: EdgeInsets.fromLTRB(side, kPaperLip + 6, side, 20),
                  slivers: [
                    SliverToBoxAdapter(
                      // Ink of the controls paints on this layer, above the sheet.
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: inputs,
                        ),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: SheetFoot(seed: '$screenKey.foot')),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    side - 4,
                    20,
                    side - 4,
                    32 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: result == null
                        ? const SizedBox.shrink()
                        : CalculatorReceipt(seed: screenKey, children: result),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A result printed on a receipt: a white slip with a hand-cut top and a
/// torn zigzag foot, lying on the sky.
class CalculatorReceipt extends StatelessWidget {
  const CalculatorReceipt({super.key, required this.seed, required this.children});

  final String seed;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: design.surface,
        shape: ReceiptBorder(
          seed: seed,
          tooth: 12,
          depth: 6,
          shadows: paperShadows(PaperElevation.low, design.shadowOn(design.background)),
        ),
      ),
      // Clear of the cut on every side and of the teeth at the foot.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}
