import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickAndUploadImage(BuildContext context, UserModel user, bool isAvatar) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final File file = File(image.path);
      
      final String cloudName = 'dogxxj74b';
      final String uploadPreset = 'ml_default';
      
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);
        final String downloadUrl = jsonResponse['secure_url'];

        if (!context.mounted) return;
        context.read<AuthBloc>().add(
          UpdateProfileRequested(
            avatarUrl: isAvatar ? downloadUrl : null,
            coverUrl: !isAvatar ? downloadUrl : null,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật ảnh thành công!')));
      } else {
        throw Exception('Không thể tải file lên Cloudinary');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editDisplayName(BuildContext context, UserModel user) async {
    TextEditingController nameController = TextEditingController(text: user.displayName);
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Đổi tên hiển thị'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: "Nhập tên mới"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  context.read<AuthBloc>().add(UpdateProfileRequested(displayName: nameController.text.trim()));
                  Navigator.pop(context);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        backgroundColor: const Color(0xFFF57C00),
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            final user = state.user;
            return Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // Cover Photo Area
                      Stack(
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey[300],
                            child: user.coverUrl != null && user.coverUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: user.coverUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  )
                                : const Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
                              onPressed: () => _pickAndUploadImage(context, user, false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),
                      // User Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user.displayName.isEmpty ? 'Chưa có tên' : user.displayName,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editDisplayName(context, user),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        user.email,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: ListTile(
                          leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                          title: const Text('Số dư'),
                          trailing: Text(
                            '${user.balance} VND',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Avatar Positioned
                Positioned(
                  top: 150,
                  left: MediaQuery.of(context).size.width / 2 - 50,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: Colors.grey[400],
                          backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(user.avatarUrl!)
                              : const AssetImage('assets/images/logo.png') as ImageProvider,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFF57C00),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            onPressed: () => _pickAndUploadImage(context, user, true),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
