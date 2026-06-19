import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_mapper.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

class PropertyDetailsController extends GetxController {
  final Rxn<PropertyModel> property = Rxn<PropertyModel>();
  final RxBool isLoading = true.obs;
  final RxnString errorKey = RxnString();
  final RxnString errorDetail = RxnString();

  late final PropertiesRepository _propertiesRepository;

  @override
  void onInit() {
    super.onInit();
    _propertiesRepository = Get.find<PropertiesRepository>();
    // VisitsController may not be registered when deep-linking directly to a
    // property (it is registered by the dashboard binding). Guard against its
    // absence so the property details screen still loads.
    if (Get.isRegistered<VisitsController>()) {
      _ensureVisitsLoaded();
    }
    _resolveProperty();
  }

  void _ensureVisitsLoaded() {
    if (!Get.isRegistered<VisitsController>()) return;
    final visits = Get.find<VisitsController>();
    if (!visits.hasLoadedVisits.value && !visits.isLoading.value) {
      visits.loadVisitsLazy();
    }
  }

  dynamic _extractPropertyOrId(dynamic arguments) {
    if (arguments is PropertyModel || arguments is String || arguments is int) {
      return arguments;
    }

    if (arguments is Map) {
      final dynamic embeddedProperty = arguments['property'];
      if (embeddedProperty is PropertyModel) return embeddedProperty;

      final dynamic embeddedId =
          arguments['id'] ?? arguments['propertyId'] ?? arguments['property_id'];
      if (embeddedId is String || embeddedId is int) return embeddedId;
    }

    return arguments;
  }

  Future<void> _resolveProperty() async {
    isLoading.value = true;
    errorKey.value = null;
    errorDetail.value = null;

    dynamic id = _extractPropertyOrId(Get.arguments);
    final urlId = Get.parameters['id'];
    if (urlId != null && urlId.isNotEmpty) {
      id = urlId;
    }

    if (id is PropertyModel) {
      property.value = id;
      isLoading.value = false;
      return;
    }

    if (id is String || id is int) {
      final int? propertyId = id is int ? id : int.tryParse(id as String);
      if (propertyId == null) {
        _setError('invalid_property_id');
        return;
      }
      try {
        final fetched = await _propertiesRepository.getPropertyDetail(propertyId);
        property.value = fetched;
      } catch (e, stackTrace) {
        DebugLogger.error('Failed to load property details', e, stackTrace);
        final mapped = ErrorMapper.mapApiError(e, stackTrace);
        errorDetail.value = mapped.message;
        errorKey.value = 'property_load_failed';
      } finally {
        isLoading.value = false;
      }
      return;
    }

    _setError('property_not_found');
  }

  void _setError(String key) {
    errorKey.value = key;
    isLoading.value = false;
  }

  String? get errorMessage {
    final key = errorKey.value;
    if (key == null) return null;
    if (key == 'property_load_failed') {
      final detail = errorDetail.value ?? 'unknown_error'.tr;
      return 'property_load_failed'.trParams({'error': detail});
    }
    return key.tr;
  }
}
