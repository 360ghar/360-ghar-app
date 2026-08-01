import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:shimmer/shimmer.dart';

class ToolCallIndicator extends StatelessWidget {
  final String toolName;

  const ToolCallIndicator({super.key, required this.toolName});

  @override
  Widget build(BuildContext context) {
    final palette = context.design;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 48, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppDesign.accentBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppDesign.accentBlue.withValues(alpha: 0.2)),
          ),
          child: Shimmer.fromColors(
            baseColor: palette.textSecondary,
            highlightColor: AppDesign.accentBlue,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppDesign.accentBlue),
                ),
                const SizedBox(width: 8),
                Text(_humanizeToolName(toolName), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _humanizeToolName(String tool) {
    // Convert snake_case tool names to readable labels
    final mapping = {
      'discovery_search': 'assistant_tool_searching_properties'.tr,
      'discovery_property_get': 'assistant_tool_fetching_property'.tr,
      'discovery_recommendations': 'assistant_tool_searching_properties'.tr,
      'owner_properties_list': 'assistant_tool_loading_my_properties'.tr,
      'owner_properties_get': 'assistant_tool_fetching_property'.tr,
      'owner_properties_create': 'assistant_tool_creating_property'.tr,
      'owner_properties_update': 'assistant_tool_fetching_property'.tr,
      'bookings_check_availability': 'assistant_tool_checking_availability'.tr,
      'bookings_create': 'assistant_tool_scheduling_visit'.tr,
      'bookings_list': 'assistant_tool_loading_bookings'.tr,
      'bookings_get': 'assistant_tool_loading_bookings'.tr,
      'bookings_cancel': 'assistant_tool_loading_bookings'.tr,
      'tenant_lease_current': 'assistant_tool_loading_lease'.tr,
      'tenant_rent_history': 'assistant_tool_loading_rent'.tr,
      'tenant_maintenance_create': 'assistant_tool_creating_request'.tr,
      'tenant_maintenance_list': 'assistant_tool_loading_bookings'.tr,
      'agent_dashboard_overview': 'assistant_tool_loading_dashboard'.tr,
    };

    return mapping[tool] ?? 'assistant_tool_executing'.tr;
  }
}
