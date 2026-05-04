class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final int balance;
  final String lastLogin;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.balance,
    required this.lastLogin,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      balance: map['balance'] ?? 0,
      lastLogin: map['lastLogin'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'balance': balance,
      'lastLogin': lastLogin,
    };
  }
}
