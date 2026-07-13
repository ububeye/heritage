import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../blocs/localization/localization_cubit.dart';
import '../../../data/models/site_model.dart';
import '../../../data/services/firestore_service.dart';
import '../../../data/services/cloudinary_service.dart';
import '../../../blocs/site_list/site_list_cubit.dart';
import '../../widgets/heritage_map.dart';

class AdminAddSiteScreen extends StatefulWidget {
  const AdminAddSiteScreen({super.key});

  @override
  State<AdminAddSiteScreen> createState() => _AdminAddSiteScreenState();
}

class _AdminAddSiteScreenState extends State<AdminAddSiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _cloudinaryService = CloudinaryService();

  // Controllers — names (7)
  final _nameEnController = TextEditingController();
  final _nameSwController = TextEditingController();
  final _nameFrController = TextEditingController();
  final _nameDeController = TextEditingController();
  final _nameArController = TextEditingController();
  final _nameItController = TextEditingController();
  final _nameEsController = TextEditingController();

  // Controllers — descriptions (7)
  final _descEnController = TextEditingController();
  final _descSwController = TextEditingController();
  final _descFrController = TextEditingController();
  final _descDeController = TextEditingController();
  final _descArController = TextEditingController();
  final _descItController = TextEditingController();
  final _descEsController = TextEditingController();

  // Location controllers
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _addressController = TextEditingController();

  // Form state
  String _selectedCategory = 'historic';
  double _entryRadius = 50.0;
  int _locationTabIndex = 1; // 0 = Map, 1 = Manual

  // Images
  final List<XFile> _selectedImages = [];
  bool _isUploading = false;

  // Loading state
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in [
      _nameEnController, _nameSwController, _nameFrController,
      _nameDeController, _nameArController, _nameItController, _nameEsController,
      _descEnController, _descSwController, _descFrController,
      _descDeController, _descArController, _descItController, _descEsController,
      _latController, _lngController, _addressController,
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

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _saveSite() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one image'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      setState(() => _isUploading = true);
      final uploadedUrls = await _cloudinaryService.uploadImages(_selectedImages);
      if (uploadedUrls.isEmpty) {
        throw Exception('Failed to upload images');
      }

      final site = SiteModel(
        id: '',
        nameEn: _nameEnController.text.trim(),
        nameSw: _nameSwController.text.trim(),
        descriptionEn: _descEnController.text.trim(),
        descriptionSw: _descSwController.text.trim(),
        descriptionFr: _descFrController.text.trim(),
        descriptionDe: _descDeController.text.trim(),
        descriptionAr: _descArController.text.trim(),
        descriptionIt: _descItController.text.trim(),
        descriptionEs: _descEsController.text.trim(),
        cloudinaryImageUrl: uploadedUrls.first,
        imageUrls: uploadedUrls,
        latitude: double.parse(_latController.text),
        longitude: double.parse(_lngController.text),
        entryRadiusM: _entryRadius,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        category: _selectedCategory,
        createdAt: DateTime.now(),
      );

      await _firestoreService.addSite(site);

      if (mounted) {
        context.read<SiteListCubit>().loadSites();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site added successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Add Site'),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(
                    _isUploading ? 'Uploading images...' : 'Saving site...',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('Photos (Required - Min 1)'),
                  _buildPhotoSection(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Category'),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Location'),
                  _buildLocationSection(),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Entry Radius: ${_entryRadius.round()}m'),
                  _buildRadiusSlider(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Translations (all 7 languages required)'),
                  const SizedBox(height: 4),
                  const Text(
                    'Fill in the site name and description for every language. The user\'s chosen audio language will be read aloud.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _buildLanguageSection(
                    code: 'en',
                    flag: '🇬🇧',
                    name: 'English',
                    nameController: _nameEnController,
                    descController: _descEnController,
                  ),
                  _buildLanguageSection(
                    code: 'sw',
                    flag: '🇹🇿',
                    name: 'Swahili',
                    nameController: _nameSwController,
                    descController: _descSwController,
                  ),
                  _buildLanguageSection(
                    code: 'fr',
                    flag: '🇫🇷',
                    name: 'French',
                    nameController: _nameFrController,
                    descController: _descFrController,
                  ),
                  _buildLanguageSection(
                    code: 'de',
                    flag: '🇩🇪',
                    name: 'German',
                    nameController: _nameDeController,
                    descController: _descDeController,
                  ),
                  _buildLanguageSection(
                    code: 'ar',
                    flag: '🇸🇦',
                    name: 'Arabic',
                    nameController: _nameArController,
                    descController: _descArController,
                  ),
                  _buildLanguageSection(
                    code: 'it',
                    flag: '🇮🇹',
                    name: 'Italian',
                    nameController: _nameItController,
                    descController: _descItController,
                  ),
                  _buildLanguageSection(
                    code: 'es',
                    flag: '🇪🇸',
                    name: 'Spanish',
                    nameController: _nameEsController,
                    descController: _descEsController,
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveSite,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Site',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          items: SiteCategories.all.map((cat) {
            return DropdownMenuItem(
              value: cat,
              child: Text(SiteCategories.getLabel(cat)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCategory = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_selectedImages[index].path),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10)),
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(Icons.add_photo_alternate, size: 40, color: AppColors.primary),
                const SizedBox(height: 8),
                const Text('Add from Gallery', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Select multiple photos', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTabButton('Manual', Icons.edit_location, 1),
              ),
              Expanded(
                child: _buildTabButton('Map', Icons.map, 0),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTextField(
                  controller: _addressController,
                  label: 'Display address (optional)',
                ),
                const SizedBox(height: 12),
                _locationTabIndex == 0
                    ? _buildMapLocation()
                    : _buildManualLocation(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isSelected = _locationTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _locationTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLocation() {
    final lat = double.tryParse(_latController.text) ?? -6.1621;
    final lng = double.tryParse(_lngController.text) ?? 39.1835;

    return Column(
      children: [
        Container(
          height: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: HeritageMap.picker(
            initialLat: lat,
            initialLng: lng,
            onLocationPicked: (pickedLat, pickedLng) {
              // setState so the lat/lng text inputs below the map re-render
              // with the freshly-picked coordinates. Without this the inputs
              // keep showing the previous values until the user taps into
              // them (assigning to TextEditingController.text doesn't
              // notify the framework).
              setState(() {
                _latController.text = pickedLat.toStringAsFixed(6);
                _lngController.text = pickedLng.toStringAsFixed(6);
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTextField(controller: _latController, label: 'Latitude')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(controller: _lngController, label: 'Longitude')),
          ],
        ),
      ],
    );
  }

  Widget _buildManualLocation() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _latController,
            label: 'Latitude',
            validator: (v) {
              if (v?.isEmpty == true) return 'Required';
              if (double.tryParse(v!) == null) return 'Invalid';
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextField(
            controller: _lngController,
            label: 'Longitude',
            validator: (v) {
              if (v?.isEmpty == true) return 'Required';
              if (double.tryParse(v!) == null) return 'Invalid';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRadiusSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Entry Radius'),
              Text('${_entryRadius.round()} m', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: _entryRadius,
            min: 10,
            max: 200,
            divisions: 19,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primary.withValues(alpha: 0.3),
            onChanged: (value) => setState(() => _entryRadius = value),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10m', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              Text('200m', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection({
    required String code,
    required String flag,
    required String name,
    required TextEditingController nameController,
    required TextEditingController descController,
  }) {
    final loc = context.watch<LocalizationCubit>().state;
    final copyLabel = loc.translations['copy_from_english'] ?? 'Copy from English';
    final isEnglish = code == 'en';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const Spacer(),
              if (!isEnglish)
                TextButton.icon(
                  onPressed: () {
                    if (_nameEnController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Fill the English name first'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      nameController.text = _nameEnController.text;
                      descController.text = _descEnController.text;
                    });
                  },
                  icon: const Icon(Icons.content_copy, size: 16),
                  label: Text(copyLabel, style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: nameController,
            label: 'Name',
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: descController,
            label: 'Description',
            maxLines: 3,
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}
