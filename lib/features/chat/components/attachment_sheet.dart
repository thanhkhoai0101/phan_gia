import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/message_model.dart';

class AttachmentSheet extends StatelessWidget {
  final Function(File file, MessageType type) onMediaSelected;
  final Function(String gifUrl) onGifSelected;

  const AttachmentSheet({
    Key? key,
    required this.onMediaSelected,
    required this.onGifSelected,
  }) : super(key: key);

  Future<void> _pickMedia(BuildContext context, ImageSource source, bool isVideo) async {
    final ImagePicker picker = ImagePicker();
    Navigator.of(context).pop(); // Close sheet first

    try {
      if (isVideo) {
        final XFile? file = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 5),
        );
        if (file != null) {
          onMediaSelected(File(file.path), MessageType.video);
        }
      } else {
        final XFile? file = await picker.pickImage(
          source: source,
          imageQuality: 80,
        );
        if (file != null) {
          onMediaSelected(File(file.path), MessageType.image);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn file: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF162435),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Gửi nội dung đính kèm',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOption(
                context,
                icon: Icons.photo_library_outlined,
                color: Colors.purpleAccent,
                label: 'Thư viện ảnh',
                onTap: () => _pickMedia(context, ImageSource.gallery, false),
              ),
              _buildOption(
                context,
                icon: Icons.camera_alt_outlined,
                color: Colors.blueAccent,
                label: 'Chụp ảnh',
                onTap: () => _pickMedia(context, ImageSource.camera, false),
              ),
              _buildOption(
                context,
                icon: Icons.video_library_outlined,
                color: Colors.orangeAccent,
                label: 'Gửi Video',
                onTap: () => _pickMedia(context, ImageSource.gallery, true),
              ),
              _buildOption(
                context,
                icon: Icons.gif_box_outlined,
                color: Colors.tealAccent,
                label: 'Gửi GIF',
                onTap: () {
                  Navigator.of(context).pop(); // Close attachment sheet
                  _showGifSearch(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showGifSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GifSearchSheet(onGifSelected: onGifSelected),
    );
  }
}

// ==========================================
// CUSTOM GIF SEARCH SHEET WITH TENOR API
// ==========================================
class GifSearchSheet extends StatefulWidget {
  final Function(String gifUrl) onGifSelected;

  const GifSearchSheet({Key? key, required this.onGifSelected}) : super(key: key);

  @override
  State<GifSearchSheet> createState() => _GifSearchSheetState();
}

class _GifSearchSheetState extends State<GifSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _gifs = [];
  bool _isLoading = false;
  final String _tenorApiKey = 'LIVDTRZGLBI2'; // Public Demo Key

  @override
  void initState() {
    super.initState();
    _fetchGifs(); // Load trending initially
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchGifs({String query = ''}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final String endpoint = query.isEmpty
          ? 'https://g.tenor.com/v1/trending?key=$_tenorApiKey&limit=21'
          : 'https://g.tenor.com/v1/search?q=${Uri.encodeComponent(query)}&key=$_tenorApiKey&limit=21';

      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null) {
          final List<String> loadedGifs = [];
          for (var result in results) {
            final media = result['media'] as List?;
            if (media != null && media.isNotEmpty) {
              final gifData = media[0]['gif'];
              if (gifData != null && gifData['url'] != null) {
                loadedGifs.add(gifData['url'] as String);
              }
            }
          }
          if (mounted) {
            setState(() {
              _gifs = loadedGifs;
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching gifs from Tenor: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65 + bottomInset,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomInset + 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF162435),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          // Search input
          TextField(
            controller: _searchController,
            onChanged: (val) {
              // Simple debounce or query search
              _fetchGifs(query: val.trim());
            },
            decoration: InputDecoration(
              hintText: 'Tìm kiếm GIF trên Tenor...',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.search, color: Colors.white30),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white30),
                      onPressed: () {
                        _searchController.clear();
                        _fetchGifs();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              fillColor: Colors.white.withOpacity(0.05),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),
          
          // Grid view of GIFs
          Expanded(
            child: _isLoading && _gifs.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _gifs.isEmpty
                    ? const Center(
                        child: Text(
                          'Không tìm thấy GIF nào',
                          style: TextStyle(color: Colors.white30),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _gifs.length,
                        itemBuilder: (context, index) {
                          final gifUrl = _gifs[index];
                          return GestureDetector(
                            onTap: () {
                              widget.onGifSelected(gifUrl);
                              Navigator.of(context).pop(); // Close Gif search sheet
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: gifUrl,
                                placeholder: (context, url) => Container(
                                  color: Colors.white.withOpacity(0.02),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white10),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
