class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.model,
    required this.endpoint,
    required this.apiKey,
    required this.enabled,
    required this.isGemini,
  });

  final String id;
  final String name;
  final String model;
  final String endpoint;
  final String apiKey;
  final bool enabled;
  final bool isGemini;

  AiProviderConfig copyWith({
    String? model,
    String? apiKey,
    bool? enabled,
  }) => AiProviderConfig(
    id: id,
    name: name,
    model: model ?? this.model,
    endpoint: endpoint,
    apiKey: apiKey ?? this.apiKey,
    enabled: enabled ?? this.enabled,
    isGemini: isGemini,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'model': model, 'endpoint': endpoint,
    'enabled': enabled, 'isGemini': isGemini,
  };

  factory AiProviderConfig.fromJson(
    Map<String, dynamic> json, String apiKey,
  ) => AiProviderConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    model: json['model'] as String,
    endpoint: json['endpoint'] as String,
    enabled: json['enabled'] as bool? ?? true,
    isGemini: json['isGemini'] as bool? ?? false,
    apiKey: apiKey,
  );

  static List<AiProviderConfig> defaults() => const [
    AiProviderConfig(
      id: 'gemini', name: 'Google Gemini', model: 'gemini-3.8-flash',
      endpoint: '', apiKey: '', enabled: true, isGemini: true,
    ),
    AiProviderConfig(
      id: 'openai', name: 'OpenAI', model: 'gpt-4o-mini',
      endpoint: 'https://api.openai.com/v1/chat/completions',
      apiKey: '', enabled: true, isGemini: false,
    ),
    AiProviderConfig(
      id: 'deepseek', name: 'DeepSeek', model: 'deepseek-chat',
      endpoint: 'https://api.deepseek.com/chat/completions',
      apiKey: '', enabled: true, isGemini: false,
    ),
    AiProviderConfig(
      id: 'groq', name: 'Groq', model: 'llama-3.3-70b-versatile',
      endpoint: 'https://api.groq.com/openai/v1/chat/completions',
      apiKey: '', enabled: true, isGemini: false,
    ),
    AiProviderConfig(
      id: 'openrouter', name: 'OpenRouter',
      model: 'openai/gpt-4o-mini',
      endpoint: 'https://openrouter.ai/api/v1/chat/completions',
      apiKey: '', enabled: true, isGemini: false,
    ),
  ];
}
