import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminAiConfig {
  const AdminAiConfig({
    required this.id,
    required this.model,
    required this.systemPrompt,
    required this.userPromptTemplate,
    required this.temperature,
    required this.maxOutputTokens,
    required this.enabled,
    this.name,
    this.description,
    this.extraNotes,
    this.createdAt,
    this.updatedAt,
    this.updatedByUid,
    this.updatedByName,
  });

  final String id;
  final String model;
  final String systemPrompt;
  final String userPromptTemplate;
  final double temperature;
  final int maxOutputTokens;
  final bool enabled;
  final String? name;
  final String? description;
  final String? extraNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedByUid;
  final String? updatedByName;

  AdminAiConfig copyWith({
    String? id,
    String? model,
    String? systemPrompt,
    String? userPromptTemplate,
    double? temperature,
    int? maxOutputTokens,
    bool? enabled,
    String? name,
    String? description,
    String? extraNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedByUid,
    String? updatedByName,
  }) {
    return AdminAiConfig(
      id: id ?? this.id,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      userPromptTemplate: userPromptTemplate ?? this.userPromptTemplate,
      temperature: temperature ?? this.temperature,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      enabled: enabled ?? this.enabled,
      name: name ?? this.name,
      description: description ?? this.description,
      extraNotes: extraNotes ?? this.extraNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }

  factory AdminAiConfig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AdminAiConfig(
      id: doc.id,
      name: _nonEmptyString(data['name']) ?? doc.id,
      description: _nonEmptyString(data['description']),
      model: _nonEmptyString(data['model']) ?? 'gpt-4.1-mini',
      systemPrompt: _nonEmptyString(data['systemPrompt']) ?? '',
      userPromptTemplate: _nonEmptyString(data['userPromptTemplate']) ?? '',
      temperature: _toDouble(data['temperature']) ?? 0.7,
      maxOutputTokens: _toInt(data['maxOutputTokens']) ?? 1024,
      enabled: _parseBool(data['enabled'], fallback: true),
      extraNotes: _nonEmptyString(data['extraNotes']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedByUid: _nonEmptyString(data['updatedByUid']),
      updatedByName: _nonEmptyString(data['updatedByName']),
    );
  }
}

class AdminAiConfigRepository {
  AdminAiConfigRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _configs =>
      _firestore.collection('aiConfigs');

  Stream<List<AdminAiConfig>> watchAll() {
    return _configs.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map(AdminAiConfig.fromDoc).toList();
    });
  }

  Stream<AdminAiConfig?> watchOne(String id) {
    return _configs.doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AdminAiConfig.fromDoc(snap);
    });
  }

  Future<void> saveConfig(
    AdminAiConfig config, {
    required String updatedByUid,
    String? updatedByName,
  }) async {
    final ref = _configs.doc(config.id);
    final snap = await ref.get();

    final payload = <String, dynamic>{
      'id': config.id,
      'name': config.name,
      'description': config.description,
      'model': config.model,
      'systemPrompt': config.systemPrompt,
      'userPromptTemplate': config.userPromptTemplate,
      'temperature': config.temperature.clamp(0, 2),
      'maxOutputTokens': config.maxOutputTokens,
      'enabled': config.enabled,
      'extraNotes': config.extraNotes,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': updatedByUid,
      'updatedByName': updatedByName,
    };
    if (!snap.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(payload, SetOptions(merge: true));
  }
}

final adminAiConfigRepositoryProvider =
    Provider<AdminAiConfigRepository>((ref) {
  return AdminAiConfigRepository();
});

final aiConfigsProvider = StreamProvider<List<AdminAiConfig>>((ref) {
  return ref.watch(adminAiConfigRepositoryProvider).watchAll();
});

final aiConfigProvider =
    StreamProvider.family<AdminAiConfig?, String>((ref, id) {
  return ref.watch(adminAiConfigRepositoryProvider).watchOne(id);
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

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _nonEmptyString(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
