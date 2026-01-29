import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class RecipeStorageService {
  RecipeStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadCover({
    required String recipeId,
    required XFile image,
  }) async {
    final ref = _storage.ref().child('recipes/$recipeId/cover.jpg');
    final bytes = await image.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<List<String>> uploadPhotos({
    required String recipeId,
    required List<XFile> images,
  }) async {
    final urls = <String>[];
    for (int i = 0; i < images.length; i++) {
      final file = images[i];
      final ref =
          _storage.ref().child('recipes/$recipeId/photo_$i.jpg');
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }
}
