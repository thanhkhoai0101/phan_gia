class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final num balance;
  final String lastLogin;
  final String? avatarUrl;
  final String? coverUrl;
  final String? dateOfBirth;
  final bool isCookingModeEnabled;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.balance,
    required this.lastLogin,
    this.avatarUrl,
    this.coverUrl,
    this.dateOfBirth,
    this.isCookingModeEnabled = false,
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    num? balance,
    String? lastLogin,
    String? avatarUrl,
    String? coverUrl,
    String? dateOfBirth,
    bool? isCookingModeEnabled,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      balance: balance ?? this.balance,
      lastLogin: lastLogin ?? this.lastLogin,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      isCookingModeEnabled: isCookingModeEnabled ?? this.isCookingModeEnabled,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      balance: map['balance'] ?? 0,
      lastLogin: map['lastLogin'] ?? '',
      avatarUrl: map['avatarUrl'],
      coverUrl: map['coverUrl'],
      dateOfBirth: map['dateOfBirth'],
      isCookingModeEnabled: map['isCookingModeEnabled'] ?? false,
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
      'dateOfBirth': dateOfBirth,
      'isCookingModeEnabled': isCookingModeEnabled,
    };
  }
}
