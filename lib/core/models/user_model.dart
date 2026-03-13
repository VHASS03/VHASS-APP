/// User Model
class UserModel {
  final String id;
  final String phone;
  final String? name;
  final String? email;

  UserModel({
    required this.id,
    required this.phone,
    this.name,
    this.email,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'email': email,
    };
  }
}

