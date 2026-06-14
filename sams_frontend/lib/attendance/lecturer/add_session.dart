import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddSessionPage extends StatefulWidget {
  // Info subjek yang dipassing dari page sebelum ni
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
  bool isLoading = false;         // Loading state masa submit form
  bool isFetchingSections = false; // Loading state masa fetch sections dari API

  final weekController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String selectedSessionType = 'Lecture'; // Default: Lecture

  // Senarai sections dari database & section yang dipilih
  List<Map<String, dynamic>> sectionOptions = [];
  Map<String, dynamic>? selectedSection;

  @override
  void initState() {
    super.initState();
    // Fetch sections untuk Lecture by default bila page ni dibuka
    _fetchSections('Lecture');
  }

  @override
  void dispose() {
    // Dispose controller elak memory leak
    weekController.dispose();
    super.dispose();
  }

  /// Fetch senarai sections dari API berdasarkan jenis sesi (lecture/lab).
  /// Bila session type bertukar, list section akan reset dan fetch semula.
  Future<void> _fetchSections(String sessionType) async {
    setState(() {
      isFetchingSections = true;
      sectionOptions = [];     // Reset list lama
      selectedSection = null;  // Reset pilihan lama
    });

    try {
      // Convert session type ke lowercase untuk query param
      final type = sessionType == 'Lecture' ? 'lecture' : 'lab';
      final response = await http
          .get(Uri.parse(
            'https://darkgrey-lyrebird-505549.hostingersite.com/api/subjects/${widget.subjectId}/sections?type=$type',
          ))
          .timeout(const Duration(seconds: 10));

      // Kalau widget dah disposed (user keluar), jangan proceed
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          sectionOptions = data.map((e) => Map<String, dynamic>.from(e)).toList();
          // Auto-select section pertama & auto-fill masa dia
          if (sectionOptions.isNotEmpty) {
            selectedSection = sectionOptions.first;
            _autoFillTime(sectionOptions.first);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching sections: $e');
    } finally {
      // Pastikan loading indicator dimatikan walaupun ada error
      if (mounted) setState(() => isFetchingSections = false);
    }
  }

  /// Auto-fill masa start dan end berdasarkan data section yang dipilih.
  /// Format masa yang dijangka dari API: "08:00-10:00" atau "8:00 AM-10:00 AM"
  void _autoFillTime(Map<String, dynamic> section) {
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

  /// Parse string masa seperti "08:00" atau "8:00" jadi TimeOfDay.
  /// Return null kalau format tak valid.
  TimeOfDay? _parseTime(String timeStr) {
    try {
      // Handle format "08:00" atau "8:00"
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0].trim());
        // Ambil 2 digit pertama je dari minit (abaikan AM/PM kalau ada)
        final minute = int.tryParse(parts[1].trim().substring(0, 2));
        if (hour != null && minute != null) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Format TimeOfDay ke string "HH:mm:ss" untuk hantar ke API
  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  /// Format DateTime ke string "YYYY-MM-DD" untuk hantar ke API
  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Format DateTime untuk display pada UI, contoh: "14 Jun 2026"
  String _displayDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Format TimeOfDay ke 12-jam format untuk display, contoh: "8:00 AM"
  String _displayTime(TimeOfDay t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final suffix = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  /// Buka date picker untuk user pilih tarikh sesi
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2026),
      lastDate: DateTime(2028),
      builder: (context, child) => Theme(
        // Override warna picker ikut color scheme SAMS
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2E4E96)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  /// Buka time picker untuk user pilih masa mula atau masa tamat.
  /// [isStart] = true untuk start time, false untuk end time.
  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      // Guna masa yang dah dipilih sebelum ni sebagai initial value
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

  /// Validate semua input dan submit form ke API untuk create class session baru.
  Future<void> _submit() async {
    // Validate form fields dulu
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

    // Pastikan end time mesti selepas start time
    final startMinutes = startTime!.hour * 60 + startTime!.minute;
    final endMinutes = endTime!.hour * 60 + endTime!.minute;
    if (endMinutes <= startMinutes) {
      _showSnack('End time must be after start time', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Resolve section name — API boleh return dalam pelbagai key name
      final sectionName = selectedSection!['section_name']?.toString()
          ?? selectedSection!['lab_name']?.toString()
          ?? selectedSection!['name']?.toString()
          ?? '';
      final venue = selectedSection!['location']?.toString() ?? '';

      // POST request ke API untuk create session baru
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
        // Session berjaya dicipta — balik ke page sebelum dengan result = true
        _showSnack('Session added successfully!');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, true); // true = page perlu refresh
      } else {
        // Tunjuk error message dari API
        final data = json.decode(response.body);
        _showSnack(data['message'] ?? 'Failed to add session', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Helper untuk tunjuk snackbar — merah kalau error, biru kalau success
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
              // Card info subjek — tunjuk code & nama subjek kat atas sekali
              _buildInfoCard(),
              const SizedBox(height: 16),

              // Toggle Lecture / Lab — bila bertukar, sections akan di-fetch semula
              _buildCard(
                title: 'Session Type',
                children: [
                  Row(
                    children: ['Lecture', 'Lab'].map((type) {
                      final isSelected = selectedSessionType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            // Elak fetch semula kalau type sama
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
                              // Highlight button yang dipilih dengan warna biru
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

              // Dropdown sections — populated dari API, auto-fill masa bila pilih
              _buildCard(
                title: 'Section',
                children: [
                  isFetchingSections
                      // Tunjuk loading spinner masa fetch sections
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
                          // Kalau takde sections, tunjuk mesej kosong
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
                          // Dropdown dengan semua sections yang ada
                          : DropdownButtonFormField<Map<String, dynamic>>(
                              value: selectedSection,
                              decoration: _inputDecoration('Select section'),
                              isExpanded: true,
                              items: sectionOptions.map((section) {
                                // Handle pelbagai key name dari API
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
                                  // Format: "A1  •  Monday 08:00-10:00  •  DK1"
                                  child: Text(
                                    '$sectionName  •  $day $time  •  $location',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => selectedSection = val);
                                // Auto-fill masa bila section bertukar
                                if (val != null) _autoFillTime(val);
                              },
                              validator: (v) =>
                                  v == null ? 'Please select a section' : null,
                            ),

                  // Detail section yang dipilih — venue, hari, masa, instructor
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
                          // Instructor hanya dipaparkan kalau data ada
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

              // Input minggu — wajib diisi, angka sahaja
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

              // Date & Time pickers — tap untuk buka dialog pilihan
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

              // Butang submit — disable dan tunjuk spinner masa loading
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

  /// Card info subjek kat bahagian atas form — tunjuk kod dan nama subjek
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

  /// Reusable card container dengan title dan senarai children widgets
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

  /// Row untuk tunjuk detail section — icon, label, dan value dalam satu baris
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

  /// Tile untuk date/time picker — tunjuk icon, label, dan nilai yang dipilih.
  /// Warna bertukar bila value dah ada (biru) vs belum pilih (kelabu)
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
              // Icon biru kalau dah ada value, kelabu kalau belum
              Icon(icon,
                  size: 18,
                  color: hasValue
                      ? const Color(0xFF2E4E96)
                      : Colors.black38),
              const SizedBox(width: 10),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      color: hasValue ? Colors.black87 : Colors.black38)),
            ]),
          ),
        ),
      ],
    );
  }

  /// Reusable input decoration untuk TextFormField dan DropdownButtonFormField
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
      // Border bertukar biru bila field dalam focus
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2E4E96)),
      ),
    );
  }
}
