import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/features/tools/presentation/controllers/tools_controller.dart';
import 'package:ghar360/features/tools/presentation/widgets/tool_card.dart';

class ToolsView extends GetView<ToolsController> {
  const ToolsView({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = [
      ToolItem(
        icon: Icons.square_foot_outlined,
        title: 'area_converter'.tr,
        description: 'area_converter_desc'.tr,
        qaKey: 'qa.tools.menu.area_converter',
        route: AppRoutes.areaConverter,
      ),
      ToolItem(
        icon: Icons.account_balance_outlined,
        title: 'loan_eligibility'.tr,
        description: 'loan_eligibility_desc'.tr,
        qaKey: 'qa.tools.menu.loan_eligibility',
        route: AppRoutes.loanEligibility,
      ),
      ToolItem(
        icon: Icons.calculate_outlined,
        title: 'emi_calculator'.tr,
        description: 'emi_calculator_desc'.tr,
        qaKey: 'qa.tools.menu.emi_calculator',
        route: AppRoutes.emiCalculator,
      ),
      ToolItem(
        icon: Icons.home_work_outlined,
        title: 'carpet_area_calculator'.tr,
        description: 'carpet_area_desc'.tr,
        qaKey: 'qa.tools.menu.carpet_area',
        route: AppRoutes.carpetArea,
      ),
      ToolItem(
        icon: Icons.checklist_outlined,
        title: 'document_checklist'.tr,
        description: 'document_checklist_desc'.tr,
        qaKey: 'qa.tools.menu.document_checklist',
        route: AppRoutes.documentChecklist,
      ),
      ToolItem(
        icon: Icons.receipt_long_outlined,
        title: 'capital_gains'.tr,
        description: 'capital_gains_desc'.tr,
        qaKey: 'qa.tools.menu.capital_gains',
        route: AppRoutes.capitalGains,
      ),
    ];

    return Scaffold(
      key: const ValueKey('qa.tools.screen'),
      backgroundColor: AppDesign.background,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'back'.tr,
          icon: Icon(Icons.arrow_back, color: AppDesign.iconColor),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tools_calculators'.tr,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppDesign.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'tools_subtitle'.tr,
                style: TextStyle(fontSize: 14, color: AppDesign.textSecondary),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: tools.length,
                  itemBuilder: (context, index) {
                    final tool = tools[index];
                    return ToolCard(
                      icon: tool.icon,
                      title: tool.title,
                      description: tool.description,
                      qaKey: tool.qaKey,
                      onTap: () => Get.toNamed(tool.route),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToolItem {
  final IconData icon;
  final String title;
  final String description;
  final String? qaKey;
  final String route;

  const ToolItem({
    required this.icon,
    required this.title,
    required this.description,
    this.qaKey,
    required this.route,
  });
}
