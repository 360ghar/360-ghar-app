import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

class MockVisitRepository extends Mock implements VisitsRepository {}

class TestVisitScope extends StorageScopeNotifier {
  TestVisitScope(this.database, {this.account = 'account-a'});
  final AppDatabase database;
  final String? account;
  @override
  StorageScope build() => database.activateScope(environment: 'test', accountId: account);
  void change(String? account) =>
      state = database.activateScope(environment: 'test', accountId: account);
}

Future<AppDatabase> visitTestDatabase() {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfi,
    databasePath: inMemoryDatabasePath,
    legacyReader: () async => {},
  );
}

VisitModel visitFixture({
  int id = 1,
  int propertyId = 100,
  DateTime? date,
  VisitStatus status = VisitStatus.scheduled,
  PropertyModel? property,
}) => VisitModel(
  id: id,
  propertyId: propertyId,
  userId: 1,
  scheduledDate: date ?? DateTime.now().add(const Duration(days: 7)),
  status: status,
  createdAt: DateTime.utc(2024),
  property: property,
);
AgentModel agentFixture({String? phone}) => AgentModel(
  id: 1,
  name: 'Test Agent',
  contactNumber: phone,
  agentType: AgentType.general,
  experienceLevel: ExperienceLevel.intermediate,
  createdAt: DateTime.utc(2024),
);
PropertyModel propertyFixture({int id = 100}) => PropertyModel(
  id: id,
  ownerId: 7,
  createdAt: DateTime.utc(2026, 9, 30),
  updatedAt: DateTime.utc(2026, 9, 30),
  title: 'Test Property $id',
  purpose: PropertyPurpose.buy,
  basePrice: 5000000,
  images: const [],
  isAvailable: true,
  viewCount: 0,
  likeCount: 0,
  interestCount: 0,
);

class SeededVisitsController extends VisitsController {
  SeededVisitsController(this.initial);
  final VisitsState initial;
  int loads = 0, pages = 0, agents = 0, bookings = 0, cancellations = 0, reschedules = 0;
  bool mutationResult = true;
  bool reconciliationFound = false;
  int reconciliations = 0;
  @override
  Future<bool> reconcile(PendingAction action) async {
    reconciliations++;
    return reconciliationFound;
  }

  VisitRequestResult? bookingResult;
  String? lastNotes;
  int? lastProperty;
  DateTime? lastDate;
  String? lastReason;
  @override
  VisitsState build() => initial;
  void replace(VisitsState value) => state = value;
  @override
  Future<void> loadVisits() async {
    loads++;
  }

  @override
  Future<void> loadMoreVisits() async {
    pages++;
  }

  @override
  Future<void> loadRelationshipManager() async {
    agents++;
  }

  @override
  Future<VisitRequestResult> bookVisit(int propertyId, DateTime date, {String? notes}) async {
    bookings++;
    lastProperty = propertyId;
    lastDate = date;
    lastNotes = notes;
    return bookingResult ?? VisitConfirmed(visitFixture());
  }

  @override
  Future<bool> cancelVisit(int visitId, {required String reason}) async {
    cancellations++;
    lastReason = reason;
    return mutationResult;
  }

  @override
  Future<bool> rescheduleVisit(int visitId, DateTime date, {String? reason}) async {
    reschedules++;
    lastDate = date;
    return mutationResult;
  }
}

class SeededPendingActions extends PendingActionsController {
  SeededPendingActions([this.initial = const []]);
  final List<PendingAction> initial;
  String? discarded;
  @override
  PendingActionsState build() =>
      PendingActionsState(actions: initial, phase: PendingActionsPhase.ready);
  @override
  Future<void> reload() async {}
  @override
  Future<void> discard(String operationId) async {
    discarded = operationId;
    state = PendingActionsState(
      actions: state.actions.where((action) => action.operationId != operationId).toList(),
      phase: PendingActionsPhase.ready,
    );
  }
}
