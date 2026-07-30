import '../../../core/theme/app_spacing.dart';
import 'dart:io';
import '../../../core/theme/app_radius.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../blocs/localization/localization_cubit.dart';
import '../../../data/models/site_model.dart';
import '../../../data/services/firestore_service.dart';
import '../../../data/services/cloudinary_service.dart';
import '../../widgets/heritage_map.dart';

class AdminEditSiteScreen extends StatefulWidget {
  const AdminEditSiteScreen({super.key, required this.site});
  final SiteModel site;

  @override
  State<AdminEditSiteScreen> createState() => _AdminEditSiteScreenState();
}

class _AdminEditSiteScreenState extends State<AdminEditSiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _cloudinaryService = CloudinaryService();

  // Controllers for the 7-language name + description fields.
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameSwController;
  late final TextEditingController _nameFrController;
  late final TextEditingController _nameDeController;
  late final TextEditingController _nameArController;
  late final TextEditingController _nameItController;
  late final TextEditingController _nameEsController;
  late final TextEditingController _descEnController;
  late final TextEditingController _descSwController;
  late final TextEditingController _descFrController;
  late final TextEditingController _descDeController;
  late final TextEditingController _descArController;
  late final TextEditingController _descItController;
  late final TextEditingController _descEsController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _radiusController;
  late final TextEditingController _addressController;

  late String _selectedCategory;
  bool _isLoading = false;

  // Multi-image support. `_existingImages` mirrors `widget.site.imageUrls`
  // (and falls back to the legacy `cloudinaryImageUrl`); `_selectedImages`
  // are locally-picked files that will be uploaded on save.
  late List<String> _existingImages;
  final List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _nameEnController = TextEditingController(text: widget.site.nameEn);
    _nameSwController = TextEditingController(text: widget.site.nameSw);
    _nameFrController = TextEditingController(text: widget.site.nameFr);
    _nameDeController = TextEditingController(text: widget.site.nameDe);
    _nameArController = TextEditingController(text: widget.site.nameAr);
    _nameItController = TextEditingController(text: widget.site.nameIt);
    _nameEsController = TextEditingController(text: widget.site.nameEs);
    _descEnController = TextEditingController(text: widget.site.descriptionEn);
    _descSwController = TextEditingController(text: widget.site.descriptionSw);
    _descFrController = TextEditingController(text: widget.site.descriptionFr);
    _descDeController = TextEditingController(text: widget.site.descriptionDe);
    _descArController = TextEditingController(text: widget.site.descriptionAr);
    _descItController = TextEditingController(text: widget.site.descriptionIt);
    _descEsController = TextEditingController(text: widget.site.descriptionEs);
    _latController = TextEditingController(
      text: widget.site.latitude.toString(),
    );
    _lngController = TextEditingController(
      text: widget.site.longitude.toString(),
    );
    _radiusController = TextEditingController(
      text: widget.site.entryRadiusM.toString(),
    );
    _addressController = TextEditingController(text: widget.site.address ?? '');
    _selectedCategory = widget.site.category ?? 'historic';

    // Prefer the modern `imageUrls` list; fall back to the legacy single
    // image URL for sites that haven't been migrated yet.
    _existingImages =
        widget.site.imageUrls.isNotEmpty
            ? List.of(widget.site.imageUrls)
            : (widget.site.cloudinaryImageUrl.isNotEmpty
                ? [widget.site.cloudinaryImageUrl]
                : <String>[]);
  }

  @override
  void dispose() {
    for (final c in [
      _nameEnController,
      _nameSwController,
      _nameFrController,
      _nameDeController,
      _nameArController,
      _nameItController,
      _nameEsController,
      _descEnController,
      _descSwController,
      _descFrController,
      _descDeController,
      _descArController,
      _descItController,
      _descEsController,
      _latController,
      _lngController,
      _radiusController,
      _addressController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _cloudinaryService.pickMultipleImages();
    if (images.isNotEmpty) {
      setState(() => _selectedImages.addAll(images));
    }
  }

  void _removeExisting(int index) {
    setState(() => _existingImages.removeAt(index));
  }

  void _removeSelected(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _updateSite() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingImages.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please keep at least one image'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload only the locally-picked files; existing Cloudinary URLs are
      // already in `imageUrls` shape and just need to be re-saved.
      final uploaded =
          _selectedImages.isEmpty
              ? <String>[]
              : await _cloudinaryService.uploadImages(_selectedImages);
      final allImages = <String>[..._existingImages, ...uploaded];

      final site = widget.site.copyWith(
        nameEn: _nameEnController.text,
        nameSw: _nameSwController.text,
        nameFr: _nameFrController.text,
        nameDe: _nameDeController.text,
        nameAr: _nameArController.text,
        nameIt: _nameItController.text,
        nameEs: _nameEsController.text,
        descriptionEn: _descEnController.text,
        descriptionSw: _descSwController.text,
        descriptionFr: _descFrController.text,
        descriptionDe: _descDeController.text,
        descriptionAr: _descArController.text,
        descriptionIt: _descItController.text,
        descriptionEs: _descEsController.text,
        cloudinaryImageUrl: allImages.isNotEmpty ? allImages.first : '',
        imageUrls: allImages,
        latitude: double.parse(_latController.text),
        longitude: double.parse(_lngController.text),
        entryRadiusM: double.parse(_radiusController.text),
        address:
            _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
        category: _selectedCategory,
      );

      await _firestoreService.updateSite(widget.site.id, site);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Site updated successfully'),
            backgroundColor: context.semanticColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing Cloudinary images — read-only chips with a remove badge.
        if (_existingImages.isNotEmpty) ...[
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _existingImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.bannerBorder,
                        child: CachedNetworkImage(
                          imageUrl: _existingImages[index],
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          placeholder:
                              (_, __) => Container(
                                width: 110,
                                height: 110,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                              ),
                          errorWidget:
                              (_, __, ___) => Container(
                                width: 110,
                                height: 110,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                                child: Icon(
                                  Icons.broken_image,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeExisting(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Theme.of(context).colorScheme.onError,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: AppInsets.badgePadding,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: AppRadius.xsBorder,
                            ),
                            child: Text(
                              'Cover',
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Newly picked images — show local File previews.
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.bannerBorder,
                        child: Image.file(
                          File(_selectedImages[index].path),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeSelected(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Theme.of(context).colorScheme.onError,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: AppInsets.badgePadding,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: AppRadius.xsBorder,
                          ),
                          child: Text(
                            'New',
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        InkWell(
          onTap: _pickImages,
          borderRadius: AppRadius.mdBorder,
          child: Container(
            padding: AppInsets.card,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: AppRadius.mdBorder,
              border: Border.all(color: Theme.of(context).colorScheme.primary),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add More Photos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Touch the localization cubit so any language change re-renders the
    // tooltips (e.g. delete-user label).
    final _ = context.watch<LocalizationCubit>().state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Edit Site'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppInsets.card,
          children: [
            const _SectionTitle(title: 'Photos'),
            _buildPhotoSection(),
            const SizedBox(height: 24),
            const _SectionTitle(title: 'Basic Info'),
            _TextField(
              controller: _nameEnController,
              label: 'Name (English)',
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            _TextField(
              controller: _nameSwController,
              label: 'Name (Swahili)',
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            _TextField(controller: _nameFrController, label: 'Name (French)'),
            _TextField(controller: _nameDeController, label: 'Name (German)'),
            _TextField(controller: _nameArController, label: 'Name (Arabic)'),
            _TextField(controller: _nameItController, label: 'Name (Italian)'),
            _TextField(controller: _nameEsController, label: 'Name (Spanish)'),
            const SizedBox(height: 16),
            _DropdownField(
              label: 'Category',
              value: _selectedCategory,
              items: SiteCategories.all,
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 24),
            const _SectionTitle(title: 'Descriptions'),
            _TextField(
              controller: _descEnController,
              label: 'Description (English)',
              maxLines: 3,
            ),
            _TextField(
              controller: _descSwController,
              label: 'Description (Swahili)',
              maxLines: 3,
            ),
            _TextField(
              controller: _descFrController,
              label: 'Description (French)',
              maxLines: 3,
            ),
            _TextField(
              controller: _descDeController,
              label: 'Description (German)',
              maxLines: 3,
            ),
            _TextField(
              controller: _descArController,
              label: 'Description (Arabic)',
              maxLines: 3,
            ),
            _TextField(
              controller: _descItController,
              label: 'Description (Italian)',
              maxLines: 3,
            ),
            _TextField(
              controller: _descEsController,
              label: 'Description (Spanish)',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const _SectionTitle(title: 'Location'),
            Container(
              height: 400,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdBorder,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: HeritageMap.picker(
                initialLat: widget.site.latitude,
                initialLng: widget.site.longitude,
                onLocationPicked: (pickedLat, pickedLng) {
                  // setState keeps the lat/lng fields in sync visually
                  // with the map marker.
                  setState(() {
                    _latController.text = pickedLat.toStringAsFixed(6);
                    _lngController.text = pickedLng.toStringAsFixed(6);
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TextField(
                    controller: _latController,
                    label: 'Latitude',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TextField(
                    controller: _lngController,
                    label: 'Longitude',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            _TextField(
              controller: _radiusController,
              label: 'Entry Radius (meters)',
              keyboardType: TextInputType.number,
            ),
            _TextField(
              controller: _addressController,
              label: 'Display address (optional)',
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: AppSpacing.xxl,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateSite,
                child:
                    _isLoading
                        ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text('Update Site'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<String> items;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items:
            items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
