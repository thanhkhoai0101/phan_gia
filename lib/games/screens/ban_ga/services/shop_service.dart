import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ShopService {
  static final ShopService _instance = ShopService._internal();
  factory ShopService() => _instance;
  ShopService._internal();

  int coins = 0;
  int maxHp = 3;
  double powerupDuration = 5.0; // Normal powerup duration
  int startingWeapon = 1; // 1 = normal, 2 = triple, etc
  int highScore = 0;

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    coins = prefs.getInt('ban_ga_coins') ?? 0;
    maxHp = prefs.getInt('ban_ga_max_hp') ?? 3;
    powerupDuration = prefs.getDouble('ban_ga_powerup_duration') ?? 5.0;
    startingWeapon = prefs.getInt('ban_ga_starting_weapon') ?? 1;
    highScore = prefs.getInt('ban_ga_high_score') ?? 0;

    // Sync from Firestore if logged in
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          if (data.containsKey('banGaHighScore')) {
            highScore = data['banGaHighScore'];
            coins = data['banGaCoins'] ?? coins;
            maxHp = data['banGaMaxHp'] ?? maxHp;
            powerupDuration = (data['banGaPowerupDuration'] ?? powerupDuration).toDouble();
            startingWeapon = data['banGaStartingWeapon'] ?? startingWeapon;
          }
        }
      } catch (e) {
        debugPrint("Error loading from Firestore: $e");
      }
    }
  }

  Future<void> _syncToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'banGaCoins': coins,
          'banGaHighScore': highScore,
          'banGaMaxHp': maxHp,
          'banGaPowerupDuration': powerupDuration,
          'banGaStartingWeapon': startingWeapon,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error syncing to Firestore: $e");
      }
    }
  }

  Future<void> addCoins(int amount) async {
    coins += amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ban_ga_coins', coins);
    _syncToFirestore();
  }

  Future<void> saveHighScore(int score) async {
    if (score > highScore) {
      highScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ban_ga_high_score', highScore);
      _syncToFirestore();
    }
  }

  Future<bool> buyMaxHp() async {
    int cost = 100 * (maxHp - 2);
    if (coins >= cost) {
      coins -= cost;
      maxHp++;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ban_ga_coins', coins);
      await prefs.setInt('ban_ga_max_hp', maxHp);
      _syncToFirestore();
      return true;
    }
    return false;
  }

  Future<bool> buyPowerupDuration() async {
    int cost = 150;
    if (coins >= cost) {
      coins -= cost;
      powerupDuration += 2.0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ban_ga_coins', coins);
      await prefs.setDouble('ban_ga_powerup_duration', powerupDuration);
      _syncToFirestore();
      return true;
    }
    return false;
  }

  Future<bool> buyStartingWeapon(int type, int cost) async {
    if (coins >= cost) {
      coins -= cost;
      startingWeapon = type;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ban_ga_coins', coins);
      await prefs.setInt('ban_ga_starting_weapon', startingWeapon);
      _syncToFirestore();
      return true;
    }
    return false;
  }
}
