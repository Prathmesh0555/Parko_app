class User {
  final int id;
  final String username;
  final String name;
  final String email;
  final String? phone;
  final String joinDate;

  User({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    this.phone,
    this.joinDate = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'], 
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      joinDate: json['join_date'] ?? json['joinDate'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
      'phone': phone,
      'join_date': joinDate,
    };
  }

  User copyWith({
    String? name,
    String? email,
    String? phone,
  }) {
    return User(
      id: this.id,
      username: this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      joinDate: this.joinDate,
    );
  }
}