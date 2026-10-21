import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/features/assistant/presentation/widgets/paper_note.dart';

/// The l10n key of the line shown while one assistant tool runs. Every tool the backend registers
/// has an entry (`tool-names.json`, 52 names); a tool with no specific line shows the generic
/// `assistant_tool_executing`. A name this app does not know gets the generic line too.
const toolLabelKeys = <String, String>{
  'admin_system_status': 'assistant_tool_executing',
  'agent_bookings_list_all': 'assistant_tool_loading_bookings',
  'agent_bookings_update_status': 'assistant_tool_executing',
  'agent_dashboard_overview': 'assistant_tool_loading_dashboard',
  'agent_leases_create': 'assistant_tool_executing',
  'agent_leases_list': 'assistant_tool_loading_lease',
  'agent_leases_terminate': 'assistant_tool_executing',
  'agent_maintenance_list': 'assistant_tool_executing',
  'agent_maintenance_update_status': 'assistant_tool_executing',
  'agent_properties_create_for_owner': 'assistant_tool_creating_property',
  'agent_properties_get': 'assistant_tool_fetching_property',
  'agent_properties_list': 'assistant_tool_loading_my_properties',
  'agent_properties_verify': 'assistant_tool_executing',
  'agent_rent_list_due': 'assistant_tool_loading_rent',
  'agent_rent_record_payment': 'assistant_tool_executing',
  'bookings_cancel': 'assistant_tool_executing',
  'bookings_check_availability': 'assistant_tool_checking_availability',
  'bookings_create': 'assistant_tool_executing',
  'bookings_get': 'assistant_tool_loading_bookings',
  'bookings_get_pricing': 'assistant_tool_loading_bookings',
  'bookings_list': 'assistant_tool_loading_bookings',
  'discovery_amenities': 'assistant_tool_searching_properties',
  'discovery_feed': 'assistant_tool_searching_properties',
  'discovery_property_get': 'assistant_tool_fetching_property',
  'discovery_recommendations': 'assistant_tool_searching_properties',
  'discovery_search': 'assistant_tool_searching_properties',
  'discovery_shortlist': 'assistant_tool_executing',
  'discovery_swipe': 'assistant_tool_executing',
  'owner_dashboard_overview': 'assistant_tool_loading_dashboard',
  'owner_leases_get': 'assistant_tool_loading_lease',
  'owner_leases_list': 'assistant_tool_loading_lease',
  'owner_leases_terminate': 'assistant_tool_executing',
  'owner_maintenance_list': 'assistant_tool_executing',
  'owner_maintenance_update': 'assistant_tool_executing',
  'owner_properties_create': 'assistant_tool_creating_property',
  'owner_properties_get': 'assistant_tool_fetching_property',
  'owner_properties_list': 'assistant_tool_loading_my_properties',
  'owner_properties_toggle_availability': 'assistant_tool_executing',
  'owner_properties_update': 'assistant_tool_executing',
  'owner_rent_history': 'assistant_tool_loading_rent',
  'owner_rent_record_payment': 'assistant_tool_executing',
  'owner_rent_status': 'assistant_tool_loading_rent',
  'tenant_lease_current': 'assistant_tool_loading_lease',
  'tenant_maintenance_create': 'assistant_tool_creating_request',
  'tenant_maintenance_list': 'assistant_tool_executing',
  'tenant_rent_dues': 'assistant_tool_loading_rent',
  'tenant_rent_history': 'assistant_tool_loading_rent',
  'user_system_status': 'assistant_tool_executing',
  'visits_cancel': 'assistant_tool_executing',
  'visits_get': 'assistant_tool_executing',
  'visits_list': 'assistant_tool_executing',
  'visits_schedule': 'assistant_tool_scheduling_visit',
};

class ToolCallIndicator extends StatelessWidget {
  final String toolName;

  const ToolCallIndicator({super.key, required this.toolName});

  @override
  Widget build(BuildContext context) {
    final palette = context.design;

    // One quiet line under the conversation: the kite rocks while a tool runs.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 48, 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          liveRegion: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AssistantKite(size: 18, sway: true),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  context.l10n.text(toolLabelKeys[toolName] ?? 'assistant_tool_executing'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
