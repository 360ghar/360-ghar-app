import 'package:ghar360/core/utils/app_exceptions.dart';

/// A local read or write failed. The cause is for diagnostics, not user text.
class StorageFailure extends AppException {
  StorageFailure(this.operation, {this.cause, String code = 'LOCAL_STORAGE_FAILED'})
    : super('Local data could not be saved or read.', code: code);

  final String operation;
  final Object? cause;
}
