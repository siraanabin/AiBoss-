// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import 'models/ai_provider_config.dart';
import 'models/chat_message.dart';
import 'services/ai_service.dart';
import 'services/plugin_registry.dart';
import 'services/storage_service.dart';

class AiBossApp extends StatelessWidget {
  const AiBossApp({super.key, required this.storage});

  final AppStorage storage;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7567F8);
    return MaterialApp(
      title: 'AiBoss',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF11121A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0C12),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0C12),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF191A25),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: ChatScreen(storage: storage),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.storage});

  final AppStorage storage;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _ai = const AiService();

  late final PluginRegistry _plugins;
  List<ChatMessage> _messages = [];
  List<AiProviderConfig> _providers = [];
  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _plugins = PluginRegistry(widget.storage);
    _load();
  }

  Future<void> _load() async {
    final storage = widget.storage;
    final key = await storage.loadApiKey();
    if (!mounted) return;
    setState(() {
      _messages = storage.loadMessages();
      _providers = await storage.loadProviderConfigs();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    await widget.storage.saveMessages(_messages);
  }

  Future<void> _addMessage(String role, String content) async {
    setState(() {
      _messages.add(ChatMessage(
        role: role,
        content: content,
        createdAt: DateTime.now(),
      ));
    });
    await _persist();
    _jumpToBottom();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String> _makeMemory() async {
    if (_messages.length <= 24) return widget.storage.loadMemory();
    final older = _messages.sublist(0, _messages.length - 24);
    final useful = older.where((m) => m.role == 'user').toList();
    final recentFacts = useful.take(12).map((m) {
      final text = m.content.replaceAll('\n', ' ').trim();
      return text.length > 180 ? '${text.substring(0, 180)}…' : text;
    }).toList();
    final summary = recentFacts.join('\n');
    await widget.storage.saveMemory(summary);
    return summary;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy || _loading) return;
    _controller.clear();
    await _addMessage('user', text);

    final pluginResponse = await _plugins.handleCommand(text);
    if (pluginResponse != null) {
      await _addMessage('assistant', pluginResponse);
      return;
    }

    if (!_providers.any((p) => p.enabled && p.apiKey.trim().isNotEmpty)) {
      await _addMessage('assistant',
          'Connect at least one AI provider in Settings. API keys stay on this device.');
      return;
    }

    setState(() => _busy = true);
    try {
      final contextMessages = _messages.length > 24
          ? _messages.sublist(_messages.length - 24)
          : List<ChatMessage>.from(_messages);
      final answer = await _ai.replyWithFallback(
        providers: _providers,
        memory: await _makeMemory(),
        history: contextMessages,
      );
      await _addMessage('assistant', answer);
    } catch (error) {
      await _addMessage(
        'assistant',
        'I could not complete that request. $error',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    final configs = _providers.isEmpty
        ? AiProviderConfig.defaults()
        : _providers;
    final modelControllers = <String, TextEditingController>{
      for (final p in configs) p.id: TextEditingController(text: p.model),
    };
    final keyControllers = <String, TextEditingController>{
      for (final p in configs) p.id: TextEditingController(text: p.apiKey),
    };
    final enabled = <String, bool>{for (final p in configs) p.id: p.enabled};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => Padding(
          padding: EdgeInsets.fromLTRB(
            18, 8, 18, MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Multi-AI & Automatic Fallback',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text(
                  'Enable providers in the order shown. If one fails or is rate-limited, AiBoss tries the next enabled provider.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      for (final p in configs) ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name),
                          subtitle: Text(p.endpoint.isEmpty
                              ? 'Google Gemini API'
                              : p.endpoint),
                          value: enabled[p.id] ?? false,
                          onChanged: (v) => refresh(() => enabled[p.id] = v),
                        ),
                        TextField(
                          controller: modelControllers[p.id],
                          decoration: InputDecoration(
                            labelText: '${p.name} model ID',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: keyControllers[p.id],
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: '${p.name} API key',
                            helperText: 'Leave blank if you do not use this provider.',
                          ),
                        ),
                        const Divider(height: 24),
                      ],
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final updated = configs.map((p) => p.copyWith(
                        model: modelControllers[p.id]!.text.trim(),
                        apiKey: keyControllers[p.id]!.text.trim(),
                        enabled: enabled[p.id] ?? false,
                      )).toList();
                      await widget.storage.saveProviderConfigs(updated);
                      if (!mounted) return;
                      setState(() => _providers = updated);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Save All AI Settings'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Provider limits and token quotas are separate. Fallback uses your own configured accounts and does not create unlimited free usage. Never share API keys.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final controller in modelControllers.values) {
      controller.dispose();
    }
    for (final controller in keyControllers.values) {
      controller.dispose();
    }
  }

  Future<void> _openPlugins() async {
    var notesEnabled = widget.storage.notesPluginEnabled();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, refresh) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plugin Center',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  const ListTile(
                    leading: Icon(Icons.psychology_alt_outlined),
                    title: Text('Conversation Memory'),
                    subtitle: Text('Core feature · Always enabled'),
                    trailing: Icon(Icons.lock_outline),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.note_alt_outlined),
                    title: const Text('Local Notes'),
                    subtitle: const Text('/note text  ·  /notes'),
                    value: notesEnabled,
                    onChanged: (value) async {
                      refresh(() => notesEnabled = value);
                      await widget.storage.setNotesPluginEnabled(value);
                    },
                  ),
                  const ListTile(
                    leading: Icon(Icons.travel_explore),
                    title: Text('Web Search'),
                    subtitle: Text('Extension point · Coming in a later build'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.extension_outlined),
                    title: Text('Custom Plugins'),
                    subtitle: Text('Modular plugin registry is ready to extend'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This clears local chat history and rolling memory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.storage.clearConversation();
    if (!mounted) return;
    setState(() => _messages = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AiBoss', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Your multi-model AI workspace',
                style: TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Plugin Center',
            onPressed: _openPlugins,
            icon: const Icon(Icons.extension_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _clearChat();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear conversation')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _WelcomeView(onSettings: _openSettings)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          itemCount: _messages.length + (_busy ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return const _TypingBubble();
                            }
                            return _MessageBubble(message: _messages[index]);
                          },
                        ),
                ),
                _Composer(
                  controller: _controller,
                  busy: _busy,
                  onSend: _send,
                ),
              ],
            ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7667F8), Color(0xFF35B6D6)],
                ),
              ),
              child: const Icon(Icons.auto_awesome, size: 38, color: Colors.white),
            ),
            const SizedBox(height: 22),
            Text('Meet AiBoss',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 8),
            Text(
              'One chat for multiple AI providers, persistent history, '
              'conversation memory, and plugins.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onSettings,
              icon: const Icon(Icons.link),
              label: const Text('Connect an AI provider'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Try /note remember this or /notes after enabling Local Notes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF5147B8) : const Color(0xFF1A1B27),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 18),
          ),
        ),
        child: SelectableText(message.content),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Chip(
          avatar: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text('AiBoss is thinking…'),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message AiBoss…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              width: 52,
              child: FilledButton(
                onPressed: busy ? null : onSend,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
