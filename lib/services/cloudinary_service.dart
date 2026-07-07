import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:phan_family/config/cloudinary_config.dart';

/// Dịch vụ Cloudinary: upload và xoá ảnh.
///
/// ⚠️  Điền API Key và API Secret vào đây.
///     Với ứng dụng gia đình nội bộ thì chấp nhận được,
///     nhưng nếu public thì nên dùng backend/Cloud Function để bảo vệ secret.
class CloudinaryService {
  static const String _cloudName  = CloudinaryConfig.cloudName;
  static const String _uploadPreset = CloudinaryConfig.uploadPreset;
  static const String _apiKey    = CloudinaryConfig.apiKey;
  static const String _apiSecret  = CloudinaryConfig.apiSecret;

  // ── Upload ──────────────────────────────────────────────────────────
  /// Trả về [secure_url] nếu thành công, null nếu thất bại.
  Future<String?> uploadImage(File file) async {
    try {
      final url = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = json.decode(await response.stream.bytesToString());
        return data['secure_url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // ── Delete ───────────────────────────────────────────────────────────
  /// Xoá ảnh trên Cloudinary bằng URL cũ.
  /// Tự động trích xuất [public_id] từ URL rồi gọi Destroy API.
  Future<bool> deleteByUrl(String imageUrl) async {
    final publicId = _extractPublicId(imageUrl);
    if (publicId == null) return false;
    return _destroy(publicId);
  }

  /// Trích xuất public_id từ Cloudinary URL.
  /// Ví dụ: https://res.cloudinary.com/dogxxj74b/image/upload/v1234567890/folder/abc.jpg
  ///        → public_id = "folder/abc"
  String? _extractPublicId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      // pathSegments = ['dogxxj74b','image','upload','v1234567890','folder','abc.jpg']
      final uploadIdx = segments.indexOf('upload');
      if (uploadIdx == -1) return null;

      // Bỏ phần 'v{version}' nếu có, rồi ghép phần còn lại
      var parts = segments.sublist(uploadIdx + 1);
      if (parts.isNotEmpty && RegExp(r'^v\d+$').hasMatch(parts.first)) {
        parts = parts.sublist(1);
      }

      if (parts.isEmpty) return null;

      // Bỏ đuôi file (.jpg, .png, ...)
      final last = parts.last;
      final dotIdx = last.lastIndexOf('.');
      final lastWithoutExt = dotIdx != -1 ? last.substring(0, dotIdx) : last;
      final publicId = [...parts.sublist(0, parts.length - 1), lastWithoutExt].join('/');

      return publicId.isEmpty ? null : publicId;
    } catch (_) {
      return null;
    }
  }

  /// Gọi Cloudinary Destroy API (yêu cầu signature).
  Future<bool> _destroy(String publicId) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

      // Tạo chữ ký: SHA-1(public_id=...&timestamp=...<api_secret>)
      final toSign  = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';
      final signature = sha1.convert(utf8.encode(toSign)).toString();

      final url  = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/destroy');
      final response = await http.post(url, body: {
        'public_id': publicId,
        'timestamp': timestamp,
        'api_key':   _apiKey,
        'signature': signature,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'] == 'ok';
      }
    } catch (_) {}
    return false;
  }
}
