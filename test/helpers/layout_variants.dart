import 'package:flutter/widgets.dart';

/// A window the layout goldens cover beyond the phone and the 834 tablet.
typedef LayoutVariant = ({String name, Size size, EdgeInsets padding});

/// The iPhone Duo's always-on status pill sits on the right edge; Flutter
/// reports it as a right safe-area inset (measured on the simulator).
const kDuoRightInset = 84.0;

/// Duo outer and inner displays, iPad 11" portrait, iPad 13" landscape and a
/// Split View third. Names read `<width>x<height>_<device>`.
const layoutVariants = <LayoutVariant>[
  (
    name: '466x678_duo_outer',
    size: Size(466, 678),
    padding: EdgeInsets.only(right: kDuoRightInset),
  ),
  (
    name: '669x951_duo_inner',
    size: Size(669, 951),
    padding: EdgeInsets.only(right: kDuoRightInset),
  ),
  (name: '820x1180_ipad11', size: Size(820, 1180), padding: EdgeInsets.zero),
  (name: '1376x1032_ipad13l', size: Size(1376, 1032), padding: EdgeInsets.zero),
  (name: '375x667_split_third', size: Size(375, 667), padding: EdgeInsets.zero),
];

/// [MediaQuery] data with [padding] as both padding and view padding.
MediaQueryData withInset(MediaQueryData data, EdgeInsets padding) =>
    data.copyWith(padding: data.padding + padding, viewPadding: data.viewPadding + padding);
