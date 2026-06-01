import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class BackgroundThemeOption {
  final String id;
  final String name;
  final Color color;

  BackgroundThemeOption({
    required this.id,
    required this.name,
    required this.color,
  });
}

class BackgroundSelectorSheet extends StatelessWidget {
  final String? currentBackground;
  final Function(String?) onPresetSelected;
  final Function(File) onImageSelected;

  BackgroundSelectorSheet({
    Key? key,
    required this.currentBackground,
    required this.onPresetSelected,
    required this.onImageSelected,
  }) : super(key: key);

  final List<BackgroundThemeOption> options = [
    BackgroundThemeOption(id: 'default', name: 'Mặc định', color: const Color(0xFF162435)), // Default app bg
    BackgroundThemeOption(id: 'color_pink', name: 'Hồng nhạt', color: Colors.pink.shade50),
    BackgroundThemeOption(id: 'color_blue', name: 'Xanh lơ', color: Colors.blue.shade50),
    BackgroundThemeOption(id: 'color_green', name: 'Xanh nhạt', color: Colors.green.shade50),
    BackgroundThemeOption(id: 'color_yellow', name: 'Vàng nhạt', color: Colors.yellow.shade50),
    BackgroundThemeOption(id: 'color_purple', name: 'Tím nhạt', color: Colors.purple.shade50),
  ];

  Future<void> _pickImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        onImageSelected(File(image.path));
        Navigator.pop(context);
      }
    } catch (e) {
      print('Lỗi chọn ảnh: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF162435),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
              ),
              const Text(
                'Đổi hình nền',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 50), // Balance the title
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _pickImage(context),
            icon: const Icon(Icons.image),
            label: const Text('Chọn ảnh từ thiết bị'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('Hoặc chọn màu nền', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 250,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = currentBackground == option.id || (currentBackground == null && option.id == 'default');

                return GestureDetector(
                  onTap: () {
                    onPresetSelected(option.id == 'default' ? null : option.id);
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: option.color,
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected ? Border.all(color: Colors.blueAccent, width: 3) : null,
                        ),
                        child: isSelected 
                            ? const Center(child: Icon(Icons.check, color: Colors.blueAccent))
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option.name,
                        style: TextStyle(
                          color: isSelected ? Colors.blueAccent : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
