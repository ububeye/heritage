import 'package:equatable/equatable.dart';

class SiteModel extends Equatable {
  final String id;

  // Names
  final String nameEn;
  final String nameSw;

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

  // Metadata
  final double? rating;
  final String? category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SiteModel({
    required this.id,
    required this.nameEn,
    required this.nameSw,
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
    this.rating,
    this.category,
    this.createdAt,
    this.updatedAt,
  });

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

  String getName(String languageCode) =>
      languageCode == 'sw' ? nameSw : nameEn;

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
    double? rating,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SiteModel(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameSw: nameSw ?? this.nameSw,
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
      rating: rating ?? this.rating,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_sw': nameSw,
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
      'rating': rating,
      'category': category,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

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
      descriptionEn: map['description_en'] ?? '',
      descriptionSw: map['description_sw'] ?? '',
      descriptionFr: map['description_fr'] ?? '',
      descriptionDe: map['description_de'] ?? '',
      descriptionAr: map['description_ar'] ?? '',
      descriptionIt: map['description_it'] ?? '',
      descriptionEs: map['description_es'] ?? '',
      cloudinaryImageUrl: map['cloudinary_image_url'] ?? '',
      imageUrls: parseImageUrls(map['image_urls']),
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      entryRadiusM: (map['entry_radius_m'] ?? 50.0).toDouble(),
      rating: map['rating']?.toDouble(),
      category: map['category'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        nameEn,
        nameSw,
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
        rating,
        category,
        createdAt,
        updatedAt,
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
