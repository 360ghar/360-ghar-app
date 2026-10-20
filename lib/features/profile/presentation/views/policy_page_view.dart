import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/data/models/static_page_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/error_message.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/paper_scroll_page.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/features/profile/data/static_page_repository.dart';
import 'package:ghar360/features/profile/presentation/widgets/paper_parts.dart';
import 'package:url_launcher/url_launcher.dart';

final staticPageRepositoryProvider = Provider<StaticPageRepository>(
  (ref) => StaticPageRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Clock seam for cache freshness.
final staticPageClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class StaticPageState {
  const StaticPageState({this.page, this.loading = true, this.failure});
  final StaticPageModel? page;
  final bool loading;
  final AppException? failure;
}

final staticPageProvider = NotifierProvider.autoDispose
    .family<StaticPageController, StaticPageState, String>(StaticPageController.new);

/// Stale-while-revalidate: a cached page shows at once, a stale one refreshes
/// in the background, and a failed refresh keeps the cached text.
class StaticPageController extends Notifier<StaticPageState> {
  StaticPageController(this.uniqueName);
  final String uniqueName;
  int _generation = 0;

  static const freshFor = Duration(days: 1);
  static const keepFor = Duration(days: 30);
  String get _key => 'static_page:$uniqueName';

  @override
  StaticPageState build() {
    ref.watch(staticPageRepositoryProvider);
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    Future.microtask(() => _restoreAndLoad(generation));
    return const StaticPageState();
  }

  bool _active(int generation) => ref.mounted && generation == _generation;

  Future<void> _restoreAndLoad(int generation) async {
    if (!_active(generation)) return;
    try {
      final cache = await ref
          .read(appDatabaseProvider)
          .readCache(scope: ref.read(storageScopeProvider), key: _key);
      if (!_active(generation)) return;
      if (cache?.value case final Map<String, dynamic> json) {
        final page = StaticPageModel.fromJson(json);
        final fresh = cache!.freshUntil.isAfter(ref.read(staticPageClockProvider)());
        state = StaticPageState(page: page, loading: !fresh);
        if (fresh) return;
      }
    } catch (_) {
      /* The cache is optional; the network still answers. */
    }
    if (_active(generation)) await refresh();
  }

  Future<void> refresh() async {
    final generation = _generation;
    state = StaticPageState(page: state.page);
    try {
      final page = await ref.read(staticPageRepositoryProvider).fetchPublicPage(uniqueName);
      if (!_active(generation)) return;
      state = StaticPageState(page: page, loading: false);
      unawaited(_writeCache(page));
    } catch (error) {
      if (_active(generation)) {
        state = StaticPageState(
          page: state.page,
          loading: false,
          failure: error is AppException
              ? error
              : ServerException('The page could not be loaded.', code: 'STATIC_PAGE_FAILED'),
        );
      }
    }
  }

  Future<void> _writeCache(StaticPageModel page) async {
    try {
      final now = ref.read(staticPageClockProvider)();
      await ref
          .read(appDatabaseProvider)
          .writeCache(
            scope: ref.read(storageScopeProvider),
            key: _key,
            value: page.toJson(),
            freshUntil: now.add(freshFor),
            expiresAt: now.add(keepFor),
          );
    } catch (_) {
      /* Shown content does not depend on the cache write. */
    }
  }
}

class PolicyPageView extends ConsumerWidget {
  const PolicyPageView({super.key, required this.uniqueName, required this.titleText});
  final String uniqueName;
  final String titleText;

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final design = context.design;
    TextStyle? ink(TextStyle? style) => style?.copyWith(color: design.textPrimary);
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: text.bodyMedium?.copyWith(color: design.textPrimary, height: 1.6),
      h1: ink(text.headlineMedium),
      h2: ink(text.headlineSmall),
      h3: ink(text.titleLarge),
      h4: ink(text.titleMedium),
      h5: ink(text.titleSmall),
      h6: ink(text.labelLarge),
      blockquote: text.bodyMedium?.copyWith(color: design.textSecondary),
      blockquoteDecoration: BoxDecoration(color: design.slip),
      blockquotePadding: const EdgeInsets.all(12),
      blockSpacing: 16,
      listBulletPadding: const EdgeInsets.only(right: 8),
      listIndent: 24,
      textAlign: WrapAlignment.start,
      a: TextStyle(color: design.accent, decoration: TextDecoration.underline),
      code: text.bodySmall?.copyWith(backgroundColor: design.slip, color: design.textPrimary),
      tableBorder: TableBorder.all(color: design.border),
      tableHead: text.titleSmall?.copyWith(color: design.textPrimary),
      tableBody: text.bodyMedium?.copyWith(color: design.textSecondary),
      tableCellsPadding: const EdgeInsets.all(12),
    );
  }

  Future<void> _handleLinkTap(BuildContext context, String? href) async {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null || !['https', 'http', 'mailto', 'tel'].contains(uri.scheme)) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
        AppToast.error(context.l10n.text('error'), context.l10n.text('unable_to_open_link'));
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context.l10n.text('error'), context.l10n.text('unable_to_open_link'));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staticPageProvider(uniqueName));
    final retry = ref.read(staticPageProvider(uniqueName).notifier).refresh;
    final page = state.page;
    final header = SceneHeaderSliver(
      title: titleText,
      scene: PaperSceneSpec.skyline(),
      seed: 'policy-$uniqueName',
    );
    final banner = page != null && state.failure != null
        ? InlineRetryBanner(
            message: errorMessage(context, state.failure),
            error: state.failure,
            onRetry: retry,
          )
        : null;
    if (page != null && page.content.trim().isNotEmpty && page.isRenderable) {
      // The page reads as one long sheet; the header folds away above it.
      return Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final side = paperGutter(constraints.maxWidth, 720);
            return PaperScrollPage(
              header: header,
              padding: EdgeInsets.only(top: 8, bottom: 32 + MediaQuery.paddingOf(context).bottom),
              slivers: [
                if (banner != null) SliverToBoxAdapter(child: banner),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: MarkdownBody(
                      data: page.content,
                      styleSheet: _buildMarkdownStyleSheet(context),
                      selectable: true,
                      onTapLink: (_, href, _) => _handleLinkTap(context, href),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
    final Widget body;
    if (page == null && state.loading) {
      body = LoadingStates.documentSkeleton();
    } else if (page == null) {
      body = ErrorStates.genericError(
        error: state.failure,
        onRetry: retry,
        customMessage: context.l10n.text('failed_to_load_content'),
        seed: 'page',
      );
    } else {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.text('content_unavailable'),
            style: TextStyle(color: context.design.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          header,
          SliverFillRemaining(
            child: ColoredBox(
              color: context.design.surface,
              child: Column(
                children: [
                  ?banner,
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
