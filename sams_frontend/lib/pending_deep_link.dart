/* Simpan payload deep-link yang masuk before user authenticated 
   Call [PendingDeepLink.save] dalam deep-link handler bila user belum login, 
   pastu call [PendingDeepLink.consume] dalam [_onLoginSuccess] untuk resume navigation balik
  */
class PendingDeepLink {
  PendingDeepLink._(); // Constructor private — class ni tak boleh di-instantiate

  // simpan data dalam memory cth: hilang bila app restart, itu okay sebab deep link akan re-trigger _initDeepLinks lagi pada cold start
  static _PendingData? _data;

  /// Simpan link yang belum boleh diproses untuk pelajar belum login
  static void save(String code, int subjectId, String type) {
    _data = _PendingData(code: code, subjectId: subjectId, type: type);
  }

  /* 
  Return data yang disimpan and terus clear so data ni hanya boleh
  digunakan sekali sahaja (elak re-trigger attendance submission berulang
  kali kalau _onLoginSuccess dipanggil lebih dari sekali)
  */
  static _PendingData? consume() {
    final d = _data;
    _data = null; // Clear serta-merta selepas diambil
    return d;
  }

  // True kalau ada link yang masih menunggu untuk diproses selepas login
  static bool get hasPending => _data != null;
}

// Data class ringkas untuk simpan payload deep link
class _PendingData { // _ is private hanya digunakan dalaman oleh PendingDeepLink
  final String code;
  final int subjectId;
  final String type;

  const _PendingData({
    required this.code,
    required this.subjectId,
    required this.type,
  });
}
