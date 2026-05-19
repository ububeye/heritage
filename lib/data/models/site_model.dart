import 'package:equatable/equatable.dart';

class SiteModel extends Equatable {
  final String id;
  final String nameEn;
  final String nameSw;
  final String descriptionEn;
  final String descriptionSw;
  final String descriptionFr;
  final String descriptionDe;
  final String descriptionAr;
  final String descriptionIt;
  final String descriptionEs;
  final String cloudinaryImageUrl;
  final double latitude;
  final double longitude;
  final double entryRadiusM;
  final double? rating;
  final String? category;

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
    required this.latitude,
    required this.longitude,
    this.entryRadiusM = 30.0,
    this.rating,
    this.category,
  });

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
  }) {
    if (cloudinaryImageUrl.contains('upload')) {
      final parts = cloudinaryImageUrl.split('upload/');
      if (parts.length == 2) {
        return '${parts[0]}upload/$transformation/${parts[1]}';
      }
    }
    return cloudinaryImageUrl;
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
    double? latitude,
    double? longitude,
    double? entryRadiusM,
    double? rating,
    String? category,
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      entryRadiusM: entryRadiusM ?? this.entryRadiusM,
      rating: rating ?? this.rating,
      category: category ?? this.category,
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
      'latitude': latitude,
      'longitude': longitude,
      'entry_radius_m': entryRadiusM,
      'rating': rating,
      'category': category,
    };
  }

  factory SiteModel.fromMap(Map<String, dynamic> map) {
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
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      entryRadiusM: (map['entry_radius_m'] ?? 30.0).toDouble(),
      rating: map['rating']?.toDouble(),
      category: map['category'],
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
        latitude,
        longitude,
        entryRadiusM,
        rating,
        category,
      ];
}