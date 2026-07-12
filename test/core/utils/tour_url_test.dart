import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/utils/tour_url.dart';

void main() {
  group('TourUrl.validate', () {
    test('accepts https tour URLs', () {
      expect(
        TourUrl.validate('https://kuula.co/share/collection/7YYgH'),
        'https://kuula.co/share/collection/7YYgH',
      );
    });

    test('rejects javascript: scheme', () {
      expect(TourUrl.validate('javascript:alert(1)'), isNull);
    });

    test('rejects data: scheme', () {
      expect(TourUrl.validate('data:text/html,<h1>x</h1>'), isNull);
    });

    test('rejects ftp scheme', () {
      expect(TourUrl.validate('ftp://example.com/tour'), isNull);
    });

    test('rejects empty and whitespace', () {
      expect(TourUrl.validate(''), isNull);
      expect(TourUrl.validate('   '), isNull);
      expect(TourUrl.validate(null), isNull);
    });

    test('rejects URLs with embedded credentials', () {
      expect(TourUrl.validate('https://user:pass@kuula.co/share/x'), isNull);
    });
  });

  group('TourUrl.extractFromArgs', () {
    test('reads String args', () {
      expect(TourUrl.extractFromArgs('https://example.com/tour'), 'https://example.com/tour');
    });

    test('reads map tourUrl', () {
      expect(
        TourUrl.extractFromArgs({'tourUrl': 'https://example.com/a'}),
        'https://example.com/a',
      );
    });

    test('rejects unsafe map values', () {
      expect(TourUrl.extractFromArgs({'url': 'javascript:alert(1)'}), isNull);
    });
  });

  group('TourUrl.isAllowedNavigation', () {
    test('allows WebView bootstrap about: URLs', () {
      expect(TourUrl.isAllowedNavigation('about:blank'), isTrue);
      expect(TourUrl.isAllowedNavigation('about:srcdoc'), isTrue);
    });

    test('allows embed allowlist hosts and rejects javascript', () {
      expect(TourUrl.isAllowedNavigation('https://kuula.co/x'), isTrue);
      expect(TourUrl.isAllowedNavigation('javascript:alert(1)'), isFalse);
    });

    test('allows same host as allowedOriginUrl', () {
      expect(
        TourUrl.isAllowedNavigation(
          'https://tours.example.com/room/2',
          allowedOriginUrl: 'https://tours.example.com/room/1',
        ),
        isTrue,
      );
    });

    test('rejects third-party https without origin match or allowlist', () {
      expect(
        TourUrl.isAllowedNavigation(
          'https://evil.example/phish',
          allowedOriginUrl: 'https://tours.example.com/room/1',
        ),
        isFalse,
      );
      expect(TourUrl.isAllowedNavigation('https://random.site/tour'), isFalse);
    });
  });

  group('TourUrl.sanitizeCssColor', () {
    test('keeps hex and falls back otherwise', () {
      expect(TourUrl.sanitizeCssColor('#fff'), '#fff');
      expect(TourUrl.sanitizeCssColor('#00ff00'), '#00ff00');
      expect(TourUrl.sanitizeCssColor('red; alert(1)'), '#f0f0f0');
    });
  });

  group('TourUrl embed helpers', () {
    test('detects kuula hosts', () {
      expect(TourUrl.isKuula('https://kuula.co/share/x'), isTrue);
      expect(TourUrl.isKuula('https://cdn.kuula.co/x'), isTrue);
      expect(TourUrl.isKuula('https://evil.com/?q=kuula.co'), isFalse);
    });

    test('htmlAttributeEscape escapes quotes', () {
      final escaped = TourUrl.htmlAttributeEscape('https://x.com/"onclick=1');
      expect(escaped, contains('&quot;'));
      expect(escaped, isNot(contains('"')));
    });

    test('buildIframeEmbedHtml uses escaped src', () {
      final html = TourUrl.buildIframeEmbedHtml(
        tourUrl: 'https://kuula.co/share/x"onload=alert(1)',
      );
      expect(html, contains('&quot;'));
      expect(html, isNot(contains('src="https://kuula.co/share/x"')));
    });
  });
}
