import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

class AppStorage {
  static const _historyKey = 'aiboss.chat.history';
  static const _memoryKey = 'aiboss.chat.memory';
  static const _providerKey = 'aiboss.provider.type';
  static const _modelKey = 'aiboss.provider.model';
  static const _endpointKey = 'aiboss.provider.endpoint';
  static const _notesKey = 'aiboss.plugin.notes';
  static const _notesEnabledKey = 'aiboss.plugin.notes.enabled';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<ChatMessage> loadMessages() {
    final raw = _prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMessages(List<ChatMessage> messages) async {
    await _prefs.setString(
      _historyKey,
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    );
  }

  String loadMemory() => _prefs.getString(_memoryKey) ?? '';

  Future<void> saveMemory(String value) async {
    await _prefs.setString(_memoryKey, value);
  }

  String loadProviderType() =>
      _prefs.getString(_providerKey) ?? 'gemini';

  String loadModel() => _prefs.getString(_modelKey) ??
      (loadProviderType() == 'gemini'
          ? 'gemini-2.5-flash'
          : 'gpt-4o-mini');

  String loadEndpoint() => _prefs.getString(_endpointKey) ??
      'https://api.openai.com/v1/chat/completions';

  Future<String> loadApiKey() async =>
      await _secure.read(key: 'aiboss.provider.api_key') ?? '';

  Future<void> saveProviderSettings({
    required String type,
    required String model,
    required String endpoint,
    required String apiKey,
  }) async {
    await _prefs.setString(_providerKey, type);
    await _prefs.setString(_modelKey, model);
    await _prefs.setString(_endpointKey, endpoint);
    if (apiKey.trim().isEmpty) {
      await _secure.delete(key: 'aiboss.provider.api_key');
    } else {
      await _secure.write(
        key: 'aiboss.provider.api_key',
        value: apiKey.trim(),
      );
    }
  }

  List<String> loadNotes() =>
      _prefs.getStringList(_notesKey) ?? <String>[];

  Future<void> saveNotes(List<String> notes) async {
    await _prefs.setStringList(_notesKey, notes);
  }

  bool notesPluginEnabled() =>
      _prefs.getBool(_notesEnabledKey) ?? true;

  Future<void> setNotesPluginEnabled(bool enabled) async {
    await _prefs.setBool(_notesEnabledKey, enabled);
  }

  Future<void> clearConversation() async {
    await _prefs.remove(_historyKey);
    await _prefs.remove(_memoryKey);
  }
}
