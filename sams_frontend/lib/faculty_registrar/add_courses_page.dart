import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AddCoursesPage extends StatefulWidget {
  final VoidCallback onCourseSaved;

  const AddCoursesPage({
    super.key,
    required this.onCourseSaved,
  });

  @override
  State<AddCoursesPage> createState() => _AddCoursesPageState();
}

class _AddCoursesPageState extends State<AddCoursesPage> {
  static const _primaryColor = Color(0xFF3FC7C4);
  static const _secondaryColor = Color(0xFFE6D36F);

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _creditController = TextEditingController();
  final _examDateController = TextEditingController();
  final List<_ClassEntry> _sections = [_ClassEntry()];
  final List<_ClassEntry> _tutorials = [_ClassEntry()];

  bool _hasExamination = true;
  bool _examIsAm = true;
  bool _isSaving = false;
  int _registrarId = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
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
    setState(() {
      entries.add(_ClassEntry());
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
      final res = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/subjects'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'code': _codeController.text.trim().toUpperCase(),
          'name': _nameController.text.trim(),
          'credit_hour': int.parse(_creditController.text.trim()),
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
      child: const Text(
        'Add Courses',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
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
                value: entry.day,
                items: const [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ],
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
                value: entry.time,
                items: const [
                  '8:00 AM',
                  '9:00 AM',
                  '10:00 AM',
                  '11:00 AM',
                  '12:00 PM',
                  '1:00 PM',
                  '2:00 PM',
                  '3:00 PM',
                  '4:00 PM',
                  '5:00 PM',
                ],
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
        _buildTextRow(
          label: 'Instructor:',
          controller: entry.instructorController,
          validator: _required,
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
  final instructorController = TextEditingController();
  String day = 'Mon';
  String time = '8:00 AM';

  Map<String, dynamic> toJson() {
    return {
      'name': nameController.text.trim(),
      'day': day,
      'time': time,
      'location': locationController.text.trim(),
      'capacity': int.tryParse(capacityController.text.trim()) ?? 0,
      'instructor': instructorController.text.trim(),
    };
  }

  void dispose() {
    nameController.dispose();
    locationController.dispose();
    capacityController.dispose();
    instructorController.dispose();
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
    return DropdownButtonFormField<String>(
      value: value,
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
