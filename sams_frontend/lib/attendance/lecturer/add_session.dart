import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddSessionPage extends StatefulWidget {
  final int lecturerId;
  final String subjectId;
  final String subjectCode;
  final String subjectName;

  const AddSessionPage({
    super.key,
    required this.lecturerId,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
  });

  @override
  State<AddSessionPage> createState() => _AddSessionPageState();
}

class _AddSessionPageState extends State<AddSessionPage> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isFetchingSections = false;

  final weekController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String selectedSessionType = 'Lecture';

  // Section data from DB
  List<Map<String, dynamic>> sectionOptions = [];
  Map<String, dynamic>? selectedSection;

  @override
  void initState() {
    super.initState();
    _fetchSections('Lecture');
  }

  @override
  void dispose() {
    weekController.dispose();
    super.dispose();
  }

  Future<void> _fetchSections(String sessionType) async {
    setState(() {
      isFetchingSections = true;
      sectionOptions = [];
      selectedSection = null;
    });

    try {
      final type = sessionType == 'Lecture' ? 'lecture' : 'lab';
      final response = await http
          .get(Uri.parse(
            'https://darkgrey-lyrebird-505549.hostingersite.com/api/subjects/${widget.subjectId}/sections?type=$type',
          ))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          sectionOptions = data.map((e) => Map<String, dynamic>.from(e)).toList();
          if (sectionOptions.isNotEmpty) {
            selectedSection = sectionOptions.first;
            _autoFillTime(sectionOptions.first);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching sections: $e');
    } finally {
      if (mounted) setState(() => isFetchingSections = false);
    }
  }

  void _autoFillTime(Map<String, dynamic> section) {
    // Auto-fill time from section data if available
    final timeStr = section['time']?.toString() ?? '';
    if (timeStr.isNotEmpty && timeStr.contains('-')) {
      final parts = timeStr.split('-');
      if (parts.length == 2) {
        final start = _parseTime(parts[0].trim());
        final end = _parseTime(parts[1].trim());
        if (start != null && end != null) {
          setState(() {
            startTime = start;
            endTime = end;
          });
        }
      }
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      // Handle format like "08:00" or "8:00"
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0].trim());
        final minute = int.tryParse(parts[1].trim().substring(0, 2));
        if (hour != null && minute != null) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    } catch (_) {}
    return null;
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _displayTime(TimeOfDay t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final suffix = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2026),
      lastDate: DateTime(2028),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2E4E96)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (startTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (endTime ?? const TimeOfDay(hour: 10, minute: 0)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2E4E96)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) startTime = picked;
        else endTime = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDate == null) {
      _showSnack('Please select a date', isError: true);
      return;
    }
    if (startTime == null) {
      _showSnack('Please select start time', isError: true);
      return;
    }
    if (endTime == null) {
      _showSnack('Please select end time', isError: true);
      return;
    }
    if (selectedSection == null) {
      _showSnack('Please select a section', isError: true);
      return;
    }

    final startMinutes = startTime!.hour * 60 + startTime!.minute;
    final endMinutes = endTime!.hour * 60 + endTime!.minute;
    if (endMinutes <= startMinutes) {
      _showSnack('End time must be after start time', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final sectionName = selectedSection!['section_name']?.toString()
          ?? selectedSection!['lab_name']?.toString()
          ?? selectedSection!['name']?.toString()
          ?? '';
      final venue = selectedSection!['location']?.toString() ?? '';

      final response = await http.post(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/class-sessions'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'subject_id':   int.tryParse(widget.subjectId) ?? 0,
          'lecturer_id':  widget.lecturerId,
          'section':      sectionName,
          'class_date':   _formatDate(selectedDate!),
          'start_time':   _formatTime(startTime!),
          'end_time':     _formatTime(endTime!),
          'venue':        venue,
          'session_type': selectedSessionType,
          'week_number':  int.tryParse(weekController.text.trim()),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        _showSnack('Session added successfully!');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, true);
      } else {
        final data = json.decode(response.body);
        _showSnack(data['message'] ?? 'Failed to add session', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF2E4E96),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E4E96),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Add Class Session',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject info
              _buildInfoCard(),
              const SizedBox(height: 16),

              // Session Type toggle
              _buildCard(
                title: 'Session Type',
                children: [
                  Row(
                    children: ['Lecture', 'Lab'].map((type) {
                      final isSelected = selectedSessionType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (selectedSessionType != type) {
                              setState(() => selectedSessionType = type);
                              _fetchSections(type);
                            }
                          },
                          child: Container(
                            margin: EdgeInsets.only(
                              right: type == 'Lecture' ? 8 : 0,
                              left: type == 'Lab' ? 8 : 0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2E4E96)
                                  : const Color(0xFFF6F7FB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2E4E96)
                                    : const Color(0xFFDDDDDD),
                              ),
                            ),
                            child: Text(
                              type,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section dropdown from DB
              _buildCard(
                title: 'Section',
                children: [
                  isFetchingSections
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2E4E96),
                            ),
                          ),
                        )
                      : sectionOptions.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F7FB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFDDDDDD)),
                              ),
                              child: Text(
                                'No ${selectedSessionType.toLowerCase()} sections found for this subject.',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black45),
                              ),
                            )
                          : DropdownButtonFormField<Map<String, dynamic>>(
                              value: selectedSection,
                              decoration: _inputDecoration('Select section'),
                              isExpanded: true,
                              items: sectionOptions.map((section) {
                                final sectionName =
                                    section['section_name']?.toString()
                                    ?? section['lab_name']?.toString()
                                    ?? section['name']?.toString()
                                    ?? '-';
                                final day = section['day']?.toString() ?? '';
                                final time = section['time']?.toString() ?? '';
                                final location = section['location']?.toString() ?? '';
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: section,
                                  child: Text(
                                    '$sectionName  •  $day $time  •  $location',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => selectedSection = val);
                                if (val != null) _autoFillTime(val);
                              },
                              validator: (v) =>
                                  v == null ? 'Please select a section' : null,
                            ),

                  // Show selected section details
                  if (selectedSection != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E4E96).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            Icons.location_on_outlined,
                            'Venue',
                            selectedSection!['location']?.toString() ?? '-',
                          ),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            Icons.calendar_today_outlined,
                            'Day',
                            selectedSection!['day']?.toString() ?? '-',
                          ),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            Icons.access_time_outlined,
                            'Time',
                            selectedSection!['time']?.toString() ?? '-',
                          ),
                          if (selectedSection!['instructor_name'] != null) ...[
                            const SizedBox(height: 6),
                            _buildDetailRow(
                              Icons.person_outline,
                              'Instructor',
                              selectedSection!['instructor_name']?.toString() ?? '-',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Week number
              _buildCard(
                title: 'Week Number',
                children: [
                  TextFormField(
                    controller: weekController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration('e.g. 1'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Week number is required';
                      if (int.tryParse(v.trim()) == null) return 'Enter a valid number';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date & Time
              _buildCard(
                title: 'Date & Time',
                children: [
                  _buildPickerTile(
                    label: 'Date',
                    value: selectedDate == null
                        ? 'Tap to select'
                        : _displayDate(selectedDate!),
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                    hasValue: selectedDate != null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPickerTile(
                          label: 'Start Time',
                          value: startTime == null
                              ? 'Tap to select'
                              : _displayTime(startTime!),
                          icon: Icons.access_time_outlined,
                          onTap: () => _pickTime(true),
                          hasValue: startTime != null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPickerTile(
                          label: 'End Time',
                          value: endTime == null
                              ? 'Tap to select'
                              : _displayTime(endTime!),
                          icon: Icons.access_time_filled_outlined,
                          onTap: () => _pickTime(false),
                          hasValue: endTime != null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E4E96),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Add Session',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E4E96).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E4E96).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined,
              color: Color(0xFF2E4E96), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subjectCode,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E4E96),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subjectName,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF2E4E96)),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildPickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool hasValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDDDDD)),
            ),
            child: Row(children: [
              Icon(icon,
                  size: 18,
                  color: hasValue
                      ? const Color(0xFF2E4E96)
                      : Colors.black38),
              const SizedBox(width: 10),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      color:
                          hasValue ? Colors.black87 : Colors.black38)),
            ]),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF6F7FB),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2E4E96)),
      ),
    );
  }
}