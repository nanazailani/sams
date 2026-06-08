import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../subject/student/faculty_registar/add_courses_page.dart';
import '../subject/student/faculty_registar/approve_subject_page.dart';
import '../subject/student/faculty_registar/manage_courses_page.dart';
import '../subject/student/faculty_registar/report_page.dart';
import '../main.dart' show LoginPage;

// ✅ This is what main.dart looks for
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _showAddCoursesPage = false;

  void _selectPage(int index) {
    setState(() {
      _currentIndex = index;
      if (index != 1) {
        _showAddCoursesPage = false;
      }
    });
  }

  void _openAddCoursesPage() {
    setState(() {
      _currentIndex = 1;
      _showAddCoursesPage = true;
    });
  }

  void _openApprovalPage() {
    setState(() {
      _currentIndex = 2;
      _showAddCoursesPage = false;
    });
  }

  void _openReportPage() {
    setState(() {
      _currentIndex = 3;
      _showAddCoursesPage = false;
    });
  }

  void _closeAddCoursesPage() {
    setState(() {
      _currentIndex = 1;
      _showAddCoursesPage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FacultyRegistrarPage(
        onManageCoursesTap: () => _selectPage(1),
        onApprovalTap: _openApprovalPage,
        onReportTap: _openReportPage,
      ),
      _showAddCoursesPage
          ? AddCoursesPage(
              onBack: _closeAddCoursesPage,
              onCourseSaved: _closeAddCoursesPage,
            )
          : ManageCoursesPage(onAddCoursesTap: _openAddCoursesPage),
      const ApproveSubjectPage(),
      const ReportPage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: SizedBox(
        height: 85,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _selectPage,
          selectedItemColor: const Color(0xFF3FC7C4),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              label: 'Courses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              label: 'Approval',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              label: 'Report',
            ),
          ],
          iconSize: 30,
        ),
      ),
    );
  }
}

// ─── HOME PAGE ───────────────────────────────────────────────────────────────

class FacultyRegistrarPage extends StatelessWidget {
  final VoidCallback onManageCoursesTap;
  final VoidCallback onApprovalTap;
  final VoidCallback onReportTap;

  const FacultyRegistrarPage({
    super.key,
    required this.onManageCoursesTap,
    required this.onApprovalTap,
    required this.onReportTap,
  });

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF3FC7C4);
    const secondaryColor = Color(0xFFE6D36F);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Faculty Registrar Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        // ✅ Manage Courses → navigates to ManageCoursesPage
                        RegistrarModuleCard(
                          title: 'Manage Courses',
                          imagePath: 'assets/images/manage_courses.png',
                          fallbackIcon: Icons.menu_book_outlined,
                          onTap: onManageCoursesTap,
                        ),
                        RegistrarModuleCard(
                          title: 'Approve Subject',
                          imagePath: 'assets/images/approve.png',
                          fallbackIcon: Icons.check_circle_outline,
                          onTap: onApprovalTap,
                        ),
                        RegistrarModuleCard(
                          title: 'Generate Report',
                          imagePath: 'assets/images/report.png',
                          fallbackIcon: Icons.bar_chart_outlined,
                          onTap: onReportTap,
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

// ─── MODULE CARD ─────────────────────────────────────────────────────────────

class RegistrarModuleCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final IconData fallbackIcon;
  final VoidCallback onTap; // ✅ now accepts onTap

  const RegistrarModuleCard({
    super.key,
    required this.title,
    required this.imagePath,
    required this.fallbackIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF3FC7C4);
    const secondaryColor = Color(0xFFE6D36F);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
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
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      fallbackIcon,
                      size: 70,
                      color: primaryColor,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
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
    );
  }
}

// ─── PLACEHOLDER PAGES ───────────────────────────────────────────────────────

class ApprovalPage extends StatelessWidget {
  const ApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderPage(
        title: 'Approval', icon: Icons.check_circle_outline);
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3FC7C4), Color(0xFFE6D36F)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 64, color: const Color(0xFF3FC7C4)),
                    const SizedBox(height: 16),
                    Text(
                      '$title\nComing Soon',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
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