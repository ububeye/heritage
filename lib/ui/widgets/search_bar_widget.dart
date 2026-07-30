import 'package:flutter/material.dart';
import '../../core/utils/debouncer.dart';
import '../../core/theme/app_radius.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// A debounced search input with a prefix search icon and a suffix clear
/// button. The clear button is rendered conditionally based on the
/// controller's current text via [ValueListenableBuilder] so it updates
/// immediately when the user types — previously the button only updated
/// when something else rebuilt the parent.
class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search places...',
  });
  final TextEditingController controller;
  final Function(String) onChanged;
  final String hintText;

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final Debouncer _debouncer = Debouncer();

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    _debouncer(() => widget.onChanged(value));
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, child) {
          final hasText = value.text.isNotEmpty;
          return TextField(
            controller: widget.controller,
            onChanged: _handleChanged,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              prefixIcon: Icon(
                PhosphorIconsRegular.magnifyingGlass,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              suffixIcon:
                  hasText
                      ? Semantics(
                        label: 'Clear search',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            Icons.clear,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          onPressed: _clear,
                        ),
                      )
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          );
        },
      ),
    );
  }
}
