import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sams_frontend/attendance/student/attendance.dart';
import 'pending_deep_link.dart';

class DeepLinkHandler extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

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

  Future<void> _initDeepLinks() async {
    // Cold start — app was closed when QR was scanned
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Deep link cold start error: $e');
    }

    // Warm / hot — app already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (e) => debugPrint('Deep link stream error: $e'),
    );
  }

  // Parses: attendease://attendance?code=XXXXXX&subject_id=42&type=course
  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Deep link received: $uri');

    if (uri.scheme != 'attendease' || uri.host != 'attendance') return;

    final code         = uri.queryParameters['code'] ?? '';
    final subjectIdStr = uri.queryParameters['subject_id'] ?? '0';
    final type         = uri.queryParameters['type'] ?? 'course';
    final subjectId    = int.tryParse(subjectIdStr) ?? 0;

    if (code.isEmpty || subjectId == 0) return;

    // ── Auth check via SharedPreferences ────────────────────────────────────
    final bool isLoggedIn = await _checkAuth();

    if (!isLoggedIn) {
      // Not logged in → save the link and redirect to login
      PendingDeepLink.save(code, subjectId, type);
      widget.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/',              // back to LoginPage (root route)
        (route) => false,
      );
      return;
    }

    // ── Fetch subject info so the page header shows correctly ────────────────
    final subjectInfo = await _fetchSubjectInfo(subjectId, type);

    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getInt('student_id') ?? 0;

    widget.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => StudentAttendancePage(
          studentId: studentId,
          subjectId: subjectId,
          subjectCode: subjectInfo['code'] ?? '',
          subjectName: subjectInfo['name'] ?? '',
          attendanceType: type,
          initialCode: code,
        ),
      ),
    );
  }

  /// Returns true if the student is already logged in.
  Future<bool> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getInt('student_id');
    final role = prefs.getString('role');
    return studentId != null && studentId > 0 && role == 'student';
  }

  /// Fetches the subject code and name from the API so the attendance page
  /// header is populated correctly when opened via QR deep link.
  Future<Map<String, String>> _fetchSubjectInfo(int subjectId, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getInt('student_id') ?? 0;

      // Reuse the same attendance endpoint — it returns student_name,
      // subject code/name etc. We only need code + name from it.
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
    // Return empty strings — the page will still work, just no header text
    return {'code': '', 'name': ''};
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}