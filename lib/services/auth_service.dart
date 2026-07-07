import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<UserModel?> authStateChanges() {
    return _auth.authStateChanges().asyncExpand((User? user) async* {
      if (user == null) {
        yield null;
      } else {
        yield* _firestore.collection('users').doc(user.uid).snapshots().asyncMap((doc) async {
          if (!doc.exists) return null;
          
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String lastLogin = data['lastLogin'] ?? '';
          String today = _getTodayString();
          
          int currentBalance = data['balance'] ?? 0;

          // Process daily login if it's a new day
          if (lastLogin != today) {
            currentBalance += 50000;
            // Update silently in background
            _firestore.collection('users').doc(user.uid).update({
              'balance': currentBalance,
              'lastLogin': today,
            });
          }

          return UserModel(
            uid: user.uid,
            email: data['email'] ?? '',
            displayName: data['displayName'] ?? '',
            balance: currentBalance,
            lastLogin: today,
            avatarUrl: data['avatarUrl'],
            coverUrl: data['coverUrl'],
          );
        });
      }
    });
  }

  String _getTodayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<String?> register(String email, String password, String displayName, {String? avatarUrl, String? dateOfBirth}) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      String today = _getTodayString();
      UserModel newUser = UserModel(
        uid: cred.user!.uid,
        email: email,
        displayName: displayName,
        balance: 200000, 
        lastLogin: today,
        avatarUrl: avatarUrl,
        dateOfBirth: dateOfBirth,
      );

      await _firestore.collection('users').doc(cred.user!.uid).set(newUser.toMap());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String?> updateProfile({String? displayName, String? avatarUrl, String? coverUrl}) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return "User not logged in";

      Map<String, dynamic> updateData = {};
      if (displayName != null) updateData['displayName'] = displayName;
      if (avatarUrl != null) updateData['avatarUrl'] = avatarUrl;
      if (coverUrl != null) updateData['coverUrl'] = coverUrl;

      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updateData);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
