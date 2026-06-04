import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'activities_page.dart';
import 'module_booking_page.dart';
import '../student/credit_claim_page.dart';

class CurriculumPage extends StatefulWidget {
  const CurriculumPage({super.key});

  @override
  State<CurriculumPage> createState() => _CurriculumPageState();
}

class _CurriculumPageState extends State<CurriculumPage> {
  static const String _baseUrl =
      'https://darkgrey-lyrebird-505549.hostingersite.com/api';

  bool _isBlocked = false;
  bool _isCheckingLock = true;

  @override
  void initState() {
    super.initState();
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final matricNo = prefs.getString('matric_no') ?? '';

      final uri = Uri.parse('$_baseUrl/week-lock/status')
          .replace(queryParameters: {'matric_no': matricNo});

      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isBlocked = data['student_blocked'] == true;
        });
      }
    } catch (e) {
      debugPrint('Lock check error: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingLock = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              decoration: const BoxDecoration(
                color: Color(0xFF67C5C4),
              ),
              child: const Text(
                'Curriculum Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                ),
              ),
            ),

            Expanded(
              child: _isCheckingLock
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Warning banner — only shows when blocked
                          if (_isBlocked)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFFFD54F)),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: const [
                                  Icon(Icons.lock,
                                      color: Color(0xFFF9A825), size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Reminder: Your tuition has not been fully paid. '
                                      'Academic modules are locked after Week 5 until '
                                      'payment is completed. Please proceed to the '
                                      'Payment module to settle your balance.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7B5800),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const Text(
                            'Quick Access',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap a module to continue',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 18),

                          GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 22,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 0.82,
                            children: [
                              CurriculumModuleCard(
                                title: 'Module Booking',
                                imagePath:
                                    'assets/images/module_booking.png',
                                isBlocked: _isBlocked,
                              ),
                              CurriculumModuleCard(
                                title: 'Credit Claim',
                                imagePath:
                                    'assets/images/credit_claim.png',
                                isBlocked: _isBlocked,
                              ),
                              CurriculumModuleCard(
                                title: 'Activities',
                                imagePath:
                                    'assets/images/activities.png',
                                isBlocked: _isBlocked,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class CurriculumModuleCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final bool isBlocked;

  const CurriculumModuleCard({
    super.key,
    required this.title,
    required this.imagePath,
    this.isBlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF3FC7C4);
    const blockedColor = Color(0xFFB0B0B0);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isBlocked
          ? () {
              // Show reminder snackbar when tapping a blocked card
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Access locked. Please settle your tuition payment first.',
                  ),
                  backgroundColor: Color(0xFFF9A825),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          : () {
              if (title == 'Module Booking') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ModuleBookingPage(),
                  ),
                );
              } else if (title == 'Credit Claim') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreditClaimPage(),
                  ),
                );
              } else if (title == 'Activities') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActivitiesPage(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$title tapped')),
                );
              }
            },
      child: Opacity(
        // Grey out the whole card when blocked
        opacity: isBlocked ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_outlined,
                            size: 70,
                            color: isBlocked ? Colors.grey : Colors.grey,
                          );
                        },
                      ),
                      // Lock icon overlay when blocked
                      if (isBlocked)
                        const Icon(
                          Icons.lock,
                          size: 32,
                          color: Color(0xFF888888),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isBlocked ? blockedColor : primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}