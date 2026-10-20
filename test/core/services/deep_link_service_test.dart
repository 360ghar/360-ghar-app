import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/services/deep_link_service.dart';

void main() {
  group('Verified public property links', () {
    for (final link in [
      'https://360ghar.com/property/42',
      'https://360ghar.com/p/42',
      'https://www.360ghar.com/p/42?campaign=test',
      'http://360ghar.com/p/42',
    ]) {
      test(link, () => expect(DeepLinkService.propertyPathForUri(Uri.parse(link)), '/property/42'));
    }
    // `ghar360` links read like https links. The scheme is also the OAuth callback scheme, so a
    // callback host never reads as a property path.
    for (final link in [
      'ghar360://property/42',
      'ghar360://p/42',
      'GHAR360://property/42',
      'ghar360:///property/42',
      'ghar360://360ghar.com/p/42',
      'ghar360://www.360ghar.com/property/42?campaign=test',
    ]) {
      test(
        'routes $link',
        () => expect(DeepLinkService.propertyPathForUri(Uri.parse(link)), '/property/42'),
      );
    }
    for (final link in [
      'https://evil.example/property/42',
      'https://360ghar.com.evil.example/p/42',
      'ftp://360ghar.com/property/42',
      'ghar360://properties/42',
      'ghar360://property/0',
      'ghar360://property/abc',
      'ghar360://property/42/more',
      'ghar360://property',
      'ghar360://property:8443/42',
      'ghar360://user@property/42',
      'ghar360://evil.example/property/42',
      'ghar360://login-callback',
      'ghar360://login-callback/property/42',
      'ghar360:///login-callback',
      'other://property/42',
      'https://user@360ghar.com/p/42',
      'https://360ghar.com:8443/p/42',
      'https://360ghar.com/about',
      'https://360ghar.com/property/',
      'https://360ghar.com/property/0',
      'https://360ghar.com/property/-1',
      'https://360ghar.com/property/abc-slug',
      'https://360ghar.com/property/uuid-1234',
      'https://360ghar.com/p/42/more',
      'https://360ghar.com/p/9999999999999999999999',
    ]) {
      test(
        'ignores $link',
        () => expect(DeepLinkService.propertyPathForUri(Uri.parse(link)), isNull),
      );
    }
    test('large valid numeric identifier is retained', () {
      expect(
        DeepLinkService.propertyPathForUri(Uri.parse('https://360ghar.com/p/999999999')),
        '/property/999999999',
      );
    });
  });

  group('Link subscription lifecycle', () {
    late StreamController<Uri> links;
    late DeepLinkService service;
    late List<String> navigations;
    late List<AsyncValue<void>> states;
    late List<Uri> exchanges;
    Future<Uri?> Function()? initial;
    Future<void> Function(Uri)? exchange;
    setUp(() {
      links = StreamController<Uri>.broadcast(sync: true);
      navigations = [];
      states = [];
      exchanges = [];
      initial = null;
      exchange = null;
      service = DeepLinkService(
        initialLink: () async => initial == null ? null : await initial!(),
        links: links.stream,
        completeOAuth: (uri) async {
          exchanges.add(uri);
          await exchange?.call(uri);
        },
        navigate: navigations.add,
        oauthState: states.add,
      );
    });
    tearDown(() async {
      service.close();
      await links.close();
    });

    test('routes a cold public link immediately, with no navigation timer', () async {
      initial = () async => Uri.parse('https://360ghar.com/p/42');
      await service.start();
      expect(navigations, ['/property/42']);
    });
    test('routes a ghar360 property link and keeps the OAuth callback on its own path', () async {
      await service.start();
      links.add(Uri.parse('ghar360://property/7'));
      links.add(Uri.parse('ghar360://login-callback?code=cb'));
      await Future<void>.delayed(Duration.zero);
      expect(navigations, ['/property/7']);
      expect(exchanges, [Uri.parse('ghar360://login-callback?code=cb')]);
    });
    test('listens before resolving initial link so warm events cannot be lost', () async {
      final pending = Completer<Uri?>();
      initial = () => pending.future;
      final started = service.start();
      links.add(Uri.parse('https://360ghar.com/p/99'));
      expect(navigations, ['/property/99']);
      pending.complete(null);
      await started;
    });
    test('delayed cold property link cannot overwrite a newer warm destination', () async {
      final pending = Completer<Uri?>();
      initial = () => pending.future;
      final started = service.start();
      links.add(Uri.parse('https://360ghar.com/p/99'));
      pending.complete(Uri.parse('https://360ghar.com/p/42'));
      await started;
      expect(navigations, ['/property/99']);
    });
    test('cold OAuth still completes after a newer public property link', () async {
      final pending = Completer<Uri?>();
      initial = () => pending.future;
      final started = service.start();
      links.add(Uri.parse('https://360ghar.com/p/99'));
      final callback = Uri.parse('ghar360://login-callback?code=cold');
      pending.complete(callback);
      await started;
      expect(navigations, ['/property/99']);
      expect(exchanges, [callback]);
      expect(states.last.hasValue, isTrue);
    });
    test('an invalid warm link does not suppress a valid cold property link', () async {
      final pending = Completer<Uri?>();
      initial = () => pending.future;
      final started = service.start();
      links.add(Uri.parse('https://evil.example/p/99'));
      pending.complete(Uri.parse('https://360ghar.com/p/42'));
      await started;
      expect(navigations, ['/property/42']);
    });
    test('starting twice does not subscribe twice', () async {
      await service.start();
      await service.start();
      links.add(Uri.parse('https://360ghar.com/p/7'));
      expect(navigations, ['/property/7']);
    });
    test('invalid URI has no routing or OAuth side effect', () async {
      await service.handle(Uri.parse('https://evil.example/p/42'));
      await service.handle(Uri.parse('https://360ghar.com/p/no-id'));
      expect(navigations, isEmpty);
      expect(exchanges, isEmpty);
    });
    test('OAuth uses only the configured callback scheme and host', () async {
      final uri = Uri.parse('ghar360://login-callback?code=example');
      await service.handle(uri);
      expect(exchanges, [uri]);
      expect(states.first.isLoading, true);
      expect(states.last.hasValue, true);
      expect(navigations, isEmpty);
      await service.handle(Uri.parse('https://360ghar.com/login-callback?code=other'));
      expect(exchanges, [uri]);
    });
    test('rejects a callback-looking path on another custom host', () async {
      await service.handle(Uri.parse('ghar360://evil/login-callback?code=example'));
      expect(exchanges, isEmpty);
    });
    test('deduplicates simultaneous and repeated callbacks', () async {
      final pending = Completer<void>();
      exchange = (_) => pending.future;
      final uri = Uri.parse('ghar360://login-callback?code=once');
      final first = service.handle(uri);
      await Future<void>.delayed(Duration.zero);
      await service.handle(uri);
      expect(exchanges, [uri]);
      pending.complete();
      await first;
      await service.handle(uri);
      expect(exchanges, [uri]);
    });
    test('failure remains explicit and does not navigate or retry by itself', () async {
      exchange = (_) async => throw StateError('exchange unavailable');
      final uri = Uri.parse('ghar360://login-callback?code=failed');
      await service.handle(uri);
      await service.handle(uri);
      expect(states.last.hasError, true);
      expect(navigations, isEmpty);
      expect(exchanges.length, 1);
    });
    test('disposal rejects a delayed cold link and closes its subscription', () async {
      final pending = Completer<Uri?>();
      initial = () => pending.future;
      final started = service.start();
      service.close();
      service.close();
      pending.complete(Uri.parse('https://360ghar.com/p/42'));
      await started;
      links.add(Uri.parse('https://360ghar.com/p/43'));
      expect(navigations, isEmpty);
      expect(links.hasListener, false);
    });
    test('disposal rejects a delayed callback state update', () async {
      final pending = Completer<void>();
      exchange = (_) => pending.future;
      final result = service.handle(Uri.parse('ghar360://login-callback?code=late'));
      await Future<void>.delayed(Duration.zero);
      service.close();
      pending.complete();
      await result;
      expect(states.length, 1);
      expect(states.single.isLoading, true);
    });
    test('initial-link and stream failures do not prevent future routing', () async {
      initial = () async => throw StateError('platform unavailable');
      await service.start();
      links.addError(StateError('stream unavailable'));
      links.add(Uri.parse('https://360ghar.com/p/3'));
      expect(navigations, ['/property/3']);
    });
  });
}
