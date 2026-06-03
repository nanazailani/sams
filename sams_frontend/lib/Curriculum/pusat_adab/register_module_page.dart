import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterModulePage extends StatefulWidget {
  const RegisterModulePage({super.key});

  @override
  State<RegisterModulePage> createState() => _RegisterModulePageState();
}

class _RegisterModulePageState extends State<RegisterModulePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _locationController = TextEditingController();
  final _venueController = TextEditingController();
  final _capacityController = TextEditingController(text: '30');

  DateTime _classDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isSubmitting = false;
  bool _isLoadingModules = true;
  String _errorMessage = '';
  int? _editingModuleId;
  int? _selectedLecturerId;
  List<Map<String, dynamic>> _lecturers = [];
  List<Map<String, dynamic>> _modules = [];

  @override
  void initState() {
    super.initState();
    _fetchLecturers();
    _fetchModules();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _venueController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  String _dateValue(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _dateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _timeValue(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _parseTime(String? value, TimeOfDay fallback) {
    if (value == null || value.isEmpty) return fallback;
    final parts = value.split(':');
    if (parts.length < 2) return fallback;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  DateTime _parseDate(String? value) {
    if (value == null || value.isEmpty) return DateTime.now();
    return DateTime.tryParse(value) ?? DateTime.now();
  }

  Future<void> _fetchModules() async {
    setState(() {
      _isLoadingModules = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/modules?scope=all'),
        headers: const {'Accept': 'application/json'},
      );
      final decoded = _decodeResponse(response);

      if (!mounted) return;

      if (response.statusCode == 200 && decoded['status'] == true) {
        final rows = decoded['data'] as List<dynamic>? ?? [];
        final seenCodes = <String>{};
        final modules = rows
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((module) {
              final code = module['code']?.toString().trim().toUpperCase() ?? '';
              if (code.isEmpty || seenCodes.contains(code)) return false;
              seenCodes.add(code);
              return true;
            })
            .toList();

        setState(() {
          _modules = modules;
          _isLoadingModules = false;
        });
      } else {
        setState(() {
          _errorMessage = decoded['message']?.toString() ?? 'Failed to load modules';
          _isLoadingModules = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoadingModules = false;
      });
    }
  }

  Future<void> _fetchLecturers() async {
    try {
      final response = await http.get(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/lecturers'),
        headers: const {'Accept': 'application/json'},
      );
      final decoded = _decodeResponse(response);

      if (!mounted) return;

      if (response.statusCode == 200 && decoded['status'] == true) {
        final rows = decoded['data'] as List<dynamic>? ?? [];
        setState(() {
          _lecturers = rows
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _selectedLecturerId ??= _lecturers.isEmpty
              ? null
              : int.tryParse(_lecturers.first['id']?.toString() ?? '');
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _classDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );

    if (picked == null) return;
    setState(() => _classDate = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );

    if (picked == null) return;

    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final isEditing = _editingModuleId != null;
      final uri = isEditing
          ? Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/pusat-adab/modules/$_editingModuleId')
          : Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/pusat-adab/modules');
      final body = jsonEncode({
        'code': _codeController.text.trim().toUpperCase(),
        'name': _nameController.text.trim(),
        'category': _categoryController.text.trim(),
        'location': _locationController.text.trim(),
        'venue': _venueController.text.trim(),
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 30,
        'lecturer_id': _selectedLecturerId,
        'class_date': _dateValue(_classDate),
        'start_time': _timeValue(_startTime),
        'end_time': _timeValue(_endTime),
      });

      final response = isEditing
          ? await http.put(
              uri,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: body,
            )
          : await http.post(
              uri,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: body,
            );

      final decoded = _decodeResponse(response);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decoded['message']?.toString() ?? 'Module saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (response.statusCode == 200 && decoded['status'] == true) {
        _resetForm();
        await _fetchModules();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _editingModuleId = null;
      _codeController.clear();
      _nameController.clear();
      _categoryController.clear();
      _locationController.clear();
      _venueController.clear();
      _capacityController.text = '30';
      _selectedLecturerId = _lecturers.isEmpty
          ? null
          : int.tryParse(_lecturers.first['id']?.toString() ?? '');
      _classDate = DateTime.now();
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 17, minute: 0);
    });
  }

  void _startEdit(Map<String, dynamic> module) {
    setState(() {
      _editingModuleId = int.tryParse(module['id']?.toString() ?? '');
      _codeController.text = module['code']?.toString() ?? '';
      _nameController.text = module['name']?.toString() ?? '';
      _categoryController.text = module['category']?.toString() ?? '';
      _locationController.text = module['location']?.toString() ?? '';
      _venueController.text =
          module['venue']?.toString() ?? module['location']?.toString() ?? '';
      _capacityController.text = module['capacity']?.toString() ?? '30';
      _selectedLecturerId = int.tryParse(
        module['lecturer_id']?.toString() ?? '',
      );
      _selectedLecturerId ??= _lecturers.isEmpty
          ? null
          : int.tryParse(_lecturers.first['id']?.toString() ?? '');
      _classDate = _parseDate(module['class_date']?.toString());
      _startTime = _parseTime(
        module['start_time']?.toString(),
        const TimeOfDay(hour: 8, minute: 0),
      );
      _endTime = _parseTime(
        module['end_time']?.toString(),
        const TimeOfDay(hour: 17, minute: 0),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit mode enabled. Update the form and save.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteModule(Map<String, dynamic> module) async {
    final moduleId = int.tryParse(module['id']?.toString() ?? '');
    if (moduleId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete module?'),
        content: Text(
          'This will remove ${module['code'] ?? 'this module'} and its schedule records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE51C2A)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/pusat-adab/modules/$moduleId'),
        headers: const {'Accept': 'application/json'},
      );
      final decoded = _decodeResponse(response);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decoded['message']?.toString() ?? 'Module deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (response.statusCode == 200 && decoded['status'] == true) {
        if (_editingModuleId == moduleId) {
          _resetForm();
        }
        await _fetchModules();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    return {
      'status': false,
      'message': 'Server returned an invalid response.',
    };
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF27206F), Color(0xFF5A4DFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Register Module',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) return '$label is required';
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _lecturerDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedLecturerId,
      validator: (value) => value == null ? 'Lecturer is required' : null,
      decoration: InputDecoration(
        labelText: 'Lecturer',
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      items: _lecturers.map((lecturer) {
        final id = int.tryParse(lecturer['id']?.toString() ?? '');
        final name = lecturer['name']?.toString() ?? 'Unknown Lecturer';
        final staffId = lecturer['staff_id']?.toString() ?? '';

        return DropdownMenuItem<int>(
          value: id,
          child: Text(
            staffId.isEmpty ? name : '$staffId - $name',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedLecturerId = value);
      },
    );
  }

  Widget _pickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF5A4DFF)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleTile(Map<String, dynamic> module) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEBFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book_outlined, color: Color(0xFF5A4DFF)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module['code']?.toString() ?? '--',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF27206F),
                  ),
                ),
                Text(
                  module['name']?.toString() ?? '--',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  module['location']?.toString() ?? '--',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Manage classes',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManageModuleClassesPage(module: module),
                ),
              );
              _fetchModules();
            },
            icon: const Icon(
              Icons.event_available_outlined,
              color: Color(0xFF35C9CA),
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Edit module',
            onPressed: () => _startEdit(module),
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF5A4DFF),
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Delete module',
            onPressed: () => _deleteModule(module),
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFE51C2A),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F2),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _editingModuleId == null
                                      ? 'Create Module & First Class'
                                      : 'Edit Module & First Class',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF27206F),
                                  ),
                                ),
                              ),
                              if (_editingModuleId != null)
                                TextButton(
                                  onPressed: _isSubmitting ? null : _resetForm,
                                  child: const Text('Cancel Edit'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _field(_codeController, 'Module Code'),
                          const SizedBox(height: 12),
                          _field(_nameController, 'Module Name'),
                          const SizedBox(height: 12),
                          _field(
                            _categoryController,
                            'Category',
                            validator: (_) => null,
                          ),
                          const SizedBox(height: 12),
                          _field(_locationController, 'Location'),
                          const SizedBox(height: 12),
                          _field(_venueController, 'Venue'),
                          const SizedBox(height: 12),
                          _lecturerDropdown(),
                          const SizedBox(height: 12),
                          _field(
                            _capacityController,
                            'Capacity',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          _pickerTile(
                            label: 'Activity Date',
                            value: _dateLabel(_classDate),
                            icon: Icons.calendar_today_outlined,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _pickerTile(
                                  label: 'Start Time',
                                  value: _startTime.format(context),
                                  icon: Icons.schedule_outlined,
                                  onTap: () => _pickTime(start: true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _pickerTile(
                                  label: 'End Time',
                                  value: _endTime.format(context),
                                  icon: Icons.schedule_outlined,
                                  onTap: () => _pickTime(start: false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.add_circle_outline),
                              label: Text(
                                _isSubmitting
                                    ? 'Saving...'
                                    : _editingModuleId == null
                                        ? 'Register Module'
                                        : 'Update Module',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF35C9CA),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Available Modules',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF27206F),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isLoadingModules)
                    const Center(child: CircularProgressIndicator())
                  else if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.black54),
                    )
                  else if (_modules.isEmpty)
                    const Text(
                      'No modules registered yet',
                      style: TextStyle(color: Colors.black54),
                    )
                  else
                    ..._modules.map(_moduleTile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManageModuleClassesPage extends StatefulWidget {
  final Map<String, dynamic> module;

  const ManageModuleClassesPage({
    super.key,
    required this.module,
  });

  @override
  State<ManageModuleClassesPage> createState() => _ManageModuleClassesPageState();
}

class _ManageModuleClassesPageState extends State<ManageModuleClassesPage> {
  final _formKey = GlobalKey<FormState>();
  final _venueController = TextEditingController();
  final _capacityController = TextEditingController(text: '30');

  DateTime _classDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isLoading = true;
  bool _isSubmitting = false;
  int? _editingScheduleId;
  int? _selectedLecturerId;
  List<Map<String, dynamic>> _lecturers = [];
  List<Map<String, dynamic>> _schedules = [];

  @override
  void initState() {
    super.initState();
    _fetchLecturers();
    _fetchSchedules();
  }

  @override
  void dispose() {
    _venueController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  int get _moduleId => int.tryParse(widget.module['id']?.toString() ?? '') ?? 0;

  String _dateValue(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _dateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _timeValue(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _timeLabel(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) return '--';
    final parts = rawTime.split(':');
    if (parts.length < 2) return rawTime;
    var hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:$minute $suffix';
  }

  TimeOfDay _parseTime(String? value, TimeOfDay fallback) {
    if (value == null || value.isEmpty) return fallback;
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  DateTime _parseDate(String? value) {
    if (value == null || value.isEmpty) return DateTime.now();
    return DateTime.tryParse(value) ?? DateTime.now();
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    return {
      'status': false,
      'message': 'Server returned an invalid response.',
    };
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/modules/$_moduleId/schedules?scope=all'),
        headers: const {'Accept': 'application/json'},
      );
      final decoded = _decodeResponse(response);

      if (!mounted) return;

      if (response.statusCode == 200 && decoded['status'] == true) {
        final rows = decoded['data'] as List<dynamic>? ?? [];
        setState(() {
          _schedules = rows
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showMessage(decoded['message']?.toString() ?? 'Failed to load classes');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Error: $e');
    }
  }

  Future<void> _fetchLecturers() async {
    try {
      final response = await http.get(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/lecturers'),
        headers: const {'Accept': 'application/json'},
      );
      final decoded = _decodeResponse(response);

      if (!mounted) return;

      if (response.statusCode == 200 && decoded['status'] == true) {
        final rows = decoded['data'] as List<dynamic>? ?? [];
        setState(() {
          _lecturers = rows
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _selectedLecturerId ??= _lecturers.isEmpty
              ? null
              : int.tryParse(_lecturers.first['id']?.toString() ?? '');
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _classDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );

    if (picked == null) return;
    setState(() => _classDate = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );

    if (picked == null) return;
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _submitSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final isEditing = _editingScheduleId != null;
      final uri = isEditing
          ? Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/pusat-adab/schedules/$_editingScheduleId')
          : Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/pusat-adab/modules/$_moduleId/schedules');
      final body = jsonEncode({
        'class_date': _dateValue(_classDate),
        'start_time': _timeValue(_startTime),
        'end_time': _timeValue(_endTime),
        'venue': _venueController.text.trim(),
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 30,
        'lecturer_id': _selectedLecturerId,
      });

      final response = isEditing
          ? await http.put(
              uri,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: body,
            )
          : await http.post(
              uri,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: body,
            );
      final decoded = _decodeResponse(response);

      if (!mounted) return;
      _showMessage(decoded['message']?.toString() ?? 'Class saved');

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          decoded['status'] == true) {
        _resetClassForm();
        await _fetchSchedules();
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetClassForm() {
    setState(() {
      _editingScheduleId = null;
      _venueController.clear();
      _capacityController.text = '30';
      _selectedLecturerId = _lecturers.isEmpty
          ? null
          : int.tryParse(_lecturers.first['id']?.toString() ?? '');
      _classDate = DateTime.now();
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 17, minute: 0);
    });
  }

  void _startEditSchedule(Map<String, dynamic> schedule) {
    setState(() {
      _editingScheduleId = int.tryParse(schedule['id']?.toString() ?? '');
      _venueController.text = schedule['venue']?.toString() ?? '';
      _capacityController.text = schedule['capacity']?.toString() ?? '30';
      _selectedLecturerId = int.tryParse(
        schedule['lecturer_id']?.toString() ?? '',
      );
      _selectedLecturerId ??= _lecturers.isEmpty
          ? null
          : int.tryParse(_lecturers.first['id']?.toString() ?? '');
      _classDate = _parseDate(schedule['date']?.toString());
      _startTime = _parseTime(
        schedule['start_time']?.toString(),
        const TimeOfDay(hour: 8, minute: 0),
      );
      _endTime = _parseTime(
        schedule['end_time']?.toString(),
        const TimeOfDay(hour: 17, minute: 0),
      );
    });
  }

  Future<void> _deleteSchedule(Map<String, dynamic> schedule) async {
    final scheduleId = int.tryParse(schedule['id']?.toString() ?? '');
    if (scheduleId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text(
          '${_dateLabel(_parseDate(schedule['date']?.toString()))}, ${schedule['venue'] ?? '--'} will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE51C2A)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/pusat-adab/schedules/$scheduleId'),
        headers: const {'Accept': 'application/json'},
      );
      final decoded = _decodeResponse(response);

      if (!mounted) return;
      _showMessage(decoded['message']?.toString() ?? 'Class deleted');

      if (response.statusCode == 200 && decoded['status'] == true) {
        if (_editingScheduleId == scheduleId) {
          _resetClassForm();
        }
        await _fetchSchedules();
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF27206F), Color(0xFF5A4DFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.module['code'] ?? '--'} Classes',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '$label is required';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _lecturerDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedLecturerId,
      validator: (value) => value == null ? 'Lecturer is required' : null,
      decoration: InputDecoration(
        labelText: 'Lecturer',
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      items: _lecturers.map((lecturer) {
        final id = int.tryParse(lecturer['id']?.toString() ?? '');
        final name = lecturer['name']?.toString() ?? 'Unknown Lecturer';
        final staffId = lecturer['staff_id']?.toString() ?? '';

        return DropdownMenuItem<int>(
          value: id,
          child: Text(
            staffId.isEmpty ? name : '$staffId - $name',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedLecturerId = value);
      },
    );
  }

  Widget _pickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF5A4DFF)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classCard(Map<String, dynamic> schedule) {
    final booked = schedule['booked_count']?.toString() ?? '0';
    final capacity = schedule['capacity']?.toString() ?? '0';
    final status = schedule['status']?.toString() ?? 'available';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEBFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.event_outlined, color: Color(0xFF5A4DFF)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_dateLabel(_parseDate(schedule['date']?.toString()))} | '
                  '${_timeLabel(schedule['start_time']?.toString())} - '
                  '${_timeLabel(schedule['end_time']?.toString())}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF27206F),
                  ),
                ),
                Text(
                  schedule['venue']?.toString() ?? '--',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  '$booked/$capacity booked | $status',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit class',
            onPressed: () => _startEditSchedule(schedule),
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF5A4DFF), size: 20),
          ),
          IconButton(
            tooltip: 'Delete class',
            onPressed: () => _deleteSchedule(schedule),
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE51C2A), size: 20),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F2),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchSchedules,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _editingScheduleId == null
                                        ? 'Add Available Class'
                                        : 'Edit Available Class',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF27206F),
                                    ),
                                  ),
                                ),
                                if (_editingScheduleId != null)
                                  TextButton(
                                    onPressed:
                                        _isSubmitting ? null : _resetClassForm,
                                    child: const Text('Cancel Edit'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _field(_venueController, 'Venue'),
                            const SizedBox(height: 12),
                            _lecturerDropdown(),
                            const SizedBox(height: 12),
                            _field(
                              _capacityController,
                              'Capacity',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            _pickerTile(
                              label: 'Class Date',
                              value: _dateLabel(_classDate),
                              icon: Icons.calendar_today_outlined,
                              onTap: _pickDate,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _pickerTile(
                                    label: 'Start Time',
                                    value: _startTime.format(context),
                                    icon: Icons.schedule_outlined,
                                    onTap: () => _pickTime(start: true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _pickerTile(
                                    label: 'End Time',
                                    value: _endTime.format(context),
                                    icon: Icons.schedule_outlined,
                                    onTap: () => _pickTime(start: false),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isSubmitting ? null : _submitSchedule,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.add_circle_outline),
                                label: Text(
                                  _isSubmitting
                                      ? 'Saving...'
                                      : _editingScheduleId == null
                                          ? 'Add Class'
                                          : 'Update Class',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF35C9CA),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Available Classes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF27206F),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_schedules.isEmpty)
                      const Text(
                        'No classes for this module yet',
                        style: TextStyle(color: Colors.black54),
                      )
                    else
                      ..._schedules.map(_classCard),
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
