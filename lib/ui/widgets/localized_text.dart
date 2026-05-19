import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/localization/localization_cubit.dart';

class LocalizedText extends StatelessWidget {
  final String translationKey;
  final TextStyle? style;
  final TextAlign? textAlign;

  const LocalizedText(
    this.translationKey, {
    super.key,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, state) {
        final text = state.translations[translationKey] ?? translationKey;
        return Text(
          text,
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}

// Helper function to translate a key
String tr(BuildContext context, String key) {
  return context.read<LocalizationCubit>().translate(key);
}

// Localized version of common widgets
class LocalizedListTile extends StatelessWidget {
  final IconData? leadingIcon;
  final String titleKey;
  final String? subtitleKey;
  final Widget? trailing;
  final VoidCallback? onTap;

  const LocalizedListTile({
    super.key,
    this.leadingIcon,
    required this.titleKey,
    this.subtitleKey,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leadingIcon != null
          ? Icon(leadingIcon, color: Theme.of(context).primaryColor)
          : null,
      title: LocalizedText(titleKey),
      subtitle: subtitleKey != null ? LocalizedText(subtitleKey!) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class LocalizedButton extends StatelessWidget {
  final String labelKey;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool isLoading;

  const LocalizedButton({
    super.key,
    required this.labelKey,
    this.onPressed,
    this.style,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : LocalizedText(labelKey),
    );
  }
}

class LocalizedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleKey;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const LocalizedAppBar({
    super.key,
    required this.titleKey,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      title: LocalizedText(
        titleKey,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: actions,
    );
  }
}