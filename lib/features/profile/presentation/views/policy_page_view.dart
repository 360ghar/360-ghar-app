import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/static_page_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/mixins/theme_mixin.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/profile/data/static_page_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class PolicyPageView extends StatefulWidget with ThemeMixin {
  final String uniqueName;
  final String titleText;

  PolicyPageView({super.key, required this.uniqueName, required this.titleText});

  @override
  State<PolicyPageView> createState() => _PolicyPageViewState();
}

class _PolicyPageViewState extends State<PolicyPageView> {
  final StaticPageRepository _staticPageRepository = Get.find<StaticPageRepository>();
  String? _markdownContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final StaticPageModel page = await _staticPageRepository.fetchPublicPage(widget.uniqueName);

      setState(() {
        _markdownContent = page.content.trim().isNotEmpty ? page.content : 'content_unavailable'.tr;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'failed_to_load_content'.tr;
        _isLoading = false;
      });
    }
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryTextColor = theme.colorScheme.onSurface;
    final Color secondaryTextColor = AppDesign.textSecondary;
    final Color linkColor = theme.colorScheme.primary;

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(color: primaryTextColor, height: 1.6),
      h1: theme.textTheme.headlineMedium?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.w700,
      ),
      h2: theme.textTheme.headlineSmall?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.w700,
      ),
      h3: theme.textTheme.titleLarge?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.w700,
      ),
      h4: theme.textTheme.titleMedium?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
      ),
      h5: theme.textTheme.titleSmall?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
      ),
      h6: theme.textTheme.labelLarge?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppDesign.cardBackground,
        border: const Border(left: BorderSide(color: AppDesign.primaryYellow, width: 4)),
      ),
      blockSpacing: 16,
      listBulletPadding: const EdgeInsets.only(right: 8),
      listIndent: 24,
      textAlign: WrapAlignment.start,
      a: TextStyle(
        color: linkColor,
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w500,
      ),
      code: TextStyle(
        backgroundColor: AppDesign.inputBackground,
        color: primaryTextColor,
        fontFamily: 'monospace',
        fontSize: (theme.textTheme.bodySmall?.fontSize ?? 13) * 0.95,
      ),
      tableBorder: TableBorder.all(color: AppDesign.divider, width: 1),
      tableHead: theme.textTheme.titleSmall?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
      ),
      tableBody: theme.textTheme.bodyMedium?.copyWith(color: secondaryTextColor),
      tableCellsPadding: const EdgeInsets.all(12),
    );
  }

  Future<void> _handleLinkTap(String? href) async {
    if (href == null || href.isEmpty) {
      return;
    }

    final Uri? uri = Uri.tryParse(href);
    if (uri == null) {
      return;
    }

    try {
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        AppToast.error('error'.tr, 'unable_to_open_link'.tr);
      }
    } catch (e) {
      AppToast.error('error'.tr, 'unable_to_open_link'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;

    if (_isLoading) {
      body = Center(child: CircularProgressIndicator(color: AppDesign.loadingIndicator));
    } else if (_error != null) {
      body = Center(
        child: Text(_error!, style: TextStyle(color: AppDesign.textSecondary)),
      );
    } else if (_markdownContent == null || _markdownContent!.isEmpty) {
      body = Center(
        child: Text('no_content'.tr, style: TextStyle(color: AppDesign.textSecondary)),
      );
    } else {
      body = Markdown(
        data: _markdownContent!,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        styleSheet: _buildMarkdownStyleSheet(context),
        selectable: true,
        onTapLink: (text, href, title) => _handleLinkTap(href),
      );
    }

    return (widget as ThemeMixin).buildThemeAwareScaffold(
      title: widget.titleText,
      body: SafeArea(child: body),
    );
  }
}
