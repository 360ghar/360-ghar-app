import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/routes/app_pages.dart';
import 'package:ghar360/core/services/deep_link_service.dart';

final appLinksProvider = Provider<AppLinks>((ref) => AppLinks());
final oauthCallbackProvider = NotifierProvider<OAuthCallbackState, AsyncValue<void>>(
  OAuthCallbackState.new,
);

class OAuthCallbackState extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);
  void update(AsyncValue<void> value) => state = value;
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final links = ref.watch(appLinksProvider);
  final auth = ref.watch(authRepositoryProvider);
  final router = ref.watch(appRouterProvider);
  final service = DeepLinkService(
    initialLink: links.getInitialLink,
    links: links.uriLinkStream,
    completeOAuth: auth.completeOAuthFromUri,
    navigate: (path) {
      if (router.state.uri.toString() != path) router.go(path);
    },
    oauthState: (state) {
      if (ref.mounted) ref.read(oauthCallbackProvider.notifier).update(state);
    },
  );
  if (!kIsWeb) unawaited(service.start());
  ref.onDispose(service.close);
  return service;
});
