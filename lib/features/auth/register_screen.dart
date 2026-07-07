import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:phan_family/config/cloudinary_config.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  DateTime? _selectedDate;
  XFile? _selectedAvatar;
  bool _isUploadingAvatar = false;

  // Cloudinary config
  static const String _cloudName = CloudinaryConfig.cloudName;
  static const String _uploadPreset = CloudinaryConfig.uploadPreset;

  // ── Chọn ảnh đại diện ──────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;
    setState(() => _selectedAvatar = image);
  }

  // ── Upload ảnh lên Cloudinary ───────────────────────────────────────
  Future<String?> _uploadToCloudinary(XFile image) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final data = json.decode(await response.stream.bytesToString());
      return data['secure_url'] as String;
    }
    return null;
  }

  // ── Hiển thị BottomSheet chọn ngày sinh ────────────────────────────
  void _showDatePicker() {
    int selectedYear = _selectedDate?.year ?? 2000;
    int selectedMonth = _selectedDate?.month ?? 1;
    int selectedDay = _selectedDate?.day ?? 1;

    final years = List.generate(100, (i) => DateTime.now().year - i);
    final months = List.generate(12, (i) => i + 1);

    int daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBS) {
            final days = List.generate(daysInMonth(selectedYear, selectedMonth), (i) => i + 1);
            if (selectedDay > days.length) selectedDay = days.length;

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn ngày sinh',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: [
                        // DAY
                        Expanded(
                          child: _buildScrollPicker(
                            label: 'Ngày',
                            items: days,
                            selected: selectedDay,
                            onChanged: (v) => setBS(() => selectedDay = v),
                            format: (v) => v.toString().padLeft(2, '0'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // MONTH
                        Expanded(
                          child: _buildScrollPicker(
                            label: 'Tháng',
                            items: months,
                            selected: selectedMonth,
                            onChanged: (v) {
                              setBS(() {
                                selectedMonth = v;
                                final maxDay = daysInMonth(selectedYear, v);
                                if (selectedDay > maxDay) selectedDay = maxDay;
                              });
                            },
                            format: (v) => 'Th.$v',
                          ),
                        ),
                        const SizedBox(width: 8),
                        // YEAR
                        Expanded(
                          child: _buildScrollPicker(
                            label: 'Năm',
                            items: years,
                            selected: selectedYear,
                            onChanged: (v) {
                              setBS(() {
                                selectedYear = v;
                                final maxDay = daysInMonth(v, selectedMonth);
                                if (selectedDay > maxDay) selectedDay = maxDay;
                              });
                            },
                            format: (v) => v.toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime(selectedYear, selectedMonth, selectedDay);
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScrollPicker({
    required String label,
    required List<int> items,
    required int selected,
    required void Function(int) onChanged,
    required String Function(int) format,
  }) {
    final controller = FixedExtentScrollController(initialItem: items.indexOf(selected));
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
            ),
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: 44,
              physics: const FixedExtentScrollPhysics(),
              perspective: 0.003,
              onSelectedItemChanged: (i) => onChanged(items[i]),
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: items.length,
                builder: (ctx, i) {
                  final isSelected = items[i] == selected;
                  return Center(
                    child: Text(
                      format(items[i]),
                      style: TextStyle(
                        color: isSelected ? Colors.amberAccent : Colors.white54,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: isSelected ? 16 : 14,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Đăng ký ────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (_isUploadingAvatar) return;

    String? avatarUrl;
    if (_selectedAvatar != null) {
      setState(() => _isUploadingAvatar = true);
      avatarUrl = await _uploadToCloudinary(_selectedAvatar!);
      setState(() => _isUploadingAvatar = false);
    }

    final dob = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;

    if (!mounted) return;
    context.read<AuthBloc>().add(
      RegisterRequested(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _displayNameController.text.trim(),
        avatarUrl: avatarUrl,
        dateOfBirth: dob,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.redAccent,
            ));
          } else if (state is AuthAuthenticated) {
            Navigator.pop(context);
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF16213E), Color(0xFF0F3460)],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/logo.png', height: 70),
                        const SizedBox(height: 8),
                        const Text(
                          'Đăng Ký',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Tân thủ banner ──────────────────────────
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.card_giftcard, color: Colors.amberAccent, size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tân thủ nhận ngay 200k!',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Avatar picker ───────────────────────────
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.white10,
                                backgroundImage: _selectedAvatar != null
                                    ? FileImage(File(_selectedAvatar!.path))
                                    : null,
                                child: _selectedAvatar == null
                                    ? const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.person, color: Colors.white38, size: 36),
                                          SizedBox(height: 2),
                                          Text(
                                            'Chọn ảnh',
                                            style: TextStyle(color: Colors.white38, fontSize: 10),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Colors.amberAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ảnh đại diện (tùy chọn)',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 16),

                        // ── Tên hiển thị ────────────────────────────
                        _buildTextField(
                          controller: _displayNameController,
                          label: 'Tên hiển thị',
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 12),

                        // ── Email ───────────────────────────────────
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),

                        // ── Mật khẩu ───────────────────────────────
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Mật khẩu',
                          icon: Icons.lock,
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),

                        // ── Ngày sinh ───────────────────────────────
                        GestureDetector(
                          onTap: _showDatePicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedDate != null
                                      ? Colors.amberAccent
                                      : Colors.white24,
                                  width: _selectedDate != null ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cake,
                                  color: _selectedDate != null
                                      ? Colors.amberAccent
                                      : Colors.white54,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedDate != null
                                        ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                                        : 'Ngày sinh (tùy chọn)',
                                    style: TextStyle(
                                      color: _selectedDate != null
                                          ? Colors.white
                                          : Colors.white38,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white38,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Nút đăng ký ─────────────────────────────
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading || _isUploadingAvatar;
                            if (isLoading) {
                              return Column(
                                children: [
                                  const CircularProgressIndicator(color: Colors.amberAccent),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isUploadingAvatar ? 'Đang tải ảnh lên...' : 'Đang đăng ký...',
                                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              );
                            }
                            return SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amberAccent,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: _register,
                                child: const Text(
                                  'ĐĂNG KÝ',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.amberAccent, width: 2),
        ),
      ),
    );
  }
}
