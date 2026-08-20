import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single activity event logged to Firestore, used primarily
/// for the admin dashboard's Recent Activities feed.
class ActivityModel {
  ActivityModel({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.userId,
  });

  factory ActivityModel.fromMap(Map<String, dynamic> map, String id) {
    return ActivityModel(
      id: id,
      type: map['type'] as String? ?? 'unknown',
      title: map['title'] as String? ?? 'Unknown Activity',
      subtitle: map['subtitle'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: map['userId'] as String?,
    );
  }

  /// Firestore document ID
  final String id;

  /// The type of activity (e.g., 'user_registered', 'site_updated', 'premium_upgrade')
  final String type;

  /// Human-readable title
  final String title;

  /// Contextual subtitle (e.g. 'Admin updated "Forodhani Gardens" details.')
  final String subtitle;

  /// When the activity occurred
  final DateTime timestamp;

  /// Optional ID of the user who performed or triggered the activity
  final String? userId;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'timestamp': Timestamp.fromDate(timestamp),
      if (userId != null) 'userId': userId,
    };
  }

  ActivityModel copyWith({
    String? id,
    String? type,
    String? title,
    String? subtitle,
    DateTime? timestamp,
    String? userId,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }
}
