/// Stores a deep-link payload that arrived before the user was authenticated.
/// Call [PendingDeepLink.save] in the deep-link handler when the user is not
/// logged in, then call [PendingDeepLink.consume] inside [_onLoginSuccess] to
/// resume navigation.
class PendingDeepLink {
  PendingDeepLink._(); // non-instantiable

  static _PendingData? _data;

  /// Persist a link that could not be handled yet (user not logged in).
  static void save(String code, int subjectId, String type) {
    _data = _PendingData(code: code, subjectId: subjectId, type: type);
  }

  /// Returns the stored link **and clears it** so it is only consumed once.
  static _PendingData? consume() {
    final d = _data;
    _data = null;
    return d;
  }

  /// True when a link is waiting to be handled after login.
  static bool get hasPending => _data != null;
}

class _PendingData {
  final String code;
  final int subjectId;
  final String type;

  const _PendingData({
    required this.code,
    required this.subjectId,
    required this.type,
  });
}