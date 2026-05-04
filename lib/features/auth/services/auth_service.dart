import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../core/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<UserModel?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user == null) return null;
      return await _fetchAndCheckDailyLogin(user.uid);
    });
  }

  String _getTodayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<UserModel?> _fetchAndCheckDailyLogin(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String lastLogin = data['lastLogin'] ?? '';
        String today = _getTodayString();
        
        int currentBalance = data['balance'] ?? 0;

        if (lastLogin != today) {
          currentBalance += 50000;
          await _firestore.collection('users').doc(uid).update({
            'balance': currentBalance,
            'lastLogin': today,
          });
        }

        return UserModel(
          uid: uid,
          email: data['email'] ?? '',
          displayName: data['displayName'] ?? '',
          balance: currentBalance,
          lastLogin: today,
        );
      }
    } catch (e) {
      print("Error fetching user: $e");
    }
    return null;
  }

  Future<String?> register(String email, String password, String displayName) async {
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
}
