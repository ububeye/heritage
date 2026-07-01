import 'package:equatable/equatable.dart';

enum UserRole { free, premium, admin }

class UserModel extends Equatable {

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.role = UserRole.free,
    this.createdAt,
    this.subscriptionExpiry,
    this.disabled = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['display_name'],
      photoUrl: map['photo_url'],
      role: _parseRole(map['role']),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
      subscriptionExpiry: map['subscription_expiry'] != null
          ? DateTime.tryParse(map['subscription_expiry'])
          : null,
      disabled: map['disabled'] ?? false,
    );
  }
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? subscriptionExpiry;
  final bool disabled;

  bool get isPremium => role == UserRole.premium || role == UserRole.admin;
  bool get isAdmin => role == UserRole.admin;

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    UserRole? role,
    DateTime? createdAt,
    DateTime? subscriptionExpiry,
    bool? disabled,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      disabled: disabled ?? this.disabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'role': role.name,
      'created_at': createdAt?.toIso8601String(),
      'subscription_expiry': subscriptionExpiry?.toIso8601String(),
      'disabled': disabled,
    };
  }

  static UserRole _parseRole(String? role) {
    switch (role) {
      case 'premium':
        return UserRole.premium;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.free;
    }
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        photoUrl,
        role,
        createdAt,
        subscriptionExpiry,
      ];
}