class CloudinaryService {
  final String cloudName;

  CloudinaryService({this.cloudName = 'demo'});

  String getTransformedUrl(
    String publicId, {
    String transformation = 'w_500,c_fill,q_auto,f_auto',
    String format = 'jpg',
  }) {
    return 'https://res.cloudinary.com/$cloudName/image/upload/$transformation/$publicId.$format';
  }

  String getThumbnailUrl(String imageUrl) {
    return _applyTransformation(imageUrl, 'w_200,c_fill,q_auto,f_auto');
  }

  String getFullImageUrl(String imageUrl) {
    return _applyTransformation(imageUrl, 'w_1200,c_fill,q_auto,f_auto');
  }

  String getMediumImageUrl(String imageUrl) {
    return _applyTransformation(imageUrl, 'w_500,c_fill,q_auto,f_auto');
  }

  String _applyTransformation(String url, String transformation) {
    if (!url.contains('upload/')) return url;

    final parts = url.split('upload/');
    if (parts.length == 2) {
      return '${parts[0]}upload/$transformation/${parts[1]}';
    }
    return url;
  }

  String generateUploadSignature({
    required String timestamp,
    required String signature,
    required String apiKey,
    required String cloudName,
  }) {
    return 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  }

  String getPlaceholderUrl({int width = 500, int height = 300}) {
    return 'https://via.placeholder.com/${width}x${height}/8B5E3C/FFFFFF?text=Loading';
  }
}