import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlannerSettings {
  final bool enabled;
  final int minutesBefore;

  const PlannerSettings({
    required this.enabled,
    required this.minutesBefore,
  });

  PlannerSettings copyWith({bool? enabled, int? minutesBefore}) {
    return PlannerSettings(
      enabled: enabled ?? this.enabled,
      minutesBefore: minutesBefore ?? this.minutesBefore,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'minutesBefore': minutesBefore,
      };

  factory PlannerSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const PlannerSettings(enabled: true, minutesBefore: 30);
    }
    return PlannerSettings(
      enabled: map['enabled'] as bool? ?? true,
      minutesBefore: (map['minutesBefore'] as num?)?.toInt() ?? 30,
    );
  }
}

abstract class PlannerSettingsRepository {
  Stream<PlannerSettings> watch();
  Future<void> update({required bool enabled, required int minutesBefore});
}

class FirestorePlannerSettingsRepository implements PlannerSettingsRepository {
  FirestorePlannerSettingsRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Stream<PlannerSettings> watch() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.error(Exception('Not authenticated'));
    return _userDoc(uid).snapshots().map((doc) {
      return PlannerSettings.fromMap(
        (doc.data() ?? {})['plannerSettings'] as Map<String, dynamic>?,
      );
    });
  }

  @override
  Future<void> update({required bool enabled, required int minutesBefore}) async {
    final uid = _requireUid();
    await _userDoc(uid).set(
      {
        'plannerSettings': {
          'enabled': enabled,
          'minutesBefore': minutesBefore,
        },
      },
      SetOptions(merge: true),
    );
  }
}

