class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final num balance;
  final String lastLogin;
  final String? avatarUrl;
  final String? coverUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.balance,
    required this.lastLogin,
    this.avatarUrl,
    this.coverUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      balance: map['balance'] ?? 0,
      lastLogin: map['lastLogin'] ?? '',
      avatarUrl: map['avatarUrl'],
      coverUrl: map['coverUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'balance': balance,
      'lastLogin': lastLogin,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
    };
  }
}
