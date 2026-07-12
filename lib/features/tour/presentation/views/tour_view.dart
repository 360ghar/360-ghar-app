import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/tour_url.dart';
import 'package:ghar360/core/widgets/common/max_content_width.dart';
import 'package:ghar360/core/widgets/common/tour_webview.dart';
import 'package:share_plus/share_plus.dart';

class TourView extends StatefulWidget {
  const TourView({super.key});

  @override
  State<TourView> createState() => _TourViewState();
}

class _TourViewState extends State<TourView> {
  String? _tourUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tourUrl = TourUrl.extractFromArgs(Get.arguments);
    if (_tourUrl == null) {
      _isLoading = false;
      DebugLogger.warning('TourView received invalid route arguments: ${Get.arguments}');
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Widget _buildInvalidTourContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 48, color: AppDesign.textSecondary),
            const SizedBox(height: 12),
            Text(
              'unable_to_open_link'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppDesign.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'check_internet_connection'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppDesign.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Get.back(), child: Text('back'.tr)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tourUrl == null) {
      return Scaffold(
        key: const ValueKey('qa.tour.screen'),
        backgroundColor: AppDesign.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: AppDesign.appBarBackground,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppDesign.appBarIcon),
            onPressed: () => Get.back(),
          ),
          title: Text(
            'virtual_tour_title'.tr,
            style: TextStyle(color: AppDesign.appBarText, fontWeight: FontWeight.bold),
          ),
        ),
        body: Semantics(label: 'qa.tour.invalid_state', child: _buildInvalidTourContent()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyBackground = isDark ? '#000' : '#fff';
    final webviewBackgroundColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return Scaffold(
      key: const ValueKey('qa.tour.screen'),
      backgroundColor: AppDesign.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppDesign.appBarIcon),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'virtual_tour_title'.tr,
          style: TextStyle(color: AppDesign.appBarText, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.fullscreen, color: AppDesign.appBarIcon),
            onPressed: () {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              AppToast.info('fullscreen_mode'.tr, 'tap_back_to_exit_fullscreen'.tr);
            },
          ),
          IconButton(
            icon: Icon(Icons.share, color: AppDesign.appBarIcon),
            onPressed: () {
              final url = _tourUrl ?? '';
              if (url.isNotEmpty) {
                SharePlus.instance.share(ShareParams(text: url, subject: 'virtual_tour_title'.tr));
              }
            },
          ),
        ],
      ),
      body: Container(
        color: AppDesign.scaffoldBackground,
        child: Stack(
          children: [
            MaxContentWidth(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppDesign.getCardShadow(),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Semantics(
                      label: 'qa.tour.webview',
                      identifier: 'qa.tour.webview',
                      child: TourWebView(
                        tourUrl: _tourUrl!,
                        backgroundColor: webviewBackgroundColor,
                        bodyBackgroundCss: bodyBackground,
                        applyPageChromeStyles: true,
                        showDefaultLoading: false,
                        showDefaultError: true,
                        onLoadingChanged: (loading) {
                          if (mounted) setState(() => _isLoading = loading);
                        },
                        onErrorChanged: (hasError) {
                          if (hasError && mounted) {
                            AppToast.error('error_loading_tour'.tr, 'check_internet_connection'.tr);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: AppDesign.scaffoldBackground,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: AppDesign.primaryYellow,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'loading_virtual_tour'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppDesign.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
