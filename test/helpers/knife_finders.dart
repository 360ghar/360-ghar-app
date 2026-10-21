import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

/// Finds a [PaperIcon] that draws [icon], like `find.byIcon` for Material.
Finder findKnife(KnifeIcon icon) =>
    find.byWidgetPredicate((widget) => widget is PaperIcon && widget.icon == icon);
