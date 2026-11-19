import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelfieService {
  Future<XFile?> pick() => ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

  Future<void> upload(File file) async {
    final path =
        '${FirebaseAuth.instance.currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bytes = await file.readAsBytes();
    await Supabase.instance.client.storage.from('selfies').uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: false),
        );
    await Supabase.instance.client.rpc(
      'submit_selfie',
      params: {'p_path': path},
    );
  }

  Future<String> signedUrl(String path) => Supabase.instance.client.storage
      .from('selfies')
      .createSignedUrl(path, 60);

  Future<void> requestRetake(String scholarId) async {
    await Supabase.instance.client.rpc(
      'request_selfie_retake',
      params: {'p_scholar_id': scholarId},
    );
  }
}
