import 'package:equatable/equatable.dart';

class SiteModel extends Equatable {

  const SiteModel({
    required this.id,
    required this.nameEn,
    required this.nameSw,
    this.nameFr = '',
    this.nameDe = '',
    this.nameAr = '',
    this.nameIt = '',
    this.nameEs = '',
    required this.descriptionEn,
    required this.descriptionSw,
    required this.descriptionFr,
    required this.descriptionDe,
    required this.descriptionAr,
    required this.descriptionIt,
    required this.descriptionEs,
    required this.cloudinaryImageUrl,
    this.imageUrls = const [],
    required this.latitude,
    required this.longitude,
    this.entryRadiusM = 50.0,
    this.address,
    this.rating,
    this.category,
    this.createdAt,
    this.updatedAt,
    this.featured = false,
  });

  factory SiteModel.fromMap(Map<String, dynamic> map) {
    // Handle both single image and multiple images
    List<String> parseImageUrls(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.cast<String>();
      if (value is String && value.isNotEmpty) return [value];
      return [];
    }

    return SiteModel(
      id: map['id'] ?? '',
      nameEn: map['name_en'] ?? '',
      nameSw: map['name_sw'] ?? '',
      nameFr: map['name_fr'] ?? '',
      nameDe: map['name_de'] ?? '',
      nameAr: map['name_ar'] ?? '',
      nameIt: map['name_it'] ?? '',
      nameEs: map['name_es'] ?? '',
      descriptionEn: map['description_en'] ?? '',
      descriptionSw: map['description_sw'] ?? '',
      descriptionFr: map['description_fr'] ?? '',
      descriptionDe: map['description_de'] ?? '',
      descriptionAr: map['description_ar'] ?? '',
      descriptionIt: map['description_it'] ?? '',
      descriptionEs: map['description_es'] ?? '',
      cloudinaryImageUrl: map['cloudinary_image_url'] ?? '',
      imageUrls: parseImageUrls(map['image_urls']),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      entryRadiusM: (map['entry_radius_m'] as num?)?.toDouble() ?? 50.0,
      address: map['address'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
      category: map['category'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'])
          : null,
      featured: map['featured'] == true,
    );
  }
  final String id;

  // Names (7 languages)
  final String nameEn;
  final String nameSw;
  final String nameFr;
  final String nameDe;
  final String nameAr;
  final String nameIt;
  final String nameEs;

  // Descriptions (7 languages)
  final String descriptionEn;
  final String descriptionSw;
  final String descriptionFr;
  final String descriptionDe;
  final String descriptionAr;
  final String descriptionIt;
  final String descriptionEs;

  // Images - support both single and multiple
  final String cloudinaryImageUrl; // For backward compatibility
  final List<String> imageUrls; // Multiple images

  // Location
  final double latitude;
  final double longitude;
  final double entryRadiusM;

  // Display address (admin-supplied; falls back to "Stone Town, Zanzibar")
  final String? address;

  // Metadata
  final double? rating;
  final String? category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Curation
  final bool featured;

  // Get primary image (first in list, or fallback to single image)
  String get primaryImage {
    if (imageUrls.isNotEmpty) return imageUrls.first;
    return cloudinaryImageUrl;
  }

  // Get all images including legacy single image
  List<String> get allImages {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (cloudinaryImageUrl.isNotEmpty) return [cloudinaryImageUrl];
    return [];
  }

  /// Human-readable address. Falls back to a sensible default if the
  /// admin hasn't filled one in for the site.
  String get displayAddress {
    final raw = address?.trim();
    if (raw == null || raw.isEmpty) return 'Stone Town, Zanzibar';
    return raw;
  }

  String getName(String languageCode) {
    switch (languageCode) {
      case 'sw':
        return nameSw;
      case 'fr':
        return nameFr;
      case 'de':
        return nameDe;
      case 'ar':
        return nameAr;
      case 'it':
        return nameIt;
      case 'es':
        return nameEs;
      default:
        return nameEn;
    }
  }

  String getDescription(String languageCode) {
    switch (languageCode) {
      case 'sw':
        return descriptionSw;
      case 'fr':
        return descriptionFr;
      case 'de':
        return descriptionDe;
      case 'ar':
        return descriptionAr;
      case 'it':
        return descriptionIt;
      case 'es':
        return descriptionEs;
      default:
        return descriptionEn;
    }
  }

  String getTransformedImageUrl({
    String transformation = 'w_500,c_fill,q_auto,f_auto',
    int imageIndex = 0,
  }) {
    final images = allImages;
    if (images.isEmpty) return '';

    final imageUrl = imageIndex < images.length
        ? images[imageIndex]
        : images.first;

    if (imageUrl.contains('upload')) {
      final parts = imageUrl.split('upload/');
      if (parts.length == 2) {
        return '${parts[0]}upload/$transformation/${parts[1]}';
      }
    }
    return imageUrl;
  }

  SiteModel copyWith({
    String? id,
    String? nameEn,
    String? nameSw,
    String? nameFr,
    String? nameDe,
    String? nameAr,
    String? nameIt,
    String? nameEs,
    String? descriptionEn,
    String? descriptionSw,
    String? descriptionFr,
    String? descriptionDe,
    String? descriptionAr,
    String? descriptionIt,
    String? descriptionEs,
    String? cloudinaryImageUrl,
    List<String>? imageUrls,
    double? latitude,
    double? longitude,
    double? entryRadiusM,
    String? address,
    double? rating,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? featured,
  }) {
    return SiteModel(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameSw: nameSw ?? this.nameSw,
      nameFr: nameFr ?? this.nameFr,
      nameDe: nameDe ?? this.nameDe,
      nameAr: nameAr ?? this.nameAr,
      nameIt: nameIt ?? this.nameIt,
      nameEs: nameEs ?? this.nameEs,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionSw: descriptionSw ?? this.descriptionSw,
      descriptionFr: descriptionFr ?? this.descriptionFr,
      descriptionDe: descriptionDe ?? this.descriptionDe,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionIt: descriptionIt ?? this.descriptionIt,
      descriptionEs: descriptionEs ?? this.descriptionEs,
      cloudinaryImageUrl: cloudinaryImageUrl ?? this.cloudinaryImageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      entryRadiusM: entryRadiusM ?? this.entryRadiusM,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      featured: featured ?? this.featured,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_sw': nameSw,
      'name_fr': nameFr,
      'name_de': nameDe,
      'name_ar': nameAr,
      'name_it': nameIt,
      'name_es': nameEs,
      'description_en': descriptionEn,
      'description_sw': descriptionSw,
      'description_fr': descriptionFr,
      'description_de': descriptionDe,
      'description_ar': descriptionAr,
      'description_it': descriptionIt,
      'description_es': descriptionEs,
      'cloudinary_image_url': cloudinaryImageUrl,
      'image_urls': imageUrls,
      'latitude': latitude,
      'longitude': longitude,
      'entry_radius_m': entryRadiusM,
      'address': address,
      'rating': rating,
      'category': category,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'featured': featured,
    };
  }

  @override
  List<Object?> get props => [
        id,
        nameEn,
        nameSw,
        nameFr,
        nameDe,
        nameAr,
        nameIt,
        nameEs,
        descriptionEn,
        descriptionSw,
        descriptionFr,
        descriptionDe,
        descriptionAr,
        descriptionIt,
        descriptionEs,
        cloudinaryImageUrl,
        imageUrls,
        latitude,
        longitude,
        entryRadiusM,
        address,
        rating,
        category,
        createdAt,
        updatedAt,
        featured,
      ];
}

// Site categories
class SiteCategories {
  static const List<String> all = [
    'historic',
    'cultural',
    'religious',
    'market',
    'museum',
    'natural_landmark',
    'government',
    'other',
  ];

  static const Map<String, String> labels = {
    'historic': 'Historic',
    'cultural': 'Cultural',
    'religious': 'Religious',
    'market': 'Market',
    'museum': 'Museum',
    'natural_landmark': 'Natural Landmark',
    'government': 'Government Building',
    'other': 'Other',
  };

  static String getLabel(String category) {
    return labels[category] ?? category;
  }
}
