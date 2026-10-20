import 'package:flutter/widgets.dart';

/// A number that counts from its previous value to [value] when the value
/// changes (600 ms). The first frame already shows [value], and with reduced
/// motion it changes at once. Screen readers hear only the final value.
class CountUpText extends StatelessWidget {
  const CountUpText(this.value, {super.key, this.format = _whole, this.style, this.textAlign});

  final num value;

  /// Formats the shown number; it gets fractional values while counting.
  final String Function(double value) format;
  final TextStyle? style;
  final TextAlign? textAlign;

  static String _whole(double value) => value.round().toString();

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: format(value.toDouble()),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.toDouble()),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, shown, _) => Text(format(shown), style: style, textAlign: textAlign),
      ),
    );
  }
}
