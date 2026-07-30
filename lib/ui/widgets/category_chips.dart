import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../blocs/localization/localization_cubit.dart';

class CategoryChips extends StatelessWidget {

  const CategoryChips({
    super.key,
    required this.categories,
    this.selectedCategory,
    required this.onSelected,
    this.locState,
  });
  final List<String> categories;
  final String? selectedCategory;
  final Function(String?) onSelected;
  final LocalizationState? locState;

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, state) {
        final locState = this.locState ?? state;
        final allCategories = ['all', ...categories];

        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = allCategories[index];
              final isSelected = (category == 'all' && selectedCategory == null) ||
                  category == selectedCategory;

              return GestureDetector(
                onTap: () => onSelected(category == 'all' ? null : category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Text(
                    _tr(locState, category),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
                        ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
