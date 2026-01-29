import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ViolationThresholds {
  const ViolationThresholds({
    required this.warningCount,
    required this.muteCount,
    required this.banCount,
  });

  final int warningCount;
  final int muteCount;
  final int banCount;

  ViolationThresholds copyWith({
    int? warningCount,
    int? muteCount,
    int? banCount,
  }) {
    return ViolationThresholds(
      warningCount: warningCount ?? this.warningCount,
      muteCount: muteCount ?? this.muteCount,
      banCount: banCount ?? this.banCount,
    );
  }
}

class RecipeContentRules {
  const RecipeContentRules({
    required this.allowAlcohol,
    required this.allowMeat,
    required this.requireNutritionForPublic,
  });

  final bool allowAlcohol;
  final bool allowMeat;
  final bool requireNutritionForPublic;

  RecipeContentRules copyWith({
    bool? allowAlcohol,
    bool? allowMeat,
    bool? requireNutritionForPublic,
  }) {
    return RecipeContentRules(
      allowAlcohol: allowAlcohol ?? this.allowAlcohol,
      allowMeat: allowMeat ?? this.allowMeat,
      requireNutritionForPublic:
          requireNutritionForPublic ?? this.requireNutritionForPublic,
    );
  }
}

class ReportSettings {
  const ReportSettings({
    required this.autoHideAfterReports,
  });

  final int autoHideAfterReports;

  ReportSettings copyWith({
    int? autoHideAfterReports,
  }) {
    return ReportSettings(
      autoHideAfterReports: autoHideAfterReports ?? this.autoHideAfterReports,
    );
  }
}

class AdminSettings {
  const AdminSettings({
    required this.communityGuidelines,
    required this.aiModerationEnabled,
    required this.aiLanguage,
    required this.violationThresholds,
    required this.recipeContentRules,
    required this.reportSettings,
    this.updatedAt,
    this.updatedBy,
  });

  final String communityGuidelines;
  final bool aiModerationEnabled;
  final String aiLanguage;
  final ViolationThresholds violationThresholds;
  final RecipeContentRules recipeContentRules;
  final ReportSettings reportSettings;
  final DateTime? updatedAt;
  final String? updatedBy;

  AdminSettings copyWith({
    String? communityGuidelines,
    bool? aiModerationEnabled,
    String? aiLanguage,
    ViolationThresholds? violationThresholds,
    RecipeContentRules? recipeContentRules,
    ReportSettings? reportSettings,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return AdminSettings(
      communityGuidelines: communityGuidelines ?? this.communityGuidelines,
      aiModerationEnabled: aiModerationEnabled ?? this.aiModerationEnabled,
      aiLanguage: aiLanguage ?? this.aiLanguage,
      violationThresholds: violationThresholds ?? this.violationThresholds,
      recipeContentRules: recipeContentRules ?? this.recipeContentRules,
      reportSettings: reportSettings ?? this.reportSettings,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory AdminSettings.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final thresholds = data['violationThresholds'] as Map<String, dynamic>? ?? {};
    final recipeRules = data['recipeContentRules'] as Map<String, dynamic>? ?? {};
    final reportSettings = data['reportSettings'] as Map<String, dynamic>? ?? {};

    return AdminSettings(
      communityGuidelines: (data['communityGuidelines'] as String? ?? '').trim(),
      aiModerationEnabled: _parseBool(data['aiModerationEnabled'], fallback: true),
      aiLanguage: (data['aiLanguage'] as String? ?? 'vi').trim(),
      violationThresholds: ViolationThresholds(
        warningCount: _toInt(thresholds['warningCount'], 1),
        muteCount: _toInt(thresholds['muteCount'], 2),
        banCount: _toInt(thresholds['banCount'], 3),
      ),
      recipeContentRules: RecipeContentRules(
        allowAlcohol: _parseBool(recipeRules['allowAlcohol'], fallback: true),
        allowMeat: _parseBool(recipeRules['allowMeat'], fallback: true),
        requireNutritionForPublic:
            _parseBool(recipeRules['requireNutritionForPublic'], fallback: false),
      ),
      reportSettings: ReportSettings(
        autoHideAfterReports: _toInt(reportSettings['autoHideAfterReports'], 5),
      ),
      updatedAt: _toDateTime(data['updatedAt']),
      updatedBy: (data['updatedBy'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'communityGuidelines': communityGuidelines,
      'aiModerationEnabled': aiModerationEnabled,
      'aiLanguage': aiLanguage,
      'violationThresholds': {
        'warningCount': violationThresholds.warningCount,
        'muteCount': violationThresholds.muteCount,
        'banCount': violationThresholds.banCount,
      },
      'recipeContentRules': {
        'allowAlcohol': recipeContentRules.allowAlcohol,
        'allowMeat': recipeContentRules.allowMeat,
        'requireNutritionForPublic': recipeContentRules.requireNutritionForPublic,
      },
      'reportSettings': {
        'autoHideAfterReports': reportSettings.autoHideAfterReports,
      },
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  static AdminSettings defaults() {
    return const AdminSettings(
      communityGuidelines: '',
      aiModerationEnabled: true,
      aiLanguage: 'vi',
      violationThresholds: ViolationThresholds(
        warningCount: 1,
        muteCount: 2,
        banCount: 3,
      ),
      recipeContentRules: RecipeContentRules(
        allowAlcohol: true,
        allowMeat: true,
        requireNutritionForPublic: false,
      ),
      reportSettings: ReportSettings(autoHideAfterReports: 5),
      updatedAt: null,
      updatedBy: null,
    );
  }
}

class AdminSettingsRepository {
  AdminSettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('adminSettings').doc('general');

  Stream<AdminSettings?> watchGeneral() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists) return AdminSettings.defaults();
      return AdminSettings.fromDoc(snap);
    });
  }

  Future<void> save(AdminSettings settings, {required String updatedBy}) async {
    await _doc.set(
      {
        ...settings.toMap(),
        'updatedBy': updatedBy,
      },
      SetOptions(merge: true),
    );
  }
}

final adminSettingsRepositoryProvider = Provider<AdminSettingsRepository>((ref) {
  return AdminSettingsRepository();
});

bool _parseBool(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return fallback;
}

int _toInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true).toLocal();
  }
  return null;
}
