import 'package:flutter/material.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel _user = UserModel();

  UserModel get user => _user;

  // Convenience getters for direct access to user properties
  String? get uid => _user.uid;
  String? get avatar => _user.avatar;
  String get verificationStatus => _user.verificationStatus;

  void updateFromSummary(Map<String, dynamic> summary) {
    _user = _user.copyWith(
      name: summary['name'] ?? '',
      college: summary['college'] ?? '',
      avatar: summary['avatar'] ?? '',
      notifications: summary['notifications'] ?? 0,
      trustScore: (summary['trustScore'] ?? 0).toDouble(),
      wallet: summary['wallet'] ?? 0,
      verificationStatus: summary['verificationStatus'] ?? 'unknown',
    );
    notifyListeners();
  }

  void setUid(String? newUid) {
    _user = _user.copyWith(uid: newUid);
    notifyListeners();
  }

  void setVerificationStatus(String status) {
    _user = _user.copyWith(verificationStatus: status);
    notifyListeners();
  }

  void setAvatar(String? newAvatar) {
    _user = _user.copyWith(avatar: newAvatar);
    notifyListeners();
  }

  void setName(String? newName) {
    _user = _user.copyWith(name: newName);
    notifyListeners();
  }

  void setProfile({
    String? newName,
    String? newCollege,
    String? newAvatar,
  }) {
    _user = _user.copyWith(
      name: newName,
      college: newCollege,
      avatar: newAvatar,
    );
    notifyListeners();
  }
}
