class User {
  final int id;
  final String username;
  final String name;
  final String email;

  User({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'], 
      name: json['name'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
    };
  }

  User copyWith({
    String? name,
    String? email,
  }) {
    return User(
      id: this.id,
      username: this.username,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }
}