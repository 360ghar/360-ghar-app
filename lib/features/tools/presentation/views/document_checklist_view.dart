import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/features/tools/presentation/controllers/document_checklist_controller.dart';

class DocumentChecklistView extends GetView<DocumentChecklistController> {
  const DocumentChecklistView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('qa.tools.document_checklist.screen'),
      backgroundColor: AppDesign.background,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        title: Text(
          'document_checklist'.tr,
          style: TextStyle(color: AppDesign.appBarText, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          tooltip: 'back'.tr,
          icon: Icon(Icons.arrow_back, color: AppDesign.iconColor),
          onPressed: () => Get.back(),
        ),
        actions: [
          Semantics(
            label: 'qa.tools.document_checklist.reset',
            identifier: 'qa.tools.document_checklist.reset',
            child: IconButton(
              key: const ValueKey('qa.tools.document_checklist.reset'),
              icon: Icon(Icons.refresh, color: AppDesign.iconColor),
              onPressed: () => _showResetDialog(context),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Obx(
            () => Container(
              padding: const EdgeInsets.all(16),
              color: AppDesign.cardBackground,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'progress'.tr,
                        style: TextStyle(fontSize: 14, color: AppDesign.textSecondary),
                      ),
                      Text(
                        '${controller.checkedItems.value}/${controller.totalItems.value}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppDesign.primaryYellow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: controller.progress,
                      backgroundColor: AppDesign.inputBackground,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        controller.progress == 1.0
                            ? AppDesign.accentGreen
                            : AppDesign.primaryYellow,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.categories.length,
                itemBuilder: (context, index) {
                  final category = controller.categories[index];
                  return _buildCategorySection(category);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(DocumentCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.titleKey.tr,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppDesign.textPrimary),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppDesign.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: category.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == category.items.length - 1;
              return Column(
                children: [
                  _buildDocumentItem(item),
                  if (!isLast) Divider(height: 1, indent: 56, color: AppDesign.divider),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDocumentItem(DocumentItem item) {
    return InkWell(
      onTap: () => controller.toggleItem(item.id),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.isChecked ? AppDesign.accentGreen : AppDesign.inputBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: item.isChecked
                  ? const Icon(Icons.check, color: AppDesignTokens.neutralWhite, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titleKey.tr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: item.isChecked ? AppDesign.textSecondary : AppDesign.textPrimary,
                      decoration: item.isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.descriptionKey.tr,
                    style: TextStyle(fontSize: 12, color: AppDesign.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppDesign.cardBackground,
        title: Text('reset_checklist'.tr, style: TextStyle(color: AppDesign.textPrimary)),
        content: Text(
          'reset_checklist_confirm'.tr,
          style: TextStyle(color: AppDesign.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          Semantics(
            label: 'qa.tools.document_checklist.reset_confirm',
            identifier: 'qa.tools.document_checklist.reset_confirm',
            child: FilledButton(
              key: const ValueKey('qa.tools.document_checklist.reset_confirm'),
              onPressed: () {
                controller.resetAll();
                Get.back();
              },
              child: Text('reset'.tr),
            ),
          ),
        ],
      ),
    );
  }
}
