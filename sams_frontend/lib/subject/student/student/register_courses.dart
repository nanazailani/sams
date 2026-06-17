import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RegisterCoursesPage extends StatefulWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onBack;
  final VoidCallback onConfirmed;

  const RegisterCoursesPage({
    super.key,
    required this.subject,
    required this.onBack,
    required this.onConfirmed,
  });

  @override
  State<RegisterCoursesPage> createState() => _RegisterCoursesPageState();
}

class _RegisterCoursesPageState extends State<RegisterCoursesPage> {
  static const _primaryColor = Color(0xFF35C8C6);
  static const _backgroundColor = Color(0xFFF3F1F2);
  static const _semester = 'SEMESTER II ACADEMIC SESSION 2025/2026';

  //static const _apiBaseUrl = 'http://10.0.2.2:8000/api';
  static const _apiBaseUrl = 'https://darkgrey-lyrebird-505549.hostingersite.com/api';


  int _studentId = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  String _name = '-';
  String _programme = '-';
  String _advisor = '-';
  int _registeredCreditHours = 0;
  Map<String, dynamic> _subject = {};
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _tutorials = [];
  List<Map<String, dynamic>> _timetable = [];
  List<Map<String, dynamic>> _registeredSubjects = [];
  String? _selectedSection;
  String? _selectedTutorial;
  bool _isLoadingRegisteredSubjects = false;
  String? _registeredSubjectsError;

  @override
  void initState() {
    super.initState();
    _subject = Map<String, dynamic>.from(widget.subject);
    _loadData();
  }

  //load student info, subject detail, and current credit hour.
  //semua data ni perlu sebelum student confirm register course.
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStudentId = prefs.getInt('student_id') ?? 0;
    final savedUserId = prefs.getInt('user_id') ?? 0;

    setState(() {
      _studentId = savedStudentId != 0 ? savedStudentId : savedUserId;
      _isLoading = true;
    });

    await Future.wait([
      _fetchStudentInfo(),
      _fetchSubjectDetail(),
      _fetchRegisteredCreditHours(),
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

      if (!mounted || response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      setState(() {
        _name = data['name']?.toString().toUpperCase() ?? '-';
        _programme = data['program']?.toString().toUpperCase() ?? '-';
        _advisor = data['advisor']?.toString().toUpperCase() ?? '-';
      });
    } catch (_) {}
  }

  //ambil detail subject termasuk section, tutorial, and timetable.
  //kalau sections/tutorials kosong, app fallback guna timetable legacy.
  Future<void> _fetchSubjectDetail() async {
    final id = _subject['id'] ?? widget.subject['id'];
    if (id == null) return;

    try {
      final response = await http
          .get(Uri.parse('$_apiBaseUrl/subjects/$id'))
          .timeout(const Duration(seconds: 10));

      if (!mounted || response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final sections = _listFrom(data['sections']);
      final tutorials = _listFrom(data['tutorials']);
      final timetable = _listFrom(data['timetable']);
      final sectionOptions = sections.isNotEmpty
          ? sections
          : timetable.where((item) => item['mode'] == 'L').toList();
      final tutorialOptions = tutorials.isNotEmpty
          ? tutorials
          : timetable.where((item) => item['mode'] == 'B').toList();
      final savedSection = widget.subject['section']?.toString();
      final savedTutorial = widget.subject['tutorial_lab']?.toString();
      final sectionNames =
          sectionOptions.map((item) => item['section'].toString()).toList();
      final selectedSection = sectionNames.contains(savedSection)
          ? savedSection
          : (sectionOptions.isNotEmpty ? sectionOptions.first['section']?.toString() : null);
      final matchingTutorialOptions = _matchingTutorialsForSection(
        tutorialOptions,
        selectedSection,
      );
      final tutorialNames = matchingTutorialOptions
          .map((item) => item['section'].toString())
          .toList();

      setState(() {
        _subject = Map<String, dynamic>.from(data);
        _sections = sectionOptions;
        _tutorials = tutorialOptions;
        _timetable = timetable;
        _selectedSection = selectedSection;
        _selectedTutorial = tutorialNames.contains(savedTutorial)
            ? savedTutorial
            : (matchingTutorialOptions.isNotEmpty
                ? matchingTutorialOptions.first['section']?.toString()
                : null);
      });
    } catch (_) {}
  }

  Future<void> _fetchRegisteredCreditHours() async {
    if (_studentId == 0) return;

    try {
      final response = await http
          .get(Uri.parse('$_apiBaseUrl/students/$_studentId/registered-subjects'))
          .timeout(const Duration(seconds: 10));

      if (!mounted || response.statusCode != 200) return;

      final List data = jsonDecode(response.body);
      final total = data.fold<int>(0, (sum, subject) {
        final credit = int.tryParse(
              (subject['credit_hour'] ?? subject['credits'] ?? 0).toString(),
            ) ??
            0;
        return sum + credit;
      });

      setState(() => _registeredCreditHours = total);
    } catch (_) {}
  }

  Future<void> _fetchRegisteredSubjects() async {
    if (_studentId == 0) return;

    setState(() {
      _isLoadingRegisteredSubjects = true;
      _registeredSubjectsError = null;
    });

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
        setState(() {
          _registeredSubjects = [];
          _registeredSubjectsError = 'Unable to load registered subjects.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _registeredSubjects = [];
        _registeredSubjectsError = 'Unable to load registered subjects.';
      });
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
        await Future.wait([
          _fetchRegisteredSubjects(),
          _fetchRegisteredCreditHours(),
        ]);
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
        await Future.wait([
          _fetchRegisteredSubjects(),
          _fetchRegisteredCreditHours(),
        ]);
      } else {
        final data = jsonDecode(response.body);
        _showSnack(data['message'] ?? 'Failed to clear subjects', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    }
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
              await _fetchRegisteredCreditHours();
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
                            : _registeredSubjectsError != null
                                ? Center(
                                    child: Text(
                                      _registeredSubjectsError!,
                                      style: const TextStyle(color: Colors.red),
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
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          18,
                                        ),
                                        itemCount: _registeredSubjects.length,
                                        itemBuilder: (context, index) {
                                          final subject =
                                              _registeredSubjects[index];
                                          return _RegisteredSubjectCard(
                                            subject: subject,
                                            onUpdate: () {
                                              Navigator.pop(sheetContext);
                                              setState(() {
                                                _subject =
                                                    Map<String, dynamic>.from(
                                                  subject,
                                                );
                                              });
                                              _fetchSubjectDetail();
                                            },
                                            onRemove: () async {
                                              await _removeRegisteredSubject(
                                                subject,
                                              );
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

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primaryColor,
      ),
    );
  }

  List<Map<String, dynamic>> _listFrom(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  List<Map<String, dynamic>> get _matchingTutorials {
    return _matchingTutorialsForSection(_tutorials, _selectedSection);
  }

  //filter tutorial/lab ikut prefix section lecture yang dipilih.
  //contoh L01 hanya match tutorial/lab yang mula dengan 01.
  List<Map<String, dynamic>> _matchingTutorialsForSection(
    List<Map<String, dynamic>> tutorials,
    String? section,
  ) {
    final sectionPrefix = _sectionPrefix(section);
    if (sectionPrefix.isEmpty) return tutorials;

    return tutorials.where((item) {
      return _sectionPrefix(item['section']?.toString()) == sectionPrefix;
    }).toList();
  }

  String _sectionPrefix(String? value) {
    final match = RegExp(r'^(\d+)').firstMatch((value ?? '').trim());
    if (match == null) return '';
    return int.parse(match.group(1)!).toString().padLeft(2, '0');
  }

  //bila section berubah, reset tutorial kalau tak matching.
  //ini elak student pilih lecture 01 tapi tutorial/lab dari section lain.
  void _setSelectedSection(String? value) {
    final matchingTutorials = _matchingTutorialsForSection(_tutorials, value);
    final matchingTutorialNames =
        matchingTutorials.map((item) => item['section']?.toString()).toList();

    setState(() {
      _selectedSection = value;
      if (!matchingTutorialNames.contains(_selectedTutorial)) {
        _selectedTutorial = matchingTutorials.isEmpty
            ? null
            : matchingTutorials.first['section']?.toString();
      }
    });
  }

  List<_SelectOption> _optionsFor(List<Map<String, dynamic>> items) {
    return items.map((item) {
      final section = item['section']?.toString() ?? '';
      final remaining = item['remaining_capacity']?.toString();
      final label = remaining == null || remaining.isEmpty
          ? section
          : '$section   Remaining: $remaining';

      return _SelectOption(value: section, label: label);
    }).toList();
  }

  //submit selected section/tutorial to backend.
  //backend akan validate clash, capacity, and save sebagai pending registration.
  Future<void> _confirmRegistration() async {
    if (_studentId == 0 || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/subjects/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'student_id': _studentId,
          'subject_id': _subject['id'],
          'section': _selectedSection,
          'tutorial_lab': _selectedTutorial,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subject registered successfully'),
            backgroundColor: _primaryColor,
          ),
        );
        widget.onConfirmed();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to register subject'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  //send notification supaya registrar tahu ada pending approval.
  //dipanggil selepas student pilih subjects dan mahu registrar review.
  Future<void> _notifyFacultyRegistrar() async {
    if (_studentId == 0) return;

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/students/$_studentId/notify-registrar'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'Faculty registrar has been notified.'),
          backgroundColor:
              response.statusCode == 200 ? _primaryColor : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  int get _creditHour {
    return int.tryParse((_subject['credit_hour'] ?? 0).toString()) ?? 0;
  }

  bool get _hasExamination {
    final value = _subject['examination'];
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().toLowerCase().trim() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }

  String get _examinationText {
    if (!_hasExamination) return 'Examination - NO';

    final date = _subject['exam_date']?.toString().trim() ?? '';
    final period = _subject['exam_period']?.toString().trim() ?? '';
    final details = [date, period].where((item) => item.isNotEmpty).join(' ');

    return details.isEmpty ? 'Examination - YES' : 'Examination - YES ($details)';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _primaryColor),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
                        child: Column(
                          children: [
                            _buildInfoTable(),
                            const SizedBox(height: 36),
                            _buildRegisterCard(),
                          ],
                        ),
                      ),
              ),
              _buildCreditFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 28, 16, 24),
      color: _primaryColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Register Subject',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
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
    return TableRow(children: [
      _InfoCell(label, isLabel: true),
      _InfoCell(value),
    ]);
  }

  Widget _buildRegisterCard() {
    final code = _subject['code']?.toString() ?? '';
    final name = _subject['name']?.toString().toUpperCase() ?? '';
    final instructors = (_subject['instructors'] is List)
        ? (_subject['instructors'] as List).map((item) => item.toString()).toList()
        : <String>[];
    final timetable =
        _timetable.isNotEmpty ? _timetable : [..._sections, ..._tutorials];
    final matchingTutorials = _matchingTutorials;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$code - $name',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          _DetailLine(
            icon: Icons.lightbulb_outline,
            iconColor: const Color(0xFFFFB300),
            text: '$_creditHour Credit Hours',
          ),
          const SizedBox(height: 3),
          if (instructors.isEmpty)
            const _DetailLine(
              icon: Icons.person,
              iconColor: Color(0xFF9AA3AF),
              text: 'Instructor not assigned',
            )
          else
            ...instructors.map(
              (instructor) => _DetailLine(
                icon: Icons.person,
                iconColor: const Color(0xFF9AA3AF),
                text: instructor,
              ),
            ),
          const SizedBox(height: 3),
          _DetailLine(
            icon: Icons.article_outlined,
            iconColor: const Color(0xFF8B8F99),
            text: _examinationText,
            highlightLastWord: true,
          ),
          const SizedBox(height: 24),
          _Timetable(rows: timetable),
          const SizedBox(height: 30),
          _SelectRow(
            label: 'Section:',
            value: _selectedSection,
            hint: 'Select',
            items: _optionsFor(_sections),
            onChanged: _setSelectedSection,
          ),
          const SizedBox(height: 12),
          _SelectRow(
            label: 'Tutorial/Lab:',
            value: _selectedTutorial,
            hint: 'Select',
            items: _optionsFor(matchingTutorials),
            onChanged: (value) => setState(() => _selectedTutorial = value),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _confirmRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'CONFIRM',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditFooter() {
    return Container(
      height: 46,
      color: _primaryColor,
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
                        const Icon(Icons.school,
                            size: 30, color: Colors.black87),
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
          InkWell(
            onTap: _notifyFacultyRegistrar,
            mouseCursor: SystemMouseCursors.click,
            child: Container(
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              color: const Color(0xFFBFE0FF),
              alignment: Alignment.center,
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
        ],
      ),
    );
  }
}

class _Timetable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _Timetable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final tableRows = rows.isEmpty
        ? <TableRow>[
            _row(['-', '-', '-', '-', '-', '-']),
          ]
        : rows.map((item) {
            return _row([
              item['section']?.toString() ?? '-',
              item['day']?.toString() ?? '-',
              item['time']?.toString() ?? '-',
              item['location']?.toString() ?? '-',
              item['mode']?.toString() ?? '-',
              item['capacity']?.toString() ?? '-',
            ]);
          }).toList();

    return Center(
      child: SizedBox(
        width: 275,
        child: Table(
          border: TableBorder.all(color: Colors.black87, width: 1),
          columnWidths: const {
            0: FlexColumnWidth(0.75),
            1: FlexColumnWidth(0.8),
            2: FlexColumnWidth(1.8),
            3: FlexColumnWidth(1.9),
            4: FlexColumnWidth(0.8),
            5: FlexColumnWidth(0.75),
          },
          children: [
            _row(['Sec', 'Day', 'Time', 'Loc', 'Mode', 'Cap'], isHeader: true),
            ...tableRows,
          ],
        ),
      ),
    );
  }

  static TableRow _row(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells.map((text) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              height: 1.05,
              fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
              color: Colors.black,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SelectRow extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final List<_SelectOption> items;
  final ValueChanged<String?> onChanged;

  const _SelectRow({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value:
                items.any((item) => item.value == value) ? value : null,
            hint: Text(hint, style: TextStyle(color: Colors.grey.shade500)),
            isExpanded: true,
            icon: const SizedBox.shrink(),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFE2DDDD),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
            items: items
                .map((item) => DropdownMenuItem(
                      value: item.value,
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: items.isEmpty ? null : onChanged,
          ),
        ),
      ],
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
                onPressed: onRemove,
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
  final bool highlightLastWord;

  const _DetailLine({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.highlightLastWord = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 15),
        const SizedBox(width: 4),
        Expanded(
          child: highlightLastWord
              ? RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                    children: _highlightExamAnswerSpans(text),
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ],
    );
  }

  List<TextSpan> _highlightExamAnswerSpans(String value) {
    final yesIndex = value.indexOf('YES');
    final noIndex = value.indexOf('NO');
    final answerIndex = yesIndex == -1 ? noIndex : yesIndex;
    final answer = yesIndex == -1 ? 'NO' : 'YES';

    if (answerIndex == -1) return [TextSpan(text: value)];

    return [
      TextSpan(text: value.substring(0, answerIndex)),
      TextSpan(
        text: answer,
        style: TextStyle(
          color: answer == 'YES' ? const Color(0xFF35C8C6) : Colors.red,
          fontWeight: FontWeight.w800,
        ),
      ),
      TextSpan(text: value.substring(answerIndex + answer.length)),
    ];
  }
}

class _SelectOption {
  final String value;
  final String label;

  const _SelectOption({
    required this.value,
    required this.label,
  });
}
