import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sams_frontend/attendance/student/attendance.dart';
import 'pending_deep_link.dart';

/* Widget wrapper yang listen untuk deep link "attendease://attendance?..."
flow: dari QR scan dan navigate ke StudentAttendancePage secara automatik 
pastu diletakkan kat atas MaterialApp supaya boleh intercept link bila-bila masa
*/
class DeepLinkHandler extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey; // Untuk navigate tanpa BuildContext local

  const DeepLinkHandler({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  /// Setup listener untuk deep link — handle both cold start dan warm/hot start
  Future<void> _initDeepLinks() async {
    // Cold start — app tertutup sepenuhnya semasa QR di-scan, link ni yang launch app so kena check sekali masa app baru start
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Deep link cold start error: $e');
    }

    // Warm / hot start — app dah running di background, dia listen stream untuk link baru yang masuk semasa app sedang aktif
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (e) => debugPrint('Deep link stream error: $e'),
    );
  }

  // Parse deep link dan navigate ke page yang sesuai, format yang dijangka: attendease://attendance?code=XXXXXX&subject_id=42&type=course
  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Deep link received: $uri');

    // Validate scheme dan host — abaikan link yang tak match format kita
    if (uri.scheme != 'attendease' || uri.host != 'attendance') return;

    final code         = uri.queryParameters['code'] ?? '';
    final subjectIdStr = uri.queryParameters['subject_id'] ?? '0';
    final type         = uri.queryParameters['type'] ?? 'course';
    final subjectId    = int.tryParse(subjectIdStr) ?? 0;

    // Guard: kalau code kosong atau subjectId tak valid, link ni diabaikan
    if (code.isEmpty || subjectId == 0) return;

    // Check login status dulu sebelum proceed 
    final bool isLoggedIn = await _checkAuth();

    if (!isLoggedIn) {
      // for student belum login: dia simpan link untuk diproses selepas login, kemudian redirect ke LoginPage
      PendingDeepLink.save(code, subjectId, type);
      widget.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/',              // Balik ke LoginPage (root route)
        (route) => false, // Buang semua route sebelum ni
      );
      return;
    }

    // Fetch info subjek dulu supaya header page tunjuk kod & nama yang betul 
    final subjectInfo = await _fetchSubjectInfo(subjectId, type);

    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getInt('student_id') ?? 0;

    // Navigate ke StudentAttendancePage dengan kod yang dah pre-fill dari QR
    widget.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => StudentAttendancePage(
          studentId: studentId,
          subjectId: subjectId,
          subjectCode: subjectInfo['code'] ?? '',
          subjectName: subjectInfo['name'] ?? '',
          attendanceType: type,
          initialCode: code, // Kod ni akan auto-fill dalam text field
        ),
      ),
    );
  }

  // Return true kalau pelajar sudah login (ada student_id dan role 'student' dalam SharedPreferences)
  Future<bool> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getInt('student_id');
    final role = prefs.getString('role');
    return studentId != null && studentId > 0 && role == 'student';
  }

  // Fetch kod dan nama subjek dari API supaya header attendance page terisi dengan betul bila dibuka melalui QR deep link
  Future<Map<String, String>> _fetchSubjectInfo(int subjectId, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getInt('student_id') ?? 0;

      // Reuse endpoint attendance yang sama, dia return banyak data cth: student_name, subject code/name... kita ambil code + name sahaja
      final response = await http.get(
        Uri.parse(
          'https://darkgrey-lyrebird-505549.hostingersite.com/api/student/$studentId/attendance/$subjectId?type=$type',
        ),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {
          'code': data['subject_code']?.toString() ?? '',
          'name': data['subject_name']?.toString() ?? '',
        };
      }
    } catch (e) {
      debugPrint('Failed to fetch subject info: $e');
    }
    // Return string kosong, page masih boleh fungsi, cuma header takde text
    return {'code': '', 'name': ''};
  }

  @override
  void dispose() {
    // Cancel subscription elak memory leak / callback selepas widget dispose
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child; // Widget ni invisible sebab jadikan sebagai listener
}
