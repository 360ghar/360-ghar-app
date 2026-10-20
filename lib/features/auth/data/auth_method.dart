/// Authentication methods recorded by `POST /api/v1/auth/last-method` and persisted locally to
/// pre-select the last-used method. The enum is generated from the backend's `AuthMethod` by
/// `tool/gen_enums.py`: `wire` is the value on the wire, `fromJson` reads an unknown value as null.
library;

export 'package:ghar360/core/data/models/wire_enums.dart' show AuthMethod;
