import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// User avatar with photo + initials fallback. Replaces the inline
/// `CircleAvatar` patterns that lived in `admin_user_management_screen`
/// and the old `_WelcomeCard` in `admin_shell.dart`.
///
/// [photoUrl] is the Google/Firebase profile image (optional).
/// [fallbackName] is used to derive the 1-2 character initials shown
/// when the photo isn't available. Pass an empty string to render the
/// default person icon.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.photoUrl,
    this.fallbackName,
    this.radius = 24,
  });

  final String? photoUrl;
  final String? fallbackName;
  final double radius;

  /// Picks 1–2 characters from the start of [name], uppercased. Skips
  /// whitespace and short-circuits when the input is empty.
  static String initialsOf(String? name) {
    if (name == null) return '';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(fallbackName);
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.outline.withValues(alpha: 0.1),
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      child:
          hasPhoto
              ? null
              : initials.isNotEmpty
              ? Text(
                initials,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: radius * 0.7,
                ),
              )
              : Icon(
                PhosphorIconsRegular.user,
                color: Theme.of(context).colorScheme.onSurface,
                size: radius * 1.2,
              ),
    );
  }
}
