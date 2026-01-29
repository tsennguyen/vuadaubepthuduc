import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

bool _emulatorConfigured = false;

Future<void> initFirebaseEmulatorIfNeeded({
  bool useEmulator = false,
  String host = 'localhost',
  int firestorePort = 8080,
  int functionsPort = 5001,
  int authPort = 9099,
}) async {
  if (!useEmulator || _emulatorConfigured) return;

  FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
  FirebaseFunctions.instance.useFunctionsEmulator(host, functionsPort);

  try {
    FirebaseAuth.instance.useAuthEmulator(host, authPort);
  } catch (err) {
    debugPrint('Auth emulator chưa sẵn sàng: $err');
  }

  _emulatorConfigured = true;
}
