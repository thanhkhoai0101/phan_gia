import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../blocs/feed/feed_bloc.dart';
import '../../../blocs/feed/feed_event.dart';
import '../../../blocs/feed/feed_state.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CreatePostScreen extends StatefulWidget {
  final UserModel currentUser;

  const CreatePostScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  File? _selectedFile;
  MediaType _mediaType = MediaType.none;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickMedia(bool isVideo) async {
    final XFile? pickedFile = isVideo
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile.path);
        _mediaType = isVideo ? MediaType.video : MediaType.image;
      });
    }
  }

  void _submitPost() {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedFile == null) return;

    context.read<FeedBloc>().add(
      AddPost(
        userId: widget.currentUser.uid,
        authorName: widget.currentUser.displayName,
        authorAvatar: widget.currentUser.avatarUrl ?? '',
        content: content,
        mediaFile: _selectedFile,
        mediaType: _mediaType,
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FeedBloc, FeedState>(
      listener: (context, state) {
        if (state is PostCreateSuccess) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng bài thành công!')),
          );
        } else if (state is PostCreateError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tạo bài viết'),
          actions: [
            BlocBuilder<FeedBloc, FeedState>(
              builder: (context, state) {
                final isCreating = state is PostCreating;
                return TextButton(
                  onPressed: isCreating ? null : _submitPost,
                  child: isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Đăng',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: widget.currentUser.avatarUrl != null &&
                                    widget.currentUser.avatarUrl!.isNotEmpty
                                ? NetworkImage(widget.currentUser.avatarUrl!)
                                : null,
                            child: widget.currentUser.avatarUrl == null ||
                                    widget.currentUser.avatarUrl!.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.currentUser.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        minLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Bạn đang nghĩ gì?',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_selectedFile != null)
                      Container(
                        margin: const EdgeInsets.all(16),
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: _mediaType == MediaType.image
                              ? DecorationImage(
                                  image: FileImage(_selectedFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: Colors.grey.shade200,
                        ),
                        child: _mediaType == MediaType.video
                            ? const Center(
                                child: Icon(Icons.videocam, size: 50, color: Colors.grey),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.image, color: Colors.green),
                    onPressed: () => _pickMedia(false),
                    tooltip: 'Thêm ảnh',
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.video, color: Colors.redAccent),
                    onPressed: () => _pickMedia(true),
                    tooltip: 'Thêm video',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
