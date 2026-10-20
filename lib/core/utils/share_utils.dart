import 'package:flutter/material.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:share_plus/share_plus.dart';

class ShareUtils {
  static Uri _propertyUri(int id) => Uri.https('360ghar.com', '/p/$id');

  static String _shorten(String text, {int max = 80}) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1).trimRight()}...';
  }

  static String propertyLink(int id) => _propertyUri(id).toString();

  static Future<void> shareProperty(PropertyModel property, {BuildContext? context}) async {
    final title = _shorten(property.title);
    final Uri link = _propertyUri(property.id);

    // Build share text: Title, optional location, then link
    final hasLocation =
        (property.locality?.isNotEmpty == true) ||
        (property.subLocality?.isNotEmpty == true) ||
        (property.city?.isNotEmpty == true);
    final location = property.shortAddressDisplay;
    final text = hasLocation ? '$title\n$location\n$link' : '$title\n$link';

    Rect? origin;
    if (context != null) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final topLeft = box.localToGlobal(Offset.zero);
        origin = topLeft & box.size;
      }
    }

    await SharePlus.instance.share(
      ShareParams(text: text, subject: '360Ghar: $title', sharePositionOrigin: origin),
    );
  }
}
