class UserModel {
  final String? uid;
  final String? name;
  final String? college;
  final String? avatar;
  final String verificationStatus;
  final int notifications;
  final double trustScore;
  final int wallet;

  UserModel({
    this.uid,
    this.name,
    this.college,
    this.avatar,
    this.verificationStatus = 'unknown',
    this.notifications = 0,
    this.trustScore = 0,
    this.wallet = 0,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? college,
    String? avatar,
    String? verificationStatus,
    int? notifications,
    double? trustScore,
    int? wallet,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      college: college ?? this.college,
      avatar: avatar ?? this.avatar,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      notifications: notifications ?? this.notifications,
      trustScore: trustScore ?? this.trustScore,
      wallet: wallet ?? this.wallet,
    );
  }
}
