import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import 'settings_tile.dart';

/// Segmented control inside a settings row. Used for short, fixed-choice
/// settings (theme, map provider, distance units) where picking from a
/// `DropdownButton` would be over-engineered.
///
/// Layout: a leading icon + a [SegmentedButton] that expands to fill
/// the rest of the row. The label above the row comes from the parent
/// [SettingsSectionTitle] — keeping a per-row title inside the same
/// `Row` as the segmented control overflowed on 360dp-wide screens
/// (icon 32 + gap 16 + 3-option button ≈ 320px left nothing for the
/// label). Putting both in the same row also produced an empty label
/// column when `SegmentedButton`'s intrinsic width exceeded the
/// available space.
class SettingsSegmentedTile<T extends Object> extends StatelessWidget {

  const SettingsSegmentedTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.options,
    this.values,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;

  /// Display labels in display order. The index of the selected label
  /// must equal the index of the matching value in [values].
  final List<String> options;

  /// Optional parallel list of values when labels aren't enough (e.g.
  /// 'en' / 'sw'). Defaults to [options] when omitted.
  final List<T>? values;

  final T value;
  final ValueChanged<T> onChanged;

  List<T> get _values => values ?? options.cast<T>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      child: Row(
        children: [
          SettingsTileIcon(icon: icon, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              style: ButtonStyle(
                textStyle: WidgetStatePropertyAll(
                  Theme.of(context).textTheme.labelMedium,
                ),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                for (var i = 0; i < options.length; i++)
                  ButtonSegment<T>(
                    value: _values[i],
                    label: Text(options[i]),
                  ),
              ],
              selected: {value},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onChanged(selection.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}