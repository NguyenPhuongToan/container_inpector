class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String role;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString().toLowerCase() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
    };
  }

  bool get canSubmitInspection => role == 'worker' || role == 'admin';

  bool get canReviewInspections => role == 'manager' || role == 'admin';
}
