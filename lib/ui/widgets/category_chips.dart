import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final Function(String?) onSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final allCategories = ['All', ...categories];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = allCategories[index];
          final isSelected = (category == 'All' && selectedCategory == null) ||
              category == selectedCategory;

          return GestureDetector(
            onTap: () => onSelected(category == 'All' ? null : category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}