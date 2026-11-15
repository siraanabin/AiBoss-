import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_provider_config.dart';
import '../models/chat_message.dart';

class AiService {
  const AiService();

  static const Duration _requestTimeout = Duration(seconds: 18);

  Future<String> replyWithFallback({
    required List<AiProviderConfig> providers,
    required String memory,
    required List<ChatMessage> history,
  }) async {
    final ready = providers
        .where((p) => p.enabled && p.apiKey.trim().isNotEmpty)
        .toList();
    if (ready.isEmpty) {
      throw Exception('No enabled provider has an API key. Check Settings.');
    }

    final systemPrompt = 'You are AiBoss, a helpful assistant. Reply in the '
        'language used by the user. Be clear, useful, accurate, and concise. '
        'Use conversation memory only as context. If unsure, say so.';
    final contextPrompt = memory.trim().isEmpty
        ? systemPrompt
        : '$systemPrompt\n\nConversation memory:\n$memory';

    final failures = <String>[];
    for (final provider in ready) {
      try {
        final answer = provider.isGemini
            ? await _gemini(
                apiKey: provider.apiKey,
                model: provider.model,
                systemPrompt: contextPrompt,
                history: history,
              )
            : await _openAiCompatible(
                apiKey: provider.apiKey,
                model: provider.model,
                endpoint: provider.endpoint,
                systemPrompt: contextPrompt,
                history: history,
              );
        return answer;
      } on TimeoutException {
        failures.add('${provider.name}: timed out after 18 seconds');
      } catch (error) {
        failures.add('${provider.name}: ${_shortError(error)}');
      }
    }
    throw Exception('All enabled AI providers failed. ${failures.join(' | ')}');
  }

  String _shortError(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '').trim();
    return value.length > 160 ? '${value.substring(0, 160)}…' : value;
  }

  Future<String> reply({
    required String providerType,
    required String apiKey,
    required String model,
    required String endpoint,
    required String memory,
    required List<ChatMessage> history,
  }) {
    final config = AiProviderConfig(
      id: providerType,
      name: providerType,
      model: model,
      endpoint: endpoint,
      apiKey: apiKey,
      enabled: true,
      isGemini: providerType == 'gemini',
    );
    return replyWithFallback(
      providers: [config],
      memory: memory,
      history: history,
    );
  }

  Future<String> _gemini({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async {
    final safeModel = (model.trim().isEmpty ? 'gemini-3.8-flash' : model.trim())
        .replaceFirst(RegExp(r'^models/'), '');
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$safeModel:generateContent',
      {'key': apiKey.trim()},
    );
    final contents = history.map((message) => {
      'role': message.role == 'assistant' ? 'model' : 'user',
      'parts': [{'text': message.content}],
    }).toList();

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'systemInstruction': {'parts': [{'text': systemPrompt}]},
        'contents': contents,
        'generationConfig': {'temperature': 0.7},
      }),
    ).timeout(_requestTimeout);

    final data = _decode(response);
    final candidates = data['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) {
      throw Exception('Gemini returned no answer. Check model access and quota.');
    }
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? [];
    final answer = parts
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text'] as String? ?? '')
        .join('\n')
        .trim();
    if (answer.isEmpty) throw Exception('Gemini returned an empty answer.');
    return answer;
  }

  Future<String> _openAiCompatible({
    required String apiKey,
    required String model,
    required String endpoint,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw Exception('Invalid API endpoint URL.');
    }
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history.map((message) => {
        'role': message.role == 'assistant' ? 'assistant' : 'user',
        'content': message.content,
      }),
    ];
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${apiKey.trim()}',
      },
      body: jsonEncode({
        'model': model.trim().isEmpty ? 'gpt-4o-mini' : model.trim(),
        'messages': messages,
        'temperature': 0.7,
      }),
    ).timeout(_requestTimeout);

    final data = _decode(response);
    final choices = data['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) throw Exception('Provider returned no answer.');
    final message = choices.first['message'] as Map<String, dynamic>?;
    final answer = message?['content']?.toString().trim() ?? '';
    if (answer.isEmpty) throw Exception('Provider returned an empty answer.');
    return answer;
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Unreadable API response (HTTP ${response.statusCode}).');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          message = error['message']?.toString() ?? error['status']?.toString();
        } else {
          message = error?.toString() ?? decoded['message']?.toString();
        }
      }
      final status = response.statusCode;
      final hint = status == 401 || status == 403
          ? 'Check API key and permissions'
          : status == 429
              ? 'Rate limit or quota reached'
              : status == 503 || status == 502 || status == 500
                  ? 'Provider is busy or temporarily unavailable'
                  : 'HTTP $status';
      throw Exception('$hint${message == null ? '' : ': $message'}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected API response format.');
    }
    return decoded;
  }
}
