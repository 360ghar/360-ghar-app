/// The two tabs of the Likes page. Persisted inside the likes page state's
/// `additionalData` under the 'currentSegment' key using [name].
enum LikesSegment {
  liked,
  passed;

  static LikesSegment tryParse(String? raw) =>
      raw == 'passed' ? passed : liked;
}
