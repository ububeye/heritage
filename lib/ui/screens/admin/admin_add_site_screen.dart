import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/site_model.dart';
import '../../../data/services/firestore_service.dart';
import '../../../data/services/cloudinary_service.dart';
import '../../../data/services/translation_service.dart';
import '../../../blocs/localization/localization_cubit.dart';
import '../../../blocs/site_list/site_list_cubit.dart';
import '../../widgets/osm_location_picker.dart';

class AdminAddSiteScreen extends StatefulWidget {
  const AdminAddSiteScreen({super.key});

  @override
  State<AdminAddSiteScreen> createState() => _AdminAddSiteScreenState();
}

class _AdminAddSiteScreenState extends State<AdminAddSiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _cloudinaryService = CloudinaryService();
  final _translationService = TranslationService();

  // Controllers
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  // Form state
  String _selectedCategory = 'historic';
  double _entryRadius = 50.0;
  int _locationTabIndex = 1; // 0 = Map, 1 = Manual

  // Images
  List<XFile> _selectedImages = [];
  bool _isUploading = false;

  // Loading state
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  String get _currentLang {
    final locState = context.read<LocalizationCubit>().state;
    return locState.currentLanguage;
  }

  Future<void> _pickImages() async {
    final images = await _cloudinaryService.pickMultipleImages();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
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
      // 1. Upload images to Cloudinary
      setState(() => _isUploading = true);

      final uploadedUrls = await _cloudinaryService.uploadImages(_selectedImages);

      if (uploadedUrls.isEmpty) {
        throw Exception('Failed to upload images');
      }

      // 2. Prepare base language data
      final baseLang = _currentLang;
      final isSwahili = baseLang == 'sw';

      // 3. Create site with base language content
      final site = SiteModel(
        id: '',
        nameEn: isSwahili ? '' : _nameController.text,
        nameSw: isSwahili ? _nameController.text : '',
        descriptionEn: isSwahili ? '' : _descController.text,
        descriptionSw: isSwahili ? _descController.text : '',
        descriptionFr: '',
        descriptionDe: '',
        descriptionAr: '',
        descriptionIt: '',
        descriptionEs: '',
        cloudinaryImageUrl: uploadedUrls.first,
        imageUrls: uploadedUrls,
        latitude: double.parse(_latController.text),
        longitude: double.parse(_lngController.text),
        entryRadiusM: _entryRadius,
        category: _selectedCategory,
        createdAt: DateTime.now(),
      );

      // 4. Save initial site to Firestore
      await _firestoreService.addSite(site);

      // 5. Auto-translate missing languages
      await _translateMissingLanguages(site.id, baseLang);

      // 6. Reload sites list
      if (mounted) {
        context.read<SiteListCubit>().loadSites();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site added! Translations in progress...'),
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

  Future<void> _translateMissingLanguages(String siteId, String baseLang) async {
    final targetLangs = ['fr', 'de', 'ar', 'it', 'es'];
    if (baseLang == 'sw') targetLangs.add('en');
    if (baseLang == 'en') targetLangs.add('sw');

    final baseName = _nameController.text;
    final baseDesc = _descController.text;

    for (final targetLang in targetLangs) {
      final translatedName = await _translationService.translate(
        text: baseName,
        targetLanguage: targetLang,
        sourceLanguage: baseLang,
      );

      final translatedDesc = await _translationService.translate(
        text: baseDesc,
        targetLanguage: targetLang,
        sourceLanguage: baseLang,
      );

      await _firestoreService.translateSite(
        siteId: siteId,
        languageCode: targetLang,
        name: translatedName ?? '',
        description: translatedDesc ?? '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, locState) {
        final nameLabel = _currentLang == 'sw' ? 'Jina la Eneo' : 'Site Name (${_currentLang.toUpperCase()})';
        final descLabel = _currentLang == 'sw' ? 'Maelezo' : 'Description (${_currentLang.toUpperCase()})';

        return Scaffold(
          backgroundColor: AppColors.background,
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
                        _isUploading ? 'Uploading images...' : 'Translating...',
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
                      // Site Name
                      _buildSectionTitle('Site Information'),
                      _buildTextField(
                        controller: _nameController,
                        label: nameLabel,
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      _buildTextField(
                        controller: _descController,
                        label: descLabel,
                        maxLines: 4,
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Category
                      _buildSectionTitle('Category'),
                      _buildCategoryDropdown(),
                      const SizedBox(height: 24),

                      // Photos
                      _buildSectionTitle('Photos (Required - Min 1)'),
                      _buildPhotoSection(),
                      const SizedBox(height: 24),

                      // Location
                      _buildSectionTitle('Location'),
                      _buildLocationSection(),
                      const SizedBox(height: 24),

                      // Entry Radius
                      _buildSectionTitle('Entry Radius: ${_entryRadius.round()}m'),
                      _buildRadiusSlider(),
                      const SizedBox(height: 32),

                      // Save Button
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
      },
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
        fillColor: AppColors.surface,
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
              color: AppColors.surface,
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
        color: AppColors.surface,
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
            child: _locationTabIndex == 0 ? _buildMapLocation() : _buildManualLocation(),
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
    return Column(
      children: [
        OsmLocationPicker(
          defaultLat: -6.1621,
          defaultLng: 39.1835,
          onLocationSelected: (lat, lng) {
            _latController.text = lat.toStringAsFixed(6);
            _lngController.text = lng.toStringAsFixed(6);
          },
        ),
        const SizedBox(height: 12),
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
        color: AppColors.surface,
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
}
