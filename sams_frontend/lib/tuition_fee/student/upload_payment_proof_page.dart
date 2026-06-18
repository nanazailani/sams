import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UploadPaymentProofPage extends StatefulWidget {
  final String pageTitle;
  final int studentId;

  const UploadPaymentProofPage({
    super.key,
    required this.pageTitle,
    required this.studentId,
  });

  @override
  State<UploadPaymentProofPage> createState() => _UploadPaymentProofPageState();
}

class _UploadPaymentProofPageState extends State<UploadPaymentProofPage> {
  // Controller untuk input amount dan remarks
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // File yang dipilih untuk upload sebagai resit
  String? _selectedFileName;
  String? _selectedFilePath;

  // Default kaedah bayaran — boleh tukar via radio button
  String _selectedPaymentMethod = 'Online Banking';

  bool isSubmitting = false;

  // Info student yang dipaparkan kat atas form
  String studentName = '-';
  String matricNo = '-';
  String semester = '-';

  @override
  void initState() {
    super.initState();
    // Load info student dari local storage dan API
    loadStudentInfo();
  }

  @override
  void dispose() {
    // Buang controller bila page ditutup — elak memory leak
    _remarksController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // Load nama student dari SharedPreferences dulu (offline),
  // lepas tu fetch dari API untuk data yang more lengkap.
  Future<void> loadStudentInfo() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // Guna login_id sebagai nama sementara sambil tunggu API
      studentName = prefs.getString('login_id') ?? '-';
    });

    try {
      final response = await http.get(
        Uri.parse(
          // Untuk development local, uncomment line bawah:
          //'http://127.0.0.1:8000/api/tuition/student/${widget.studentId}/status',
          'https://darkgrey-lyrebird-505549.hostingersite.com/api/tuition/student/${widget.studentId}/status',
        ),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        // Update dengan data sebenar from API
        setState(() {
          studentName = data['student_name']?.toString() ?? '-';
          matricNo = data['matric_no']?.toString() ?? '-';
          semester = data['semester']?.toString() ?? '-';
        });
      }
    } catch (_) {
      // Senyap je kalau failed — data dari SharedPreferences still ada
    }
  }

  // Bukak file picker — student boleh pilih JPG, PNG, atau PDF.
  // Path dan nama file disimpan dalam state untuk upload later.
  Future<void> _chooseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFileName = result.files.single.name;
        _selectedFilePath = result.files.single.path!;
      });
    }
  }

  // Submit payment proof ke API guna multipart request.
  // Hantar student_id, amount, payment_method, remarks, dan file resit.
  Future<void> _submitProof() async {
    // Validate — file dan amount wajib ada sebelum submit
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a file first.')),
      );
      return;
    }

    if (_amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter payment amount.')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // Guna MultipartRequest sebab ada file upload sekali
      final request = http.MultipartRequest(
        'POST',
        // Untuk development local, uncomment line bawah:
        //Uri.parse('http://127.0.0.1:8000/api/tuition/student/submit-payment'),
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/tuition/student/submit-payment'),
      );

      request.headers['Accept'] = 'application/json';
      request.fields['student_id'] = widget.studentId.toString();
      request.fields['amount'] = _amountController.text.trim();
      request.fields['payment_method'] = _selectedPaymentMethod;
      request.fields['remarks'] = _remarksController.text.trim();

      // Attach file resit — field name kena match dengan backend validation
      request.files.add(
        await http.MultipartFile.fromPath(
          'receipt',
          _selectedFilePath!,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Berjaya — balik ke page sebelum dan trigger refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment proof uploaded successfully.')),
        );
        Navigator.pop(context, true);
      } else {
        // Fail — tunjuk mesej error dari API
        String message = 'Upload failed.';
        try {
          final body = jsonDecode(response.body);
          message = body['message']?.toString() ?? message;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      // Error network or others
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      // Pastikan loading state dibuang walaupun ada error
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // Widget radio button untuk pilih payment method.
  // Highlight yang dipilih dengan warna primary.
  Widget _buildPaymentMethodOption({
    required String title,
    required String value,
  }) {
    const Color primaryColor = Color(0xFF40C4C4);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Row(
        children: [
          Radio<String>(
            value: value,
            groupValue: _selectedPaymentMethod,
            activeColor: primaryColor,
            onChanged: (value) {
              setState(() {
                _selectedPaymentMethod = value!;
              });
            },
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF40C4C4);
    const Color bgColor = Color(0xFFF3F3F3);
    const Color borderColor = Color(0xFFB7C0CC);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              //Header dengan butang back 
              Container(
                height: 92,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: primaryColor,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.pageTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Info Student
              // Diload dari API masa page dibuka
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Student Info',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Name: $studentName'),
                      const SizedBox(height: 6),
                      Text('Student ID: $matricNo'),
                      const SizedBox(height: 6),
                      Text('Semester: $semester'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Input Jumlah Bayaran
              // Wajib isi — tak boleh submit kalau kosong
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Payment Amount (RM)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Pilihan payment method
              // Radio button — pilih satu je
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPaymentMethodOption(
                        title: 'Online Banking',
                        value: 'Online Banking',
                      ),
                      _buildPaymentMethodOption(
                        title: 'Credit/Debit Card',
                        value: 'Credit/Debit Card',
                      ),
                      _buildPaymentMethodOption(
                        title: 'Other',
                        value: 'Other',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Upload Resit 
              // click to open file picker — JPG, PNG, atau PDF je
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: _chooseFile,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: primaryColor, width: 1.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          size: 40,
                          color: primaryColor,
                        ),
                        const SizedBox(height: 10),
                        // Tunjuk nama file kalau dah pilih, atau placeholder
                        Text(
                          _selectedFileName ?? 'Choose File / Take Photo',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Remarks (Optional)
              // Student boleh letak remarks — contoh "bayaran kedua"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _remarksController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Remarks (optional)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Button Submit 
              // Disabled dan tunjuk spinner time upload sedang berlaku
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submitProof,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
