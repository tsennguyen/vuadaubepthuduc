import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Service for uploading profile-related files to Firebase Storage
class ProfileStorageService {
  ProfileStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Upload a profile avatar image
  /// Returns the download URL of the uploaded image
  Future<String> uploadProfileAvatar({
    required String userId,
    required XFile image,
  }) async {
    final path = 'user_avatars/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(path);

    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      final bytes = await image.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    }

    final downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  }

  /// Delete an old profile avatar (optional cleanup)
  Future<void> deleteProfileAvatar(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Ignore errors if the file doesn't exist or isn't in our storage
      debugPrint('Failed to delete old avatar: $e');
    }
  }
}
