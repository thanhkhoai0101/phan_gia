import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../services/feed_service.dart';
import '../../services/cloudinary_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../feed/widgets/post_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final FeedService _feedService = FeedService();
  final CloudinaryService _cloudinary = CloudinaryService();
  bool _isLoading = false;

  // Trạng thái bộ lọc: 'all' (Tất cả), 'photos' (Ảnh), 'status' (Trạng thái)
  String _activeFilter = 'all';

  Future<void> _pickAndUploadImage(BuildContext context, UserModel user, bool isAvatar) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    setState(() { _isLoading = true; });

    try {
      // Lấy URL ảnh cũ để xoá sau khi upload thành công
      final String? oldUrl = isAvatar ? user.avatarUrl : user.coverUrl;

      // Upload ảnh mới lên Cloudinary
      final String? downloadUrl = await _cloudinary.uploadImage(File(image.path));
      if (downloadUrl == null) throw Exception('Không thể tải ảnh lên Cloudinary');

      // Xoá ảnh cũ (không block UI, chạy ngầm)
      if (oldUrl != null && oldUrl.isNotEmpty) {
        _cloudinary.deleteByUrl(oldUrl); // fire & forget
      }

      if (!context.mounted) return;
      context.read<AuthBloc>().add(
        UpdateProfileRequested(
          avatarUrl: isAvatar ? downloadUrl : null,
          coverUrl: !isAvatar ? downloadUrl : null,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật ảnh thành công!')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
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
        title: const Text('Hồ sơ', style: TextStyle(color: Colors.white),),
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
                      // GỘP COVER VÀ AVATAR VÀO ĐÂY ĐỂ ĐẢM BẢO CUỘN ĐƯỢC MƯỢT MÀ
                      SizedBox(
                        height: 250, // 200 chiều cao cover + 50 phần nhô ra của avatar
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Cover Photo Area
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
                            // Avatar đặt trong này sẽ cuộn theo màn hình luôn
                            Positioned(
                              bottom: 0,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
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
                      Text(
                        user.email,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 15),
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

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Divider(),
                      ),

                      // ─── THANH PHÂN LOẠI / BỘ LỌC BÀI VIẾT ─────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'Tất cả'),
                            const SizedBox(width: 8),
                            _buildFilterChip('photos', 'Ảnh'),
                            const SizedBox(width: 8),
                            _buildFilterChip('status', 'Trạng thái'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ─── DANH SÁCH BÀI VIẾT TỰ ĐỘNG LỌC REALTIME ───────────
                      StreamBuilder<List<PostModel>>(
                        stream: _feedService.getUserPosts(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(40.0),
                              child: Text('Chưa có bài viết nào.', style: TextStyle(color: Colors.grey)),
                            );
                          }

                          // Tiến hành lọc bài viết ngay trên UI dựa vào tab đang chọn
                          final allPosts = snapshot.data!;
                          final filteredPosts = allPosts.where((post) {
                            if (_activeFilter == 'photos') {
                              return post.mediaType == MediaType.image; // Chỉ lấy bài chứa ảnh
                            } else if (_activeFilter == 'status') {
                              // Trạng thái là bài không chứa ảnh và không chứa video (chỉ có chữ)
                              return post.mediaUrl == null || post.mediaUrl!.isEmpty;
                            }
                            return true; // 'all' lấy hết
                          }).toList();

                          if (filteredPosts.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(40.0),
                              child: Text('Không có bài viết nào thuộc mục này.', style: TextStyle(color: Colors.grey)),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true, // Ép kích thước theo danh sách bài viết
                            physics: const NeverScrollableScrollPhysics(), // Để cuộn mượt theo SingleChildScrollView tổng
                            itemCount: filteredPosts.length,
                            itemBuilder: (context, index) {
                              final post = filteredPosts[index];
                              // Tái sử dụng lại PostCard xịn sò ông làm ở bài trước
                              return PostCard(
                                post: post,
                                currentUser: user,
                                onReact: (type) {
                                  // Xử lý sự kiện thả tim/like bài viết của ông ở đây nếu cần gọi xuống service
                                },
                                onDelete: () {
                                  // Xử lý sự kiện xóa bài viết
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
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

  // Hàm helper để vẽ các nút bấm chọn bộ lọc
  Widget _buildFilterChip(String filterType, String label) {
    final isSelected = _activeFilter == filterType;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFF57C00),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _activeFilter = filterType;
          });
        }
      },
    );
  }
}
