import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show LoginPage;

class StudentHomepage extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onRegisterSubject;
  final int refreshSignal;

  const StudentHomepage({
    super.key,
    required this.onRegisterSubject,
    this.refreshSignal = 0,
  });

  @override
  State<StudentHomepage> createState() => _StudentHomepageState();
}

class _StudentHomepageState extends State<StudentHomepage> {
  static const _primaryColor = Color(0xFF35C8C6);
  static const _backgroundColor = Color(0xFFF3F1F2);
  static const _semester = 'SEMESTER II ACADEMIC SESSION 2025/2026';
  static const _apiBaseUrl = 'http://10.0.2.2:8000/api';

  final TextEditingController _searchController = TextEditingController();

  int _studentId = 0;
  bool _isLoading = true;
  String? _errorMessage;
  String _name = '-';
  String _programme = '-';
  String _advisor = '-';
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _filteredSubjects = [];
  List<Map<String, dynamic>> _registeredSubjects = [];
  bool _isLoadingRegisteredSubjects = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterSubjects);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant StudentHomepage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStudentId = prefs.getInt('student_id') ?? 0;
    final savedUserId = prefs.getInt('user_id') ?? 0;
    final resolvedStudentId = savedStudentId != 0 ? savedStudentId : savedUserId;

    setState(() {
      _studentId = resolvedStudentId;
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.wait([
      _fetchStudentInfo(),
      _fetchSubjects(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentInfo() async {
    if (_studentId == 0) return;

    try {
      final response = await http
          .get(Uri.parse('$_apiBaseUrl/student/$_studentId/info'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (response.statusCode != 200) {
        debugPrint('Student info failed: ${response.statusCode}');
        debugPrint(response.body);
        setState(() {
          _errorMessage = 'Unable to load student info.';
        });
        return;
      }

      final data = jsonDecode(response.body);
      setState(() {
        _name = data['name']?.toString().toUpperCase() ?? '-';
        _programme = data['program']?.toString().toUpperCase() ?? '-';
        _advisor = data['advisor']?.toString().toUpperCase() ?? '-';
      });
    } catch (e) {
      debugPrint('Student info error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Cannot connect to backend at 127.0.0.1:8000.';
      });
    }
  }

  Future<void> _fetchSubjects() async {
    try {
      final uri = _studentId == 0
          ? Uri.parse('$_apiBaseUrl/subjects')
          : Uri.parse('$_apiBaseUrl/subjects?student_id=$_studentId');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (response.statusCode != 200) {
        debugPrint('Subjects failed: ${response.statusCode}');
        debugPrint(response.body);
        setState(() {
          _errorMessage = 'Unable to load subjects.';
        });
        return;
      }

      final List data = jsonDecode(response.body);
      final subjects = data.map<Map<String, dynamic>>((item) {
        return {
          'id': item['id'],
          'code': item['code']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
          'credit_hour': item['credit_hour'] ?? item['credits'] ?? 0,
          'instructors': item['instructors'] is List ? item['instructors'] : [],
          'is_registered': item['is_registered'] == true,
        };
      }).toList();

      setState(() {
        _subjects = subjects;
        _filteredSubjects = List.from(subjects);
      });
    } catch (e) {
      debugPrint('Subjects error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Cannot connect to backend at 127.0.0.1:8000.';
      });
    }
  }

  void _filterSubjects() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredSubjects = _subjects.where((subject) {
        final code = subject['code'].toString().toLowerCase();
        final name = subject['name'].toString().toLowerCase();
        return code.contains(query) || name.contains(query);
      }).toList();
    });
  }

  int get _registeredCreditHours {
    return _subjects.where((subject) => subject['is_registered'] == true).fold(
      0,
      (total, subject) {
        final credit = int.tryParse(subject['credit_hour'].toString()) ?? 0;
        return total + credit;
      },
    );
  }

  Future<void> _fetchRegisteredSubjects() async {
    if (_studentId == 0) return;

    setState(() => _isLoadingRegisteredSubjects = true);
    try {
      final response = await http
          .get(Uri.parse('$_apiBaseUrl/students/$_studentId/registered-subjects'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _registeredSubjects = data
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        });
      } else {
        debugPrint('Registered subjects failed: ${response.statusCode}');
        debugPrint(response.body);
      }
    } catch (e) {
      debugPrint('Registered subjects error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingRegisteredSubjects = false);
      }
    }
  }

  Future<void> _removeRegisteredSubject(Map<String, dynamic> subject) async {
    if (_studentId == 0) return;

    try {
      final response = await http
          .delete(
            Uri.parse(
              '$_apiBaseUrl/students/$_studentId/registered-subjects/${subject['id']}',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _fetchSubjects();
        await _fetchRegisteredSubjects();
      } else {
        final data = jsonDecode(response.body);
        _showSnack(data['message'] ?? 'Failed to remove subject', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _clearRegisteredSubjects() async {
    if (_studentId == 0 || _registeredSubjects.isEmpty) return;

    try {
      final response = await http
          .delete(Uri.parse('$_apiBaseUrl/students/$_studentId/registered-subjects'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _fetchSubjects();
        await _fetchRegisteredSubjects();
      } else {
        final data = jsonDecode(response.body);
        _showSnack(data['message'] ?? 'Failed to clear subjects', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _notifyFacultyRegistrar() async {
    if (_studentId == 0) {
      _showSnack('Please log in again before sending notification.', isError: true);
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/students/$_studentId/notify-registrar'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack(data['message'] ?? 'Faculty registrar has been notified.');
      } else {
        _showSnack(data['message'] ?? 'Failed to notify registrar', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primaryColor,
      ),
    );
  }

  Future<void> _openRegisteredSubjectsSheet() async {
    await _fetchRegisteredSubjects();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refreshSheet() async {
              await _fetchRegisteredSubjects();
              if (context.mounted) {
                setSheetState(() {});
              }
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.48,
              minChildSize: 0.28,
              maxChildSize: 0.78,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF9AA3AF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 18, 24, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'My Subject',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _registeredSubjects.isEmpty
                                  ? null
                                  : () async {
                                      await _clearRegisteredSubjects();
                                      await refreshSheet();
                                    },
                              icon: const Icon(Icons.delete_outline, size: 14),
                              label: const Text('Clear Subject'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black54,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _isLoadingRegisteredSubjects
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: _primaryColor,
                                ),
                              )
                            : _registeredSubjects.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No registered subject yet.',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                                    itemCount: _registeredSubjects.length,
                                    itemBuilder: (context, index) {
                                      final subject = _registeredSubjects[index];
                                      return _RegisteredSubjectCard(
                                        subject: subject,
                                        onUpdate: () {
                                          Navigator.pop(sheetContext);
                                          widget.onRegisterSubject(subject);
                                        },
                                        onRemove: () async {
                                          await _removeRegisteredSubject(subject);
                                          await refreshSheet();
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _primaryColor),
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                        child: Column(
                          children: [
                            _buildInfoTable(),
                            const SizedBox(height: 16),
                            _buildSearchBox(),
                            const SizedBox(height: 18),
                            if (_errorMessage != null)
                              _buildMessageState(_errorMessage!)
                            else if (_filteredSubjects.isEmpty)
                              _buildEmptyState()
                            else
                              ..._filteredSubjects.map(
                                (subject) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _SubjectCard(
                                    subject: subject,
                                    onRegister: () =>
                                        widget.onRegisterSubject(subject),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
            _buildCreditFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 26, 24, 24),
      decoration: const BoxDecoration(color: _primaryColor),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Register Subject',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white, size: 28),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTable() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.black87, width: 1),
        columnWidths: const {
          0: FlexColumnWidth(0.75),
          1: FlexColumnWidth(2.55),
        },
        children: [
          _infoRow('NAME', _name),
          _infoRow('PROGRAMME', _programme),
          _infoRow('ADVISOR', _advisor),
          _infoRow('SEMESTER', _semester),
        ],
      ),
    );
  }

  TableRow _infoRow(String label, String value) {
    return TableRow(
      children: [
        _InfoCell(label, isLabel: true),
        _InfoCell(value),
      ],
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'SEARCH',
        hintStyle: const TextStyle(fontSize: 12, color: Colors.black87),
        prefixIcon: const Icon(Icons.search, color: Colors.black87),
        filled: true,
        fillColor: const Color(0xFFECECEC),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Colors.black87),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return _buildMessageState('No subject available.');
  }

  Widget _buildMessageState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }

  Widget _buildCreditFooter() {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: _primaryColor,
        border: Border(
          top: BorderSide(color: Color(0xFF95D8F7), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openRegisteredSubjectsSheet,
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.school, size: 30, color: Colors.black87),
                        Positioned(
                          right: -7,
                          top: -5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _registeredCreditHours.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'CREDIT HOURS: $_registeredCreditHours',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _notifyFacultyRegistrar,
              child: SizedBox(
                width: 94,
                height: double.infinity,
                child: ColoredBox(
                  color: const Color(0xFFBFE0FF),
                  child: Center(
                    child: const Text(
                      'NOTIFY',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String text;
  final bool isLabel;

  const _InfoCell(this.text, {this.isLabel = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1.15,
          color: Colors.black,
          fontWeight: isLabel ? FontWeight.w700 : FontWeight.w800,
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onRegister;

  const _SubjectCard({
    required this.subject,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final code = subject['code']?.toString() ?? '';
    final name = subject['name']?.toString().toUpperCase() ?? '';
    final credit = subject['credit_hour']?.toString() ?? '0';
    final instructors = (subject['instructors'] as List)
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final isRegistered = subject['is_registered'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 14, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$code - $name',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _DetailLine(
            icon: Icons.lightbulb_outline,
            iconColor: Color(0xFFFFB300),
            text: '$credit Credit Hours',
          ),
          const SizedBox(height: 4),
          if (instructors.isEmpty)
            const _DetailLine(
              icon: Icons.person,
              iconColor: Color(0xFF9AA3AF),
              text: 'Instructor not assigned',
            )
          else
            ...instructors.map(
              (instructor) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: _DetailLine(
                  icon: Icons.person,
                  iconColor: const Color(0xFF9AA3AF),
                  text: instructor,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton(
              onPressed: isRegistered ? null : onRegister,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF35C8C6),
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                isRegistered ? 'Registered' : 'Register Subject',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisteredSubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onUpdate;
  final Future<void> Function() onRemove;

  const _RegisteredSubjectCard({
    required this.subject,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final code = subject['code']?.toString() ?? '';
    final name = subject['name']?.toString().toUpperCase() ?? '';
    final credit = subject['credit_hour']?.toString() ?? '0';
    final section = subject['section']?.toString() ?? '-';
    final tutorialLab = subject['tutorial_lab']?.toString() ?? '-';
    final timeSummary = subject['time_summary']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 54,
            child: Center(
              child: Icon(Icons.school, color: Colors.black87, size: 38),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$code - $name',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Credit Hours: $credit | Section: $section/$tutorialLab',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    height: 1.15,
                  ),
                ),
                Text(
                  'Time: $timeSummary',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              TextButton.icon(
                onPressed: () {
                  onRemove();
                },
                icon: const Icon(Icons.delete_outline, size: 10),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black54,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 18),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 8),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 58,
                height: 30,
                child: ElevatedButton(
                  onPressed: onUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF35C8C6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Update',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _DetailLine({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 15),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
