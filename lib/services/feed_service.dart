import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/post_model.dart';
import '../models/comment_model.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final String _collectionPath = 'posts';

  // Lấy danh sách bài viết theo thời gian mới nhất
  Stream<List<PostModel>> getPosts() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    });
  }

  // Upload ảnh/video lên Cloudinary
  Future<String?> uploadMedia(File file, String userId) async {
    try {
      // Nhận biết loại file
      final isVideo = file.path.toLowerCase().endsWith('.mp4') || 
                      file.path.toLowerCase().endsWith('.mov') ||
                      file.path.toLowerCase().endsWith('.avi');
      final resourceType = isVideo ? 'video' : 'image';
      
      // TODO: ĐIỀN THÔNG TIN CLOUDINARY CỦA BẠN VÀO ĐÂY
      final String cloudName = 'dogxxj74b';
      final String uploadPreset = 'ml_default';
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');
      
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
        
      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonMap = jsonDecode(responseString);
      
      if (response.statusCode == 200) {
        return jsonMap['secure_url']; // Trả về link ảnh/video từ Cloudinary
      } else {
        print('Cloudinary upload error: ${jsonMap['error']['message']}');
        return null;
      }
    } catch (e) {
      print('Error uploading media to Cloudinary: $e');
      return null;
    }
  }

  // Tạo bài đăng mới
  Future<void> createPost(PostModel post) async {
    try {
      await _firestore.collection(_collectionPath).add(post.toFirestore());
    } catch (e) {
      print('Error creating post: $e');
      throw Exception('Could not create post');
    }
  }

  // Thêm/Cập nhật/Xoá biểu cảm
  Future<void> toggleReaction(String postId, String userId, String? reactionType) async {
    try {
      final docRef = _firestore.collection(_collectionPath).doc(postId);

      if (reactionType == null) {
        // Huỷ biểu cảm
        await docRef.update({'reactions.$userId': FieldValue.delete()});
      } else {
        // Thêm hoặc cập nhật biểu cảm
        await docRef.update({'reactions.$userId': reactionType});
      }
    } catch (e) {
      print('Error toggling reaction: $e');
    }
  }

  // Xoá bài đăng
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection(_collectionPath).doc(postId).delete();
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  // --- COMMENTS ---

// Lấy danh sách bình luận
  Stream<List<CommentModel>> getComments(String postId) {
    return _firestore
        .collection(_collectionPath) // Thường là 'posts'
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        // SỬA Ở ĐÂY: Truyền data và id riêng biệt vào model
        return CommentModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  // Thêm bình luận
  Future<void> addComment(String postId, CommentModel comment) async {
    try {
      final docRef = _firestore.collection(_collectionPath).doc(postId);
      
      await _firestore.runTransaction((transaction) async {
        // Tăng commentCount
        transaction.update(docRef, {'commentCount': FieldValue.increment(1)});
        
        // Thêm comment vào subcollection
        final commentRef = docRef.collection('comments').doc();
        transaction.set(commentRef, comment.toFirestore());
      });
    } catch (e) {
      print('Error adding comment: $e');
      throw Exception('Could not add comment');
    }
  }


  Future<void> reactComment({required String postId, required String commentId, required String userId, String? reactionType}) async {
    final docRef = _firestore.collection('posts').doc(postId).collection('comments').doc(commentId);
    if (reactionType == null) {
      await docRef.update({'reactions.$userId': FieldValue.delete()}); // Hủy cảm xúc
    } else {
      await docRef.update({'reactions.$userId': reactionType}); // Thêm/Đổi cảm xúc
    }
  }
}

