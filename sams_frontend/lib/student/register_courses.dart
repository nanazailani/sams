import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RegisterCoursesPage extends StatefulWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onConfirmed;

  const RegisterCoursesPage({
    super.key,
    required this.subject,
    required this.onConfirmed,
  });

  @override
  State<RegisterCoursesPage> createState() => _RegisterCoursesPageState();
}

class _RegisterCoursesPageState extends State<RegisterCoursesPage> {
  static const _primaryColor = Color(0xFF35C8C6);
  static const _backgroundColor = Color(0xFFF3F1F2);
  static const _semester = 'SEMESTER II ACADEMIC SESSION 2025/2026';
  static const _apiBaseUrl = 'http://10.0.2.2:8000/api';

  int _studentId = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  String _name = '-';
  String _programme = '-';
  String _advisor = '-';
  Map<String, dynamic> _subject = {};
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _tutorials = [];
  List<Map<String, dynamic>> _timetable = [];
  String? _selectedSection;
  String? _selectedTutorial;

  @override
  void initState() {
    super.initState();
    _subject = Map<String, dynamic>.from(widget.subject);
    _loadData();
  }

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

  Future<void> _fetchSubjectDetail() async {
    final id = widget.subject['id'];
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
      final tutorialNames =
          tutorialOptions.map((item) => item['section'].toString()).toList();

      setState(() {
        _subject = Map<String, dynamic>.from(data);
        _sections = sectionOptions;
        _tutorials = tutorialOptions;
        _timetable = timetable;
        _selectedSection = sectionNames.contains(savedSection)
            ? savedSection
            : (sectionOptions.isNotEmpty ? sectionOptions.first['section'] : null);
        _selectedTutorial = tutorialNames.contains(savedTutorial)
            ? savedTutorial
            : (tutorialOptions.isNotEmpty ? tutorialOptions.first['section'] : null);
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> _listFrom(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => Map<String, dynamic>.from(item)).toList();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 28, 16, 24),
      color: _primaryColor,
      child: const Text(
        'Register Subject',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
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
          const _DetailLine(
            icon: Icons.article_outlined,
            iconColor: Color(0xFF8B8F99),
            text: 'Examination - NO',
            highlightLastWord: true,
          ),
          const SizedBox(height: 24),
          _Timetable(rows: timetable),
          const SizedBox(height: 30),
          _SelectRow(
            label: 'Section:',
            value: _selectedSection,
            hint: 'Select',
            items: _sections.map((item) => item['section'].toString()).toList(),
            onChanged: (value) => setState(() => _selectedSection = value),
          ),
          const SizedBox(height: 12),
          _SelectRow(
            label: 'Tutorial/Lab:',
            value: _selectedTutorial,
            hint: 'Select',
            items: _tutorials.map((item) => item['section'].toString()).toList(),
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
                  child: const Text(
                    '0',
                    style: TextStyle(color: Colors.white, fontSize: 8),
                  ),
                ),
              ),
            ],
          ),
          const Expanded(
            child: Center(
              child: Text(
                'CREDIT HOURS: 0',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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
  final List<String> items;
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
            value: items.contains(value) ? value : null,
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
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
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
    final parts = text.split(' ');
    final last = parts.isEmpty ? '' : parts.removeLast();

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
                    ),
                    children: [
                      TextSpan(text: '${parts.join(' ')} '),
                      TextSpan(
                        text: last,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
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
