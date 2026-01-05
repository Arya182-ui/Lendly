import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String? uid;
  String? name;
  String? college;
  String? avatar;
  String verificationStatus = 'unknown';
  int notifications = 0;
  double trustScore = 0;
  int wallet = 0;

  void updateFromSummary(Map<String, dynamic> summary) {
    name = summary['name'] ?? '';
    college = summary['college'] ?? '';
    avatar = summary['avatar'] ?? '';
    notifications = summary['notifications'] ?? 0;
    trustScore = (summary['trustScore'] ?? 0).toDouble();
    wallet = summary['wallet'] ?? 0;
    verificationStatus = summary['verificationStatus'] ?? 'unknown';
    notifyListeners();
  }

  void setUid(String? newUid) {
    uid = newUid;
    notifyListeners();
  }

  void setVerificationStatus(String status) {
    verificationStatus = status;
    notifyListeners();
  }

  void setAvatar(String? newAvatar) {
    avatar = newAvatar;
    notifyListeners();
  }

  void setName(String? newName) {
    name = newName;
    notifyListeners();
  }

  void setProfile({
    String? newName,
    String? newCollege,
    String? newAvatar,
  }) {
    if (newName != null) name = newName;
    if (newCollege != null) college = newCollege;
    if (newAvatar != null) avatar = newAvatar;
    notifyListeners();
  }
}
