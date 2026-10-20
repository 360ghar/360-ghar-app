// Contract tests: parse backend-shaped responses with the app's models.
//
// The fixtures in test/fixtures/api/ are written by tool/api_fixtures.py. Each one is sample data
// validated through the backend's own Pydantic response model and dumped the way FastAPI does it
// (`mode="json"`), so it carries every key, default and format the backend sends. The schema
// checks below compare each model with `schemas.json`, which holds the required and nullable keys
// of the OpenAPI schema. Regenerate both after a backend change and run `flutter test
// test/contract`.

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/static_page_model.dart';
import 'package:ghar360/core/data/models/swipe_models.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';
import 'contract_support.dart';

/// One response schema, a sample body of it and the app's parser for it.
class _Case {
  const _Case(
    this.schema,
    this.sample,
    this.parse,
    this.keys, {
    this.unread = const {},
    this.sharedModelKeys = const {},
  });

  final String schema;
  final Map<String, dynamic> Function() sample;

  /// Parses [sample]. Throws when the body does not match the model.
  final Object Function(Map<String, dynamic> body) parse;

  /// The keys of the model after parsing, as it writes them back with `toJson`.
  final Set<String> Function(Object parsed) keys;

  /// Schema keys that no screen shows and the model does not read.
  final Set<String> unread;

  /// Keys the model also reads for a sibling schema that shares it (`PropertyModel` serves the
  /// `Property` list row and `PropertyDetail`, which adds `agent`).
  final Set<String> sharedModelKeys;
}

final _schemas = asObject(apiFixture('schemas'));

Map<String, dynamic> _first(Object? page) => pageItems(page).first;

final _cases = <_Case>[
  _Case(
    'SelfUser',
    () => asObject(apiFixture('users')['profile']),
    UserModel.fromJson,
    (m) => (m as UserModel).toJson().keys.toSet(),
    unread: {'last_auth_method', 'last_auth_method_at'},
  ),
  _Case(
    'UserPreferences',
    () => asObject(apiFixture('users')['preferences']),
    UserPreferences.fromJson,
    (m) => (m as UserPreferences).toJson().keys.toSet(),
  ),
  _Case(
    'NotificationSettings',
    () => asObject(apiFixture('users')['notification_settings']),
    UserNotificationSettings.fromJson,
    (m) => (m as UserNotificationSettings).toJson().keys.toSet(),
  ),
  _Case(
    'PrivacySettings',
    () => asObject(apiFixture('users')['privacy_settings']),
    UserPrivacySettings.fromJson,
    (m) => (m as UserPrivacySettings).toJson().keys.toSet(),
  ),
  _Case(
    'Property',
    () => _first(apiFixture('properties')['list_page']),
    PropertyModel.fromJson,
    (m) => (m as PropertyModel).toJson().keys.toSet(),
    unread: {'society_type'},
    sharedModelKeys: {
      'agent',
      'user_has_scheduled_visit',
      'user_next_visit_date',
      'user_scheduled_visit_count',
    },
  ),
  _Case(
    'PropertyDetail',
    () => asObject(apiFixture('properties')['detail']),
    PropertyModel.fromJson,
    (m) => (m as PropertyModel).toJson().keys.toSet(),
    unread: {
      'is_managed',
      'management_status',
      'payment_due_day',
      'grace_period_days',
      'late_fee_policy',
      'current_lease_id',
      'current_tenant_id',
      'compatibility_score',
      'search_keywords',
    },
  ),
  _Case(
    'PropertyImage',
    () => _first(apiFixture('properties')['list_page'])['images'] is List
        ? asObject((_first(apiFixture('properties')['list_page'])['images'] as List).first)
        : {},
    PropertyImageModel.fromJson,
    (m) => (m as PropertyImageModel).toJson().keys.toSet(),
  ),
  _Case(
    'PropertyAgent',
    () => asObject(apiFixture('properties')['detail']['agent']),
    PropertyAgent.fromJson,
    (m) => (m as PropertyAgent).toJson().keys.toSet(),
  ),
  _Case(
    'PropertyAmenityResponse',
    () => asObject((_first(apiFixture('properties')['list_page'])['amenities'] as List).first),
    PropertyAmenity.fromJson,
    (m) => (m as PropertyAmenity).toJson().keys.toSet(),
  ),
  _Case(
    'Amenity',
    () => _first(apiFixture('amenities')['page']),
    PropertyAmenity.fromJson,
    (m) => (m as PropertyAmenity).toJson().keys.toSet(),
    unread: {'created_at', 'updated_at', 'is_active'},
  ),
  _Case(
    'Visit',
    () => _first(apiFixture('visits')['list_page']),
    VisitModel.fromJson,
    (m) => (m as VisitModel).toJson().keys.toSet(),
  ),
  _Case(
    'VisitAgentInfo',
    () => asObject(_first(apiFixture('visits')['list_page'])['agents']),
    VisitAgentInfo.fromJson,
    (m) => (m as VisitAgentInfo).toJson().keys.toSet(),
  ),
  _Case(
    'PublicUserRef',
    () => asObject(_first(apiFixture('visits')['list_page'])['counterparty_user']),
    PublicUserRef.fromJson,
    (m) => (m as PublicUserRef).toJson().keys.toSet(),
  ),
  _Case(
    'Agent',
    () => asObject(apiFixture('agents')['assigned']),
    AgentModel.fromJson,
    (m) => (m as AgentModel).toJson().keys.toSet(),
  ),
  _Case(
    'SwipeOut',
    () => asObject(apiFixture('swipes')['recorded']),
    SwipeOut.fromJson,
    (m) => (m as SwipeOut).toJson().keys.toSet(),
  ),
  _Case(
    'BugReportResponse',
    () => asObject(apiFixture('support')['bug']),
    BugReportResponse.fromJson,
    (m) => (m as BugReportResponse).toJson().keys.toSet(),
  ),
  _Case(
    'PagePublicResponse',
    () => asObject(apiFixture('pages')['privacy']),
    StaticPageModel.fromJson,
    (m) => (m as StaticPageModel).toJson().keys.toSet(),
    unread: {'custom_config', 'view_count'},
  ),
  _Case(
    'IdentifierStatusResponse',
    () => asObject(apiFixture('auth')['identifier_status']),
    IdentifierStatus.fromJson,
    (m) => {'exists', 'verified', 'has_password', 'channel', 'next_step'},
  ),
  _Case(
    'AppVersionCheckResponse',
    () => asObject(apiFixture('versions')['check_response']),
    AppVersionCheckResponse.fromJson,
    (m) => (m as AppVersionCheckResponse).toJson().keys.toSet(),
  ),
  _Case(
    'ConversationMessageOut',
    () => _first(apiFixture('assistant')['messages_page']),
    ChatMessageModel.fromJson,
    (m) => {'id', 'role', 'created_at'},
  ),
  _Case(
    'AIConversationSummary',
    () => _first(apiFixture('assistant')['conversations_page']),
    ConversationModel.fromJson,
    (m) => (m as ConversationModel).toJson().keys.toSet(),
  ),
];

void main() {
  group('fixtures parse with the app models', () {
    test('GET /properties page: four purposes and types', () {
      final page = UnifiedPropertyResponse.fromJson(
        asObject(apiFixture('properties')['list_page']),
      );

      expect(page.items.map((p) => p.id), [1, 2, 3, 4]);
      expect(page.hasMorePages, isTrue);
      expect(page.limit, 20);
      expect(page.total, isNull, reason: 'total is null without include_total');
      expect(page.items.map((p) => p.purpose), [
        PropertyPurpose.buy,
        PropertyPurpose.rent,
        PropertyPurpose.shortStay,
        PropertyPurpose.rent,
      ]);
    });

    test('the price field follows the purpose', () {
      final page = UnifiedPropertyResponse.fromJson(
        asObject(apiFixture('properties')['list_page']),
      );

      expect(page.items[0].effectivePrice, 8500000, reason: 'buy: base_price');
      expect(page.items[1].effectivePrice, 45000, reason: 'rent: monthly_rent');
      expect(page.items[2].effectivePrice, 3500, reason: 'short stay: nightly_rate');
      expect(page.items[2].nightlyRate, 3500);
      expect(page.items[2].dailyRate, 3500);
      expect(page.items[3].effectivePrice, 12000);
    });

    test('price_per_sqft is the backend value for the purpose price', () {
      final page = UnifiedPropertyResponse.fromJson(
        asObject(apiFixture('properties')['list_page']),
      );

      // 8,500,000 over 1,450 sq ft; rent 45,000 over 1,450; a short stay 3,500 over 1,450.
      expect(page.items[0].pricePerSqft, closeTo(5862.07, 0.01));
      expect(page.items[1].pricePerSqft, closeTo(31.03, 0.01));
      expect(page.items[2].pricePerSqft, closeTo(2.41, 0.01));
    });

    test('amenity ids are amenity ids and floor plans are split out of images', () {
      final property = PropertyModel.fromJson(asObject(apiFixture('properties')['detail']));

      expect(property.amenities!.map((a) => a.id), [11, 12]);
      expect(property.galleryImages.map((i) => i.category), [
        ImageCategory.hall,
        ImageCategory.kitchen,
      ]);
      expect(property.floorPlanImages, hasLength(1));
      expect(property.images!.any((i) => i.isFloorPlan), isFalse);
    });

    test('the detail route carries the agent, and the agent number is the contact', () {
      final property = PropertyModel.fromJson(asObject(apiFixture('properties')['detail']));

      expect(property.agent?.name, 'Ravi Kumar');
      expect(property.contactNumber, '+919811111111');
      expect(property.userHasScheduledVisit, isTrue);
      expect(property.userScheduledVisitCount, 1);
      expect(property.listingPreferences?.sharingType, ListingSharingType.entireFlat);
      expect(property.availableFrom, DateTime(2026, 11));
    });

    test('a list item has no agent, so the company number the server chose is the contact', () {
      final property = PropertyModel.fromJson(_first(apiFixture('properties')['list_page']));

      expect(property.agent, isNull);
      expect(property.contactNumber, '+911800000360');
    });

    test('rent, short stay and PG listings read their own price fields', () {
      final rent = PropertyModel.fromJson(asObject(apiFixture('properties')['detail_rent']));
      final stay = PropertyModel.fromJson(asObject(apiFixture('properties')['detail_short_stay']));
      final pg = PropertyModel.fromJson(asObject(apiFixture('properties')['detail_pg']));

      expect(rent.monthlyRent, 45000);
      expect(rent.securityDeposit, 90000);
      expect(stay.nightlyRate, 3500);
      expect(stay.effectivePrice, 3500);
      expect(pg.setupCost, 5000);
      expect(pg.otherCharges, 1200);
      expect(pg.furnishingLevel, FurnishingLevel.semiFurnished);
      expect(pg.kitchenType, KitchenType.vegetarian);
      expect(pg.ventilationType, VentilationType.good);
      expect(pg.listingPreferences?.sharingType, ListingSharingType.masterBedroom);
      expect(pg.listingPreferences?.genderPreference, ListingGenderPreference.female);
    });

    test('GET /swipes page reads liked', () {
      final page = UnifiedPropertyResponse.fromJson(asObject(apiFixture('swipes')['history_page']));

      expect(page.items.single.liked, isTrue);
    });

    test('POST /swipes: SwipeOut for a new swipe and for an update', () {
      final recorded = SwipeOut.fromJson(asObject(apiFixture('swipes')['recorded']));
      final updated = SwipeOut.fromJson(asObject(apiFixture('swipes')['updated']));

      expect(recorded.id, 301);
      expect(recorded.propertyId, 3);
      expect(recorded.isLiked, isTrue);
      expect(updated.isLiked, isFalse);
    });

    group('visits', () {
      final visits = pageItems(apiFixture('visits')['list_page']).map(VisitModel.fromJson).toList();

      test('a flatmate meet shows its counterparty by name and avatar', () {
        final meet = visits.first;

        expect(meet.isFlatmateMeet, isTrue);
        expect(meet.counterpartyUser?.displayName, 'Karan Mehta');
        expect(meet.counterpartyUser?.avatarUrl, isNull);
        expect(meet.conversationId, 8);
        expect(meet.matchId, 9);
        expect(meet.user?.displayName, 'Asha Verma');
      });

      test('time_slot_label, the nested property and the agent are read', () {
        final visit = visits.first;

        expect(visit.timeSlotLabel, 'morning');
        expect(visit.propertyTitle, '3 BHK in Sector 51');
        expect(visit.agents?.name, 'Ravi Kumar');
        expect(visit.agentPhone, '+919811111111');
        expect(visit.scheduledDate, DateTime.utc(2026, 10, 4, 5, 30));
        expect(visit.status, VisitStatus.scheduled);
      });

      test('a visit without a property, agent or slot', () {
        final done = visits.last;

        expect(done.property, isNull);
        expect(done.agents, isNull);
        expect(done.timeSlotLabel, isNull);
        expect(done.status, VisitStatus.completed);
        expect(done.visitContext, VisitContext.propertyTour);
      });

      test('cancel and reschedule answer with the updated Visit', () {
        final cancelled = VisitModel.fromJson(asObject(apiFixture('visits')['cancelled']));
        final moved = VisitModel.fromJson(asObject(apiFixture('visits')['rescheduled']));

        expect(cancelled.status, VisitStatus.cancelled);
        expect(cancelled.cancellationReason, 'Plans changed');
        expect(moved.status, VisitStatus.rescheduled);
        expect(moved.rescheduledFrom, DateTime.utc(2026, 10, 4, 5, 30));
        expect(moved.cancellationReason, 'Traffic', reason: 'a reschedule reason is stored here');
      });
    });

    test('GET /agents/assigned', () {
      final agent = AgentModel.fromJson(asObject(apiFixture('agents')['assigned']));

      expect(agent.name, 'Ravi Kumar');
      expect(agent.userSatisfactionRating, 4.6);
      expect(agent.agentType, AgentType.general);
      expect(agent.experienceLevel, ExperienceLevel.intermediate);
    });

    test('users: SelfUser, with the typed objects the backend always sends', () {
      final user = UserModel.fromJson(asObject(apiFixture('users')['profile']));

      expect(user.id, 50);
      expect(user.supabaseUserId, isNotEmpty);
      expect(user.role, UserRole.user);
      expect(user.preferences.purpose, PropertyPurpose.rent);
      expect(user.notificationSettings.pushNotifications, isTrue);
      expect(user.privacySettings.profileVisibility, ProfileVisibility.agentsOnly);
      expect(user.dateOfBirth, '1994-02-11');
    });

    test('users: a bare account has null contact fields and default typed objects', () {
      final user = UserModel.fromJson(asObject(apiFixture('users')['profile_minimal']));

      expect(user.email, isNull);
      expect(user.phone, isNull);
      expect(user.fullName, isNull);
      expect(user.isProfileComplete, isFalse);
      expect(user.preferences.purpose, isNull);
      expect(user.preferences.maxDistanceKm, 5, reason: 'the backend default');
      expect(user.notificationSettings.promotionalEmails, isFalse, reason: 'missing is opt-out');
    });

    test('support, pages, auth and versions', () {
      expect(BugReportResponse.fromJson(asObject(apiFixture('support')['bug'])).id, 3);
      final page = StaticPageModel.fromJson(asObject(apiFixture('pages')['privacy']));
      expect(page.title, 'Privacy policy');
      expect(page.isRenderable, isTrue);
      expect(StaticPageModel.fromJson(asObject(apiFixture('pages')['html'])).isRenderable, isFalse);
      final status = IdentifierStatus.fromJson(asObject(apiFixture('auth')['identifier_status']));
      expect(status.channel, IdentifierChannel.phone);
      expect(status.nextStep, IdentifierNextStep.otp);
      final emailStatus = IdentifierStatus.fromJson(
        asObject(apiFixture('auth')['identifier_status_email']),
      );
      expect(emailStatus.channel, IdentifierChannel.email);
      expect(emailStatus.nextStep, IdentifierNextStep.password);
      expect(emailStatus.isPasswordStep, isTrue);
      final check = AppVersionCheckResponse.fromJson(
        asObject(apiFixture('versions')['check_response']),
      );
      expect(check.updateAvailable, isTrue);
      expect(check.minSupportedVersion, '3.0.0');
    });

    test('assistant: conversation and message pages', () {
      final conversations = pageItems(
        apiFixture('assistant')['conversations_page'],
      ).map(ConversationModel.fromJson).toList();
      final messages = pageItems(
        apiFixture('assistant')['messages_page'],
      ).map(ChatMessageModel.fromJson).toList();

      expect(conversations.single.id, 42);
      expect(conversations.single.updatedAt, DateTime.utc(2026, 9, 30, 10, 15, 2));
      expect(messages.map((m) => m.role), [ChatRole.user, ChatRole.widget, ChatRole.assistant]);
      expect(messages[1].widgetName, 'PropertySearchWidget');
      expect(messages[1].widgetData?['items'], isA<List>());
    });
  });

  group('every model requires the keys its schema requires', () {
    for (final contract in _cases) {
      group(contract.schema, () {
        final schema = asObject(_schemas[contract.schema]);
        final required = List<String>.from(schema['required'] as List);
        final nullable = List<String>.from(schema['nullable'] as List).toSet();
        final enums = List<String>.from(schema['enums'] as List).toSet();

        test('the fixture parses', () {
          expect(() => contract.parse(contract.sample()), returnsNormally);
        });

        test('required keys the model reads are required', () {
          final parsed = contract.parse(contract.sample());
          final read = contract.keys(parsed);
          for (final key in required) {
            if (contract.unread.contains(key)) continue;
            expect(read, contains(key), reason: '${contract.schema}.$key is required but unread');
            final body = contract.sample()..remove(key);
            expect(
              () => contract.parse(body),
              throwsA(anything),
              reason: '${contract.schema} parses without required key $key',
            );
          }
        });

        test('a required key that is not nullable rejects null', () {
          for (final key in required) {
            if (contract.unread.contains(key) || nullable.contains(key) || enums.contains(key)) {
              continue;
            }
            final body = contract.sample()..[key] = null;
            expect(
              () => contract.parse(body),
              throwsA(anything),
              reason: '${contract.schema}.$key accepts null',
            );
          }
        });

        test('a nullable required key accepts null', () {
          for (final key in required) {
            if (contract.unread.contains(key) || !nullable.contains(key)) continue;
            final body = contract.sample()..[key] = null;
            expect(
              () => contract.parse(body),
              returnsNormally,
              reason: '${contract.schema}.$key rejects null',
            );
          }
        });

        test('the model reads no key the backend does not define', () {
          final defined = List<String>.from(schema['properties'] as List).toSet();
          final read = contract.keys(contract.parse(contract.sample()));
          for (final key in read.difference(contract.sharedModelKeys)) {
            expect(defined, contains(key), reason: '${contract.schema} has no key $key');
          }
        });
      });
    }
  });
}
