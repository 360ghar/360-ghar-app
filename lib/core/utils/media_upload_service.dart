import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:image_picker/image_picker.dart';

class MediaUploadResult {
  final String url;
  final String storagePath;
  final int? bytes;
  final Duration? duration;
  final String? mimeType;

  const MediaUploadResult({
    required this.url,
    required this.storagePath,
    this.bytes,
    this.duration,
    this.mimeType,
  });
}

class MediaUploadService {
  MediaUploadService({required this._apiClient});

  final ApiClient _apiClient;
  final ImagePicker _picker = ImagePicker();

  static const int _maxImageBytes = 10 * 1024 * 1024; // 10 MB
  static const int _maxVideoBytes = 100 * 1024 * 1024; // 100 MB
  static const _allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
  static const _allowedVideoExtensions = {'mp4', 'mov', 'avi', 'webm'};

  Future<MediaUploadResult?> pickAndUploadImage({
    required int propertyId,
    bool markAsMain = false,
    String category = 'gallery',
  }) async {
    if (kIsWeb) {
      DebugLogger.warning('Image picking not supported on web sandbox');
      return null;
    }
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (file == null) return null;

    final ext = _fileExtension(file.path, fallback: 'jpg');
    if (!_allowedImageExtensions.contains(ext)) {
      DebugLogger.warning('Rejected image with disallowed extension: $ext');
      AppToast.warning(
        'invalid_image_format'.tr,
        'unsupported_image_extension'.trParams({'ext': ext}),
      );
      return null;
    }

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _maxImageBytes) {
      DebugLogger.warning(
        'Rejected image exceeding size limit: '
        '${(bytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)} MB',
      );
      AppToast.warning('image_too_large'.tr, 'image_size_limit_exceeded'.tr);
      return null;
    }

    try {
      final response = await _apiClient.upload(
        ApiPaths.upload,
        field: 'file',
        filePath: file.path,
        fields: {'folder': 'property_image', 'visibility': 'public'},
      );

      final data = response.body as Map<String, dynamic>;
      final url = data['public_url'] as String? ?? '';
      if (url.isEmpty) {
        DebugLogger.warning('Upload succeeded but no URL returned');
        return null;
      }

      return MediaUploadResult(
        url: url,
        storagePath: data['file_path'] as String? ?? '',
        bytes: bytes.lengthInBytes,
        mimeType: 'image/$ext',
      );
    } catch (e, st) {
      DebugLogger.error('Failed to upload image', e, st);
      return null;
    }
  }

  Future<MediaUploadResult?> pickAndUploadVideo({
    required int propertyId,
  }) async {
    if (kIsWeb) {
      DebugLogger.warning('Video picking not supported on web sandbox');
      return null;
    }
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (file == null) return null;

    final rawExt = _fileExtension(file.path, fallback: 'mp4');
    if (!_allowedVideoExtensions.contains(rawExt)) {
      DebugLogger.warning('Rejected video with disallowed extension: $rawExt');
      AppToast.warning(
        'invalid_video_format'.tr,
        'unsupported_video_extension'.trParams({'ext': rawExt}),
      );
      return null;
    }

    final uploadBytes = await file.readAsBytes();
    if (uploadBytes.lengthInBytes > _maxVideoBytes) {
      DebugLogger.warning(
        'Rejected video exceeding size limit: '
        '${(uploadBytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)} MB',
      );
      AppToast.warning('video_too_large'.tr, 'video_size_limit_exceeded'.tr);
      return null;
    }

    try {
      final response = await _apiClient.upload(
        ApiPaths.upload,
        field: 'file',
        filePath: file.path,
        fields: {'folder': 'property_video', 'visibility': 'public'},
      );

      final data = response.body as Map<String, dynamic>;
      final url = data['public_url'] as String? ?? '';
      if (url.isEmpty) {
        DebugLogger.warning('Upload succeeded but no URL returned');
        return null;
      }

      final ext = _fileExtension(file.path, fallback: 'mp4');
      return MediaUploadResult(
        url: url,
        storagePath: data['file_path'] as String? ?? '',
        bytes: uploadBytes.lengthInBytes,
        mimeType: 'video/$ext',
      );
    } catch (e, st) {
      DebugLogger.error('Failed to upload video', e, st);
      return null;
    }
  }

  Future<PropertyModel?> uploadImageAndAttach({
    required int propertyId,
    required PropertiesRepository repository,
    bool markAsMain = false,
    String category = 'gallery',
  }) async {
    final result = await pickAndUploadImage(
      propertyId: propertyId,
      markAsMain: markAsMain,
      category: category,
    );
    if (result == null) return null;

    final image = PropertyImageModel(
      id: -1,
      propertyId: propertyId,
      imageUrl: result.url,
      displayOrder: 0,
      isMainImage: markAsMain,
      isMain: markAsMain,
      category: category,
    );

    return repository.updatePropertyMedia(
      propertyId: propertyId,
      mainImageUrl: markAsMain ? result.url : null,
      images: [image],
    );
  }

  Future<PropertyModel?> uploadVideoAndAttach({
    required int propertyId,
    required PropertiesRepository repository,
  }) async {
    final result = await pickAndUploadVideo(propertyId: propertyId);
    if (result == null) return null;

    return repository.updatePropertyMedia(
      propertyId: propertyId,
      videoTourUrl: result.url,
      videoUrls: [result.url],
    );
  }

  String _fileExtension(String path, {required String fallback}) {
    final parts = path.split('.');
    if (parts.length > 1) {
      final ext = parts.last.trim();
      if (ext.isNotEmpty) return ext.toLowerCase();
    }
    return fallback;
  }
}
