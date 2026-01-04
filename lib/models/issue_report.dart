class IssueReport {
  final String id;
  final String uid;
  final String email;
  final String message;
  final DateTime createdAt;

  IssueReport({
    required this.id,
    required this.uid,
    required this.email,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'email': email,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
      };

  factory IssueReport.fromJson(Map<String, dynamic> json) => IssueReport(
        id: json['id'] ?? '',
        uid: json['uid'] ?? '',
        email: json['email'] ?? '',
        message: json['message'] ?? '',
        createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      );
}
