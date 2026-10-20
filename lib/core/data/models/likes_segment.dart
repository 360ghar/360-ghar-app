/// The two tabs of the Likes page. Persisted inside the likes page state's
/// `additionalData` under [additionalDataKey] using [name].
enum LikesSegment {
  liked,
  passed;

  /// `additionalData` key holding the active segment on the likes page state.
  static const String additionalDataKey = 'currentSegment';

  static LikesSegment tryParse(String? raw) => raw == 'passed' ? passed : liked;
}
