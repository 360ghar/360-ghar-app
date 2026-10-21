/// The two tabs of the Likes page. The last choice of the legacy app is read once from the
/// imported likes page state (`additionalData` under [additionalDataKey]); the new app does not
/// write it back, so the page opens on Liked after a restart.
enum LikesSegment {
  liked,
  passed;

  /// `additionalData` key holding the active segment on the likes page state.
  static const String additionalDataKey = 'currentSegment';

  static LikesSegment tryParse(String? raw) => raw == 'passed' ? passed : liked;
}
