import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

class _CourseDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> subject;
  final Future<void> Function() onSaved;

  const _CourseDetailsDialog({
    required this.subject,
    required this.onSaved,
  });

  @override
  State<_CourseDetailsDialog> createState() => _CourseDetailsDialogState();
}

class _CourseDetailsDialogState extends State<_CourseDetailsDialog> {
  static const _primaryColor = Color(0xFF3FC7C4);
  static const _secondaryColor = Color(0xFFE6D36F);
  static const _apiBaseUrl = 'https://darkgrey-lyrebird-505549.hostingersite.com/api';

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _creditController = TextEditingController();
  final _examDateController = TextEditingController();
  final List<_ClassEntry> _sections = [];
  final List<_ClassEntry> _tutorials = [];

  List<_LecturerOption> _lecturers = [];
  bool _hasExamination = true;
  bool _examIsAm = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fillFromSubject(widget.subject);
    _loadDetails();
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

  Future<void> _loadDetails() async {
    await Future.wait([
      _fetchSubjectDetails(),
      _fetchLecturers(),
    ]);

    if (!mounted) return;
    _ensureRows();
    _applyDefaultLecturer();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchSubjectDetails() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBaseUrl/subjects/${widget.subject['id']}'))
          .timeout(const Duration(seconds: 10));

      if (!mounted || res.statusCode != 200) return;
      _fillFromSubject(Map<String, dynamic>.from(jsonDecode(res.body)));
    } catch (_) {}
  }

  Future<void> _fetchLecturers() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBaseUrl/lecturers'))
          .timeout(const Duration(seconds: 10));

      if (!mounted || res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      final List raw = decoded is List ? decoded : decoded['data'] ?? [];
      _lecturers = raw
          .map((item) =>
              _LecturerOption.fromJson(Map<String, dynamic>.from(item)))
          .where((lecturer) => lecturer.label.isNotEmpty)
          .toList();
    } catch (_) {}
  }

  void _fillFromSubject(Map<String, dynamic> subject) {
    _codeController.text = subject['code']?.toString() ?? '';
    _nameController.text = subject['name']?.toString() ?? '';
    _creditController.text =
        (subject['credit_hour'] ?? subject['credits'] ?? '').toString();
    _hasExamination = _boolValue(subject['examination'], fallback: true);
    _examDateController.text = subject['exam_date']?.toString() ?? '';
    _examIsAm = (subject['exam_period']?.toString().toUpperCase() ?? 'AM') !=
        'PM';

    _replaceEntries(_sections, subject['sections']);
    _replaceEntries(_tutorials, subject['tutorials']);
  }

  void _replaceEntries(List<_ClassEntry> target, dynamic rawEntries) {
    if (rawEntries is! List) return;

    for (final entry in target) {
      entry.dispose();
    }

    target
      ..clear()
      ..addAll(rawEntries.map((entry) {
        final data = Map<String, dynamic>.from(entry as Map);
        return _ClassEntry.fromJson(data);
      }));
  }

  void _ensureRows() {
    if (_sections.isEmpty) _sections.add(_ClassEntry());
    if (_tutorials.isEmpty) _tutorials.add(_ClassEntry());
  }

  void _applyDefaultLecturer() {
    if (_lecturers.isEmpty) return;
    final defaultLecturer = _lecturers.first.label;

    for (final entry in [..._sections, ..._tutorials]) {
      if (entry.instructor.isEmpty) entry.instructor = defaultLecturer;
    }
  }

  bool _boolValue(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  void _addEntry(List<_ClassEntry> entries) {
    setState(() {
      entries.add(_ClassEntry(
        instructor: _lecturers.isEmpty ? '' : _lecturers.first.label,
      ));
    });
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

    setState(() => _isSaving = true);
    try {
      final res = await http.put(
        Uri.parse('$_apiBaseUrl/subjects/${widget.subject['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'code': _codeController.text.trim().toUpperCase(),
          'name': _nameController.text.trim(),
          'credit_hour': int.parse(_creditController.text.trim()),
          'examination': _hasExamination,
          'exam_date': _hasExamination ? _examDateController.text.trim() : null,
          'exam_period': _hasExamination ? (_examIsAm ? 'AM' : 'PM') : null,
          'sections': _sections.map((entry) => entry.toJson()).toList(),
          'tutorials': _tutorials.map((entry) => entry.toJson()).toList(),
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subject updated successfully'),
            backgroundColor: _primaryColor,
          ),
        );
        await widget.onSaved();
        if (mounted) Navigator.pop(context);
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to update subject'),
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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: _isLoading
            ? const SizedBox(
                height: 240,
                child: Center(
                  child: CircularProgressIndicator(color: _primaryColor),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'View Subject Details',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed:
                                _isSaving ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _isSaving ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('CANCEL'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveCourse,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                elevation: 0,
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
                                  : const Text('SAVE'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
        const SizedBox(height: 8),
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
        Row(
          children: [
            const SizedBox(width: 88, child: _FormLabel('Instructor:')),
            Expanded(
              child: _LecturerDropdown(
                value: entry.instructor,
                lecturers: _lecturers,
                onChanged: (value) => setState(() => entry.instructor = value),
              ),
            ),
          ],
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

  factory _ClassEntry.fromJson(Map<String, dynamic> json) {
    final entry = _ClassEntry(
      instructor: json['instructor']?.toString() ?? '',
    );
    entry.nameController.text =
        (json['name'] ?? json['section'] ?? '').toString();
    entry.day = _normalizedDay(json['day']?.toString() ?? '');
    entry.time = _normalizedTime(json['time']?.toString() ?? '');
    entry.locationController.text = json['location']?.toString() ?? '';
    entry.capacityController.text = json['capacity']?.toString() ?? '';
    return entry;
  }

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
  final String staffId;
  final String name;

  const _LecturerOption({
    required this.staffId,
    required this.name,
  });

  factory _LecturerOption.fromJson(Map<String, dynamic> json) {
    return _LecturerOption(
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
        suffixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 24),
        filled: true,
        fillColor: const Color(0xFFE2DDDD),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
  final List<_LecturerOption> lecturers;
  final ValueChanged<String> onChanged;

  const _LecturerDropdown({
    required this.value,
    required this.lecturers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = lecturers.map((lecturer) => lecturer.label).toList();
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(height: 0.7, fontSize: 9),
      ),
      hint: Text(
        lecturers.isEmpty ? 'No lecturer found' : 'Select lecturer',
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

class ManageCoursesPage extends StatefulWidget {
  final VoidCallback onAddCoursesTap;

  const ManageCoursesPage({
    super.key,
    required this.onAddCoursesTap,
  });

  @override
  State<ManageCoursesPage> createState() => _ManageCoursesPageState();
}

class _ManageCoursesPageState extends State<ManageCoursesPage> {
  List<dynamic> allSubjects = [];
  List<dynamic> filteredSubjects = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredSubjects = allSubjects.where((s) {
        final code = (s['code'] ?? '').toString().toLowerCase();
        final name = (s['name'] ?? '').toString().toLowerCase();
        return code.contains(query) || name.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchSubjects() async {
    setState(() => isLoading = true);
    try {
      final res = await http

          // .get(Uri.parse('http://10.0.2.2:8000/api/subjects'))
          .get(Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/subjects'))

          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List subjects = data is List ? data : (data['data'] ?? []);
        setState(() {
          allSubjects = subjects;
          filteredSubjects = List.from(subjects);
        });
      }
    } catch (_) {}
    setState(() => isLoading = false);
  }

  Future<void> _deleteSubject(dynamic subject) async {
    final id = subject['id'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Subject'),
        content: Text(
            'Are you sure you want to delete "${subject['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4D),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(

        //Uri.parse('http://10.0.2.2:8000/api/subjects/$id'),
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/subjects/$id'),

        headers: {'Accept': 'application/json'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subject deleted successfully'),
            backgroundColor: Color(0xFF3FC7C4),
          ),
        );
        await _fetchSubjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete subject'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showViewDialog(dynamic subject) {
    showDialog(
      context: context,
      builder: (ctx) => _CourseDetailsDialog(
        subject: Map<String, dynamic>.from(subject as Map),
        onSaved: _fetchSubjects,
      ),
    );
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
              child: const Text(
                'Manage Courses',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'SEARCH',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                          prefixIcon: Icon(Icons.search,
                              color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Add Courses button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.onAddCoursesTap,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Courses'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3FC7C4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Table header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 75,
                            child: Text('Code',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.black87)),
                          ),
                          Expanded(
                            child: Text('Course Name',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.black87)),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text('Credit',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.black87)),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text('Action',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.black87)),
                          ),
                        ],
                      ),
                    ),

                    // Table body
                    Expanded(
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF3FC7C4)))
                          : filteredSubjects.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.menu_book_outlined,
                                          size: 60,
                                          color: Colors.grey.shade300),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No subject listed',
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 15),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: ListView.separated(
                                      itemCount: filteredSubjects.length,
                                      separatorBuilder: (_, __) => Divider(
                                          color: Colors.grey.shade100,
                                          height: 1),
                                      itemBuilder: (context, i) {
                                        final s = filteredSubjects[i];
                                        final code = s['code'] ?? '';
                                        final name = s['name'] ?? '';
                                        final credit = (s['credit_hour'] ??
                                                s['credits'] ??
                                                '-')
                                            .toString();

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          child: Row(
                                            children: [
                                              // Code
                                              SizedBox(
                                                width: 75,
                                                child: Text(
                                                  code,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black87),
                                                ),
                                              ),
                                              // Name
                                              Expanded(
                                                child: Text(
                                                  name.toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black87),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              // Credit
                                              SizedBox(
                                                width: 48,
                                                child: Text(
                                                  credit,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black87),
                                                ),
                                              ),
                                              // Actions
                                              SizedBox(
                                                width: 80,
                                                child: Column(
                                                  children: [
                                                    // View button
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _showViewDialog(s),
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10,
                                                            vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          gradient:
                                                              const LinearGradient(
                                                            colors: [
                                                              Color(0xFF3FC7C4),
                                                              Color(0xFFE6D36F),
                                                            ],
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: const Center(
                                                          child: Text(
                                                            'View',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    // Delete button
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _deleteSubject(s),
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10,
                                                            vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFFFF4D4D),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: const Center(
                                                          child: Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
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
