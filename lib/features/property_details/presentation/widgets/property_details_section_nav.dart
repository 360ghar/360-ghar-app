import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/folder_tabs.dart';

enum PropertyDetailsSection { overview, media, specs, location }

/// Jump links to the sections of the details page, as folder tabs cut into
/// the top edge of the details sheet. The current section is the tab that
/// merges into the sheet. When the tabs do not fit their labels, the strip
/// scrolls sideways and keeps the current tab in view.
class PropertyDetailsSectionNav extends StatefulWidget {
  const PropertyDetailsSectionNav({
    super.key,
    required this.active,
    required this.onSelect,
    this.showMedia = true,
    this.showLocation = true,
  });

  final PropertyDetailsSection active;
  final ValueChanged<PropertyDetailsSection> onSelect;
  final bool showMedia;
  final bool showLocation;

  /// Horizontal space a tab needs around its label (FolderTabs' gutter is
  /// 16; its slant and label inset take 18 on each side of the label).
  static const _gutter = 16.0;
  static const _labelRoom = 2 * 18.0 + 6;

  static List<PropertyDetailsSection> _sections(bool media, bool location) => [
    PropertyDetailsSection.overview,
    if (media) PropertyDetailsSection.media,
    PropertyDetailsSection.specs,
    if (location) PropertyDetailsSection.location,
  ];

  static String _label(BuildContext context, PropertyDetailsSection section) =>
      context.l10n.text(switch (section) {
        PropertyDetailsSection.overview => 'section_overview',
        PropertyDetailsSection.media => 'section_media',
        PropertyDetailsSection.specs => 'section_specs',
        PropertyDetailsSection.location => 'section_location',
      });

  /// The strip's width: [width], or wider when a tab would cut its label.
  static double _stripWidth(BuildContext context, List<String> labels, double width) {
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w800);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: FolderTabs.maxLabelScale);
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return math.max(width, 2 * _gutter + labels.length * (widest + _labelRoom)).ceilToDouble();
  }

  /// Height of the tabs and the sheet's lip at [width].
  static double heightFor(
    BuildContext context,
    double width, {
    bool showMedia = true,
    bool showLocation = true,
  }) {
    final labels = [
      for (final section in _sections(showMedia, showLocation)) _label(context, section),
    ];
    return FolderTabs.heightFor(context, labels, _stripWidth(context, labels, width));
  }

  @override
  State<PropertyDetailsSectionNav> createState() => _PropertyDetailsSectionNavState();
}

class _PropertyDetailsSectionNavState extends State<PropertyDetailsSectionNav> {
  final _strip = ScrollController();
  double _tabWidth = 0;

  List<PropertyDetailsSection> get _sections =>
      PropertyDetailsSectionNav._sections(widget.showMedia, widget.showLocation);

  @override
  void didUpdateWidget(PropertyDetailsSectionNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  /// Scrolls the strip so the current tab shows whole.
  void _reveal() {
    if (!mounted || !_strip.hasClients) return;
    final position = _strip.position;
    if (position.maxScrollExtent <= 0) return;
    final index = _sections.indexOf(widget.active);
    if (index < 0) return;
    const gutter = PropertyDetailsSectionNav._gutter;
    final left = index * _tabWidth;
    final right = left + _tabWidth + 2 * gutter;
    var target = position.pixels;
    if (left < target) target = left;
    if (right > target + position.viewportDimension) target = right - position.viewportDimension;
    target = target.clamp(0.0, position.maxScrollExtent);
    if (target == position.pixels) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _strip.jumpTo(target);
    } else {
      _strip.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    final labels = [
      for (final section in sections) PropertyDetailsSectionNav._label(context, section),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final strip = PropertyDetailsSectionNav._stripWidth(context, labels, width);
        _tabWidth = (strip - 2 * PropertyDetailsSectionNav._gutter) / labels.length;
        final tabs = FolderTabs(
          seed: 'details-sections',
          labels: labels,
          selected: math.max(0, sections.indexOf(widget.active)),
          onSelect: (i) => widget.onSelect(sections[i]),
          qaIds: [for (final section in sections) 'qa.property_details.section.${section.name}'],
        );
        if (strip <= width) return tabs;
        return SingleChildScrollView(
          controller: _strip,
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: strip, child: tabs),
        );
      },
    );
  }
}
