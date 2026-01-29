import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ReelStorageService {
  ReelStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadVideo({
    required String reelId,
    required XFile video,
  }) async {
    final path = 'reels/$reelId/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ref = _storage.ref().child(path);
    
    final bytes = await video.readAsBytes();
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'video/mp4'),
    );
    
    return await ref.getDownloadURL();
  }

  Future<String> uploadThumbnail({
    required String reelId,
    required XFile thumbnail,
  }) async {
    final path = 'reels/$reelId/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(path);
    
    final bytes = await thumbnail.readAsBytes();
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    
    return await ref.getDownloadURL();
  }
}
