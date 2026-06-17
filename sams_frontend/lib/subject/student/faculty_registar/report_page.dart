import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  static const _primaryColor = Color(0xFF28C2C6);
  static const _secondaryColor = Color(0xFFEBDD63);
  static const _backgroundColor = Color(0xFFF8F6F6);
  //static const _apiBaseUrl = 'http://10.0.2.2:8000/api';
  static const _apiBaseUrl = 'https://darkgrey-lyrebird-505549.hostingersite.com/api';

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  int? _downloadingSubjectId;
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  //ambil subject list utk report table.
  //table ni jadi entry point untuk generate student list by section/tutorial.
  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);

    try {
      final response = await http
          .get(Uri.parse('$_apiBaseUrl/subjects'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List rawSubjects = decoded is List ? decoded : decoded['data'] ?? [];

        setState(() {
          _subjects = rawSubjects
              .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      } else {
        _showSnack('Failed to load subject list', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSubjects {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _subjects;

    return _subjects.where((subject) {
      final code = subject['code']?.toString().toLowerCase() ?? '';
      final name = subject['name']?.toString().toLowerCase() ?? '';
      return code.contains(query) || name.contains(query);
    }).toList();
  }

  //pilih section/tutorial dulu sebelum generate PDF.
  //report perlu slot spesifik supaya student list tak bercampur semua section.
  Future<void> _openStudentListOptions(Map<String, dynamic> subject) async {
    final subjectId = subject['id'];
    if (subjectId == null || _downloadingSubjectId != null) return;

    setState(() => _downloadingSubjectId = int.tryParse(subjectId.toString()));

    try {
      final response = await http
          .get(Uri.parse('$_apiBaseUrl/subjects/$subjectId'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode != 200) {
        _showSnack('Failed to load section list', isError: true);
        return;
      }

      final data = jsonDecode(response.body);
      final slots = _reportSlotsFromSubject(Map<String, dynamic>.from(data));

      if (slots.isEmpty) {
        _showSnack('No section or tutorial/lab found', isError: true);
        return;
      }

      setState(() => _downloadingSubjectId = null);
      if (!mounted) return;

      final selectedSlot = await showDialog<_ReportSlot>(
        context: context,
        builder: (dialogContext) => _ReportSlotDialog(
          subject: subject,
          slots: slots,
          onSelected: (slot) {
            Navigator.pop(dialogContext, slot);
          },
        ),
      );

      if (selectedSlot != null) {
        await _downloadStudentList(subject, selectedSlot);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted && _downloadingSubjectId == int.tryParse(subjectId.toString())) {
        setState(() => _downloadingSubjectId = null);
      }
    }
  }

  //convert section and tutorial data jadi report slot.
  //mode L = lecture, mode B = tutorial/lab, backend guna mode ni utk filter.
  List<_ReportSlot> _reportSlotsFromSubject(Map<String, dynamic> subject) {
    final rawSections = subject['sections'] is List ? subject['sections'] as List : [];
    final rawTutorials = subject['tutorials'] is List ? subject['tutorials'] as List : [];

    final sections = rawSections
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map((item) => _ReportSlot.fromMap(item, mode: 'L'))
        .where((slot) => slot.section.isNotEmpty)
        .toList();
    final tutorials = rawTutorials
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map((item) => _ReportSlot.fromMap(item, mode: 'B'))
        .where((slot) => slot.section.isNotEmpty)
        .toList();

    return [...sections, ...tutorials];
  }

  //download student list ikut subject and slot selected.
  //API return approved students untuk slot tu, then app build PDF.
  Future<void> _downloadStudentList(
    Map<String, dynamic> subject,
    _ReportSlot slot,
  ) async {
    final subjectId = subject['id'];
    if (subjectId == null || _downloadingSubjectId != null) return;

    setState(() => _downloadingSubjectId = int.tryParse(subjectId.toString()));

    try {
      final uri = Uri.parse(
        '$_apiBaseUrl/subjects/$subjectId/registered-students',
      ).replace(queryParameters: {
        'mode': slot.mode,
        'section': slot.section,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode != 200) {
        _showSnack('Failed to load student list', isError: true);
        return;
      }

      final data = jsonDecode(response.body);
      final List rawStudents = data['students'] ?? [];
      final students = rawStudents
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
          .toList();

      final bytes = await _buildStudentListPdf(subject, students, slot);
      final code = _safeFileName(subject['code']?.toString() ?? 'subject');
      final slotName = _safeFileName(slot.section);

      await Printing.sharePdf(
        bytes: bytes,
        filename: '${code}_${slotName}_student_list.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _downloadingSubjectId = null);
    }
  }

  //build PDF file sebelum share/download.
  //semua data student disusun dalam table supaya senang print/simpan.
  Future<Uint8List> _buildStudentListPdf(
    Map<String, dynamic> subject,
    List<Map<String, dynamic>> students,
    _ReportSlot slot,
  ) async {
    final document = pw.Document();
    final code = subject['code']?.toString() ?? '-';
    final name = subject['name']?.toString() ?? '-';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Student List Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Subject Code: $code'),
          pw.Text('Course Name: ${name.toUpperCase()}'),
          pw.Text('${slot.typeLabel}: ${slot.section}'),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const [
              'No.',
              'Student Name',
              'Matric Number',
              'Year of Study',
              'Advisor Name',
            ],
            data: students.isEmpty
                ? [
                    ['-', 'No Registered Student', '-', '-', '-']
                  ]
                : List.generate(students.length, (index) {
                    final student = students[index];
                    return [
                      '${index + 1}',
                      student['name']?.toString() ?? '-',
                      student['matric_no']?.toString() ?? '-',
                      student['year']?.toString() ?? '-',
                      student['advisor']?.toString() ?? '-',
                    ];
                  }),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF28C2C6),
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2.1),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(1.8),
            },
          ),
        ],
      ),
    );

    return document.save();
  }

  String _safeFileName(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 79,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: const Text(
                'Generate Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadSubjects,
                color: _primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    children: [
                      _SearchBox(controller: _searchController),
                      const SizedBox(height: 20),
                      _ReportTable(
                        isLoading: _isLoading,
                        subjects: _filteredSubjects,
                        downloadingSubjectId: _downloadingSubjectId,
                        onStudentListPressed: _openStudentListOptions,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSlot {
  final String mode;
  final String section;
  final String day;
  final String time;
  final String location;

  const _ReportSlot({
    required this.mode,
    required this.section,
    required this.day,
    required this.time,
    required this.location,
  });

  factory _ReportSlot.fromMap(Map<String, dynamic> item, {required String mode}) {
    return _ReportSlot(
      mode: mode,
      section: item['section']?.toString() ?? '',
      day: item['day']?.toString() ?? '',
      time: item['time']?.toString() ?? '',
      location: item['location']?.toString() ?? '',
    );
  }

  String get typeLabel => mode == 'B' ? 'Tutorial/Lab' : 'Section';

  String get subtitle {
    final details = [day, time, location]
        .where((item) => item.trim().isNotEmpty)
        .join(' | ');
    return details.isEmpty ? typeLabel : details;
  }
}

class _ReportSlotDialog extends StatelessWidget {
  final Map<String, dynamic> subject;
  final List<_ReportSlot> slots;
  final ValueChanged<_ReportSlot> onSelected;

  const _ReportSlotDialog({
    required this.subject,
    required this.slots,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final code = subject['code']?.toString() ?? '';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Student List - $code',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF28C2C6),
        ),
      ),
      content: SizedBox(
        width: 360,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: slots.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final slot = slots[index];

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                slot.mode == 'B'
                    ? Icons.science_outlined
                    : Icons.menu_book_outlined,
                color: const Color(0xFF28C2C6),
              ),
              title: Text(
                '${slot.typeLabel}: ${slot.section}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                slot.subtitle,
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () => onSelected(slot),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBox({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 31,
      child: TextField(
        controller: controller,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'SEARCH',
          hintStyle: const TextStyle(fontSize: 11, color: Colors.black87),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 8, right: 5),
            child: Icon(Icons.search, size: 24, color: Color(0xFF5B5B5B)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: const Color(0xFFF8F6F6),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Colors.black, width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Colors.black, width: 0.8),
          ),
        ),
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  final bool isLoading;
  final int? downloadingSubjectId;
  final List<Map<String, dynamic>> subjects;
  final ValueChanged<Map<String, dynamic>> onStudentListPressed;

  const _ReportTable({
    required this.isLoading,
    required this.subjects,
    required this.downloadingSubjectId,
    required this.onStudentListPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        color: Colors.white,
        child: Column(
          children: [
            const _TableHeader(),
            if (isLoading)
              const SizedBox(
                height: 190,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF28C2C6)),
                ),
              )
            else if (subjects.isEmpty)
              const SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'No subject listed',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
              )
            else
              ...List.generate(subjects.length, (index) {
                final subject = subjects[index];
                final id = int.tryParse(subject['id']?.toString() ?? '');
                final isDownloading = id != null && id == downloadingSubjectId;

                return _SubjectRow(
                  subject: subject,
                  showDivider: index != subjects.length - 1,
                  isDownloading: isDownloading,
                  onPressed: () => onStudentListPressed(subject),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 29,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black, width: 1),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              'Code',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              'Course Name',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 88,
            child: Text(
              'Action',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final bool showDivider;
  final bool isDownloading;
  final Map<String, dynamic> subject;
  final VoidCallback onPressed;

  const _SubjectRow({
    required this.subject,
    required this.showDivider,
    required this.isDownloading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final code = subject['code']?.toString() ?? '-';
    final name = subject['name']?.toString().toUpperCase() ?? '-';

    return Container(
      height: 64,
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Colors.black, width: 0.8))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 10,
                  height: 1.15,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: Center(
              child: SizedBox(
                height: 19,
                child: ElevatedButton(
                  onPressed: isDownloading ? null : onPressed,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF28C2C6),
                    disabledBackgroundColor: const Color(0xFF9CDCDD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(58, 19),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isDownloading
                      ? const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Student List',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
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
