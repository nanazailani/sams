import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _weekdayOptions = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
];

const _timeOptions = [
  '08:00 - 09:50',
  '10:00 - 11:50',
  '12:00 - 13:50',
  '14:00 - 15:50',
  '16:00 - 17:50',
];

String _normalizedDay(String day) {
  return _weekdayOptions.contains(day) ? day : _weekdayOptions.first;
}

String _normalizedTime(String time) {
  switch (time) {
    case '8:00 AM':
    case '9:00 AM':
      return '08:00 - 09:50';
    case '10:00 AM':
    case '11:00 AM':
      return '10:00 - 11:50';
    case '12:00 PM':
    case '1:00 PM':
      return '12:00 - 13:50';
    case '2:00 PM':
    case '3:00 PM':
      return '14:00 - 15:50';
    case '4:00 PM':
    case '5:00 PM':
      return '16:00 - 17:50';
    default:
      return _timeOptions.contains(time) ? time : _timeOptions.first;
  }
}

class AddCoursesPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onCourseSaved;

  const AddCoursesPage({
    super.key,
    required this.onBack,
    required this.onCourseSaved,
  });

  @override
  State<AddCoursesPage> createState() => _AddCoursesPageState();
}

class _AddCoursesPageState extends State<AddCoursesPage> {
  static const _primaryColor = Color(0xFF3FC7C4);
  static const _secondaryColor = Color(0xFFE6D36F);
  static const _apiBaseUrl =
      'https://darkgrey-lyrebird-505549.hostingersite.com/api';

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _creditController = TextEditingController();
  final _examDateController = TextEditingController();
  final List<_ClassEntry> _sections = [_ClassEntry()];
  final List<_ClassEntry> _tutorials = [_ClassEntry()];
  List<_LecturerOption>? _lecturers = [];

  bool _hasExamination = true;
  bool _examIsAm = true;
  bool _isSaving = false;
  int _registrarId = 0;
  int? _selectedLecturerId;

  List<_LecturerOption> get _lecturerOptions =>
      _lecturers ?? const <_LecturerOption>[];

  @override
  void initState() {
    super.initState();
    _loadSession();
    _fetchLecturers();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _creditController.dispose();
    _examDateController.dispose();
    for (final entry in [..._sections, ..._tutorials]) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _registrarId = prefs.getInt('registrar_id') ?? 0;
    });
  }

  void _addEntry(List<_ClassEntry> entries) {
    final lecturers = _lecturerOptions;

    setState(() {
      entries.add(_ClassEntry(
        instructor: lecturers.isEmpty ? '' : lecturers.first.label,
      ));
    });
  }

  Future<void> _fetchLecturers() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBaseUrl/lecturers'))
          .timeout(const Duration(seconds: 10));

      if (!mounted || res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      final List raw = decoded is List ? decoded : decoded['data'] ?? [];
      final lecturers = raw
          .map((item) =>
              _LecturerOption.fromJson(Map<String, dynamic>.from(item)))
          .where((lecturer) => lecturer.id > 0 && lecturer.label.isNotEmpty)
          .toList();

      setState(() {
        _lecturers = lecturers;
        final defaultLecturer =
            lecturers.isEmpty ? null : lecturers.first.label;
        if (defaultLecturer != null) {
          for (final entry in [..._sections, ..._tutorials]) {
            if (entry.instructor.isEmpty) entry.instructor = defaultLecturer;
          }
        }
        _syncSelectedLecturerFromFirstInstructor();
      });
    } catch (_) {}
  }

  void _syncSelectedLecturerFromFirstInstructor() {
    final firstInstructor = _firstInstructorLabel();
    if (firstInstructor == null) {
      _selectedLecturerId = null;
      return;
    }

    for (final lecturer in _lecturerOptions) {
      if (lecturer.label == firstInstructor) {
        _selectedLecturerId = lecturer.id;
        return;
      }
    }

    _selectedLecturerId = null;
  }

  String? _firstInstructorLabel() {
    for (final entry in [..._sections, ..._tutorials]) {
      final instructor = entry.instructor.trim();
      if (instructor.isNotEmpty) return instructor;
    }
    return null;
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    _examDateController.text =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;
    _syncSelectedLecturerFromFirstInstructor();

    if (_selectedLecturerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an instructor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final res = await http.post(
        Uri.parse('$_apiBaseUrl/subjects'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'code': _codeController.text.trim().toUpperCase(),
          'name': _nameController.text.trim(),
          'credit_hour': int.parse(_creditController.text.trim()),
          'lecturer_id': _selectedLecturerId,
          'registrar_id': _registrarId,
          'examination': _hasExamination,
          'exam_date': _hasExamination ? _examDateController.text.trim() : null,
          'exam_period': _hasExamination ? (_examIsAm ? 'AM' : 'PM') : null,
          'sections': _sections.map((entry) => entry.toJson()).toList(),
          'tutorials': _tutorials.map((entry) => entry.toJson()).toList(),
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course added successfully!'),
            backgroundColor: _primaryColor,
          ),
        );
        widget.onCourseSaved();
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to add course'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
                child: Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        _buildCourseDetails(),
                        const Divider(height: 32, thickness: 1.2),
                        _buildClassGroup(
                          label: 'Section:',
                          entries: _sections,
                          onAdd: () => _addEntry(_sections),
                        ),
                        const Divider(height: 34, thickness: 1.2),
                        _buildClassGroup(
                          label: 'Tutorial/Lab:',
                          entries: _tutorials,
                          onAdd: () => _addEntry(_tutorials),
                        ),
                        const Divider(height: 34, thickness: 1.2),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveCourse,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'CONFIRM',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 28, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
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
            'Add Courses',
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

  Widget _buildCourseDetails() {
    return Column(
      children: [
        _buildTextRow(
          label: 'Course Code:',
          controller: _codeController,
          validator: _required,
        ),
        const SizedBox(height: 10),
        _buildTextRow(
          label: 'Course Name:',
          controller: _nameController,
          validator: _required,
        ),
        const SizedBox(height: 10),
        _buildTextRow(
          label: 'Credit Hours:',
          controller: _creditController,
          keyboardType: TextInputType.number,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) return 'Required';
            if (int.tryParse(value!.trim()) == null) return 'Number only';
            return null;
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 88, child: _FormLabel('Examination:')),
            _buildRadioLabel(
              label: 'Yes',
              value: true,
              groupValue: _hasExamination,
              onChanged: (value) => setState(() => _hasExamination = value),
            ),
            const SizedBox(width: 10),
            _buildRadioLabel(
              label: 'No',
              value: false,
              groupValue: _hasExamination,
              onChanged: (value) => setState(() => _hasExamination = value),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 88, child: _FormLabel('Date:')),
            Expanded(
              child: GestureDetector(
                onTap: _hasExamination ? _pickExamDate : null,
                child: AbsorbPointer(
                  child: _PillTextField(
                    controller: _examDateController,
                    enabled: _hasExamination,
                    suffixIcon: Icons.calendar_month,
                    validator: (value) {
                      if (!_hasExamination) return null;
                      if ((value ?? '').trim().isEmpty) return 'Required';
                      return null;
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildRadioLabel(
              label: 'AM',
              value: true,
              groupValue: _examIsAm,
              onChanged: (value) => setState(() => _examIsAm = value),
            ),
            _buildRadioLabel(
              label: 'PM',
              value: false,
              groupValue: _examIsAm,
              onChanged: (value) => setState(() => _examIsAm = value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClassGroup({
    required String label,
    required List<_ClassEntry> entries,
    required VoidCallback onAdd,
  }) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          _buildClassEntry(label, entries[i]),
        ],
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primaryColor, _secondaryColor],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            height: 28,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 11, color: Colors.white),
              label: const Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassEntry(String label, _ClassEntry entry) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 88, child: _FormLabel(label)),
            Expanded(
              child: _PillTextField(
                controller: entry.nameController,
                validator: _required,
              ),
            ),
            const SizedBox(width: 18),
            const SizedBox(width: 44, child: _FormLabel('Day:')),
            Expanded(
              child: _PillDropdown(
                value: _normalizedDay(entry.day),
                items: _weekdayOptions,
                onChanged: (value) => setState(() => entry.day = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 88, child: _FormLabel('Time:')),
            Expanded(
              child: _PillDropdown(
                value: _normalizedTime(entry.time),
                items: _timeOptions,
                onChanged: (value) => setState(() => entry.time = value),
              ),
            ),
            const SizedBox(width: 18),
            const SizedBox(width: 58, child: _FormLabel('Location:')),
            Expanded(
              child: _PillTextField(
                controller: entry.locationController,
                validator: _required,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 88, child: _FormLabel('Capacity:')),
            Expanded(
              child: _PillTextField(
                controller: entry.capacityController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) return 'Required';
                  if (int.tryParse(value!.trim()) == null) return 'Number only';
                  return null;
                },
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
        const SizedBox(height: 10),
        _buildInstructorRow(entry),
      ],
    );
  }

  Widget _buildInstructorRow(_ClassEntry entry) {
    return Row(
      children: [
        const SizedBox(width: 88, child: _FormLabel('Instructor:')),
        Expanded(
          child: _LecturerDropdown(
            value: entry.instructor,
            lecturers: _lecturerOptions,
            onChanged: (value) => setState(() {
              entry.instructor = value;
              _syncSelectedLecturerFromFirstInstructor();
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildTextRow({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Row(
      children: [
        SizedBox(width: 88, child: _FormLabel(label)),
        Expanded(
          child: _PillTextField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildRadioLabel<T>({
    required String label,
    required T value,
    required T groupValue,
    required ValueChanged<T> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<T>(
            value: value,
            groupValue: groupValue,
            onChanged: (newValue) {
              if (newValue != null) onChanged(newValue);
            },
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: Colors.black87,
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
  }
}

class _ClassEntry {
  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final capacityController = TextEditingController();
  String day = 'Mon';
  String time = '08:00 - 09:50';
  String instructor;

  _ClassEntry({this.instructor = ''});

  Map<String, dynamic> toJson() {
    return {
      'name': nameController.text.trim(),
      'day': _normalizedDay(day),
      'time': _normalizedTime(time),
      'location': locationController.text.trim(),
      'capacity': int.tryParse(capacityController.text.trim()) ?? 0,
      'instructor': instructor,
    };
  }

  void dispose() {
    nameController.dispose();
    locationController.dispose();
    capacityController.dispose();
  }
}

class _LecturerOption {
  final int id;
  final String staffId;
  final String name;

  const _LecturerOption({
    required this.id,
    required this.staffId,
    required this.name,
  });

  factory _LecturerOption.fromJson(Map<String, dynamic> json) {
    return _LecturerOption(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      staffId: json['staff_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  String get label {
    if (staffId.isEmpty) return name;
    if (name.isEmpty) return staffId;
    return '$staffId - $name';
  }
}

class _FormLabel extends StatelessWidget {
  final String text;

  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _PillTextField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? suffixIcon;
  final bool enabled;

  const _PillTextField({
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        suffixIcon: suffixIcon == null
            ? null
            : Icon(suffixIcon, size: 15, color: Colors.grey.shade600),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 26, minHeight: 24),
        filled: true,
        fillColor: const Color(0xFFE2DDDD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(height: 0.7, fontSize: 9),
      ),
    );
  }
}

class _PillDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _PillDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedValue = items.contains(value) ? value : items.first;

    return DropdownButtonFormField<String>(
      value: selectedValue,
      isExpanded: true,
      icon: const Icon(Icons.arrow_drop_down, size: 18),
      style: const TextStyle(color: Colors.black87, fontSize: 11),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFE2DDDD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _LecturerDropdown extends StatelessWidget {
  final String value;
  final List<_LecturerOption>? lecturers;
  final ValueChanged<String> onChanged;

  const _LecturerDropdown({
    required this.value,
    required this.lecturers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lecturerOptions = lecturers ?? const <_LecturerOption>[];
    final labels = lecturerOptions.map((lecturer) => lecturer.label).toList();
    final selectedValue = labels.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      value: selectedValue,
      isExpanded: true,
      icon: const Icon(Icons.arrow_drop_down, size: 18),
      style: const TextStyle(color: Colors.black87, fontSize: 11),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFE2DDDD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(height: 0.7, fontSize: 9),
      ),
      hint: Text(
        lecturerOptions.isEmpty ? 'No lecturer found' : 'Select lecturer',
        overflow: TextOverflow.ellipsis,
      ),
      items: labels
          .map((label) => DropdownMenuItem(
                value: label,
                child: Text(label, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      validator: (value) => value == null ? 'Required' : null,
      onChanged: labels.isEmpty
          ? null
          : (value) {
              if (value != null) onChanged(value);
            },
    );
  }
}
