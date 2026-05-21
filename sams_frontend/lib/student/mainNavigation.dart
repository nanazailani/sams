
import 'package:flutter/material.dart';
import 'homepage.dart';
import '../attendance/student/class.dart';
import 'register_courses.dart';

import 'curriculum_page.dart';
import 'fee_dashboard.dart';


class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _homeRefreshSignal = 0;
  Map<String, dynamic>? _registeringSubject;

  void _openRegisterCourse(Map<String, dynamic> subject) {
    setState(() {
      _currentIndex = 0;
      _registeringSubject = subject;
    });
  }

  void _closeRegisterCourse() {
    setState(() {
      _currentIndex = 0;
      _registeringSubject = null;
      _homeRefreshSignal++;
    });
  }

  void _selectPage(int index) {
    setState(() {
      _currentIndex = index;
      if (index != 0) {
        _registeringSubject = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _registeringSubject == null
          ? StudentHomepage(
              onRegisterSubject: _openRegisterCourse,
              refreshSignal: _homeRefreshSignal,
            )
          : RegisterCoursesPage(
              subject: _registeringSubject!,
              onConfirmed: _closeRegisterCourse,
            ),
      const CurriculumPage(),
      const StudentClassPage(),
      const FeeDashboardPage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: SizedBox(
        height: 85,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _selectPage,
          selectedItemColor: const Color(0xFF67C5C4),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.autorenew),
              label: "Curriculum",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              label: "Class",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.payments_outlined),
              label: "Payment",
            ),
          ],
          iconSize: 30,
        ),
      ),
    );
  }
}
