import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class PostStorageService {
  PostStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<List<String>> uploadPostImages({
    required String postId,
    required List<XFile> images,
  }) async {
    final urls = <String>[];
    for (int i = 0; i < images.length; i++) {
      final file = images[i];
      final path =
          'posts/$postId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final ref = _storage.ref().child(path);

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        final bytes = await file.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      }
      final downloadUrl = await ref.getDownloadURL();
      urls.add(downloadUrl);
    }
    return urls;
  }
}
