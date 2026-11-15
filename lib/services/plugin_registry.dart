import 'storage_service.dart';

class PluginInfo {
  const PluginInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.isCore,
  });

  final String id;
  final String name;
  final String description;
  final bool isCore;
}

class PluginRegistry {
  PluginRegistry(this.storage);

  final AppStorage storage;

  List<PluginInfo> get plugins => const [
        PluginInfo(
          id: 'conversation_memory',
          name: 'Conversation Memory',
          description: 'Keeps local conversation history and rolling context.',
          isCore: true,
        ),
        PluginInfo(
          id: 'local_notes',
          name: 'Local Notes',
          description: 'Save and recall notes with /note and /notes commands.',
          isCore: false,
        ),
        PluginInfo(
          id: 'web_search',
          name: 'Web Search',
          description: 'Reserved extension point for a future search provider.',
          isCore: false,
        ),
        PluginInfo(
          id: 'custom_tools',
          name: 'Custom Plugins',
          description: 'Extension point for adding trusted tools in future builds.',
          isCore: false,
        ),
      ];

  Future<String?> handleCommand(String input) async {
    if (!storage.notesPluginEnabled()) return null;

    final trimmed = input.trim();
    if (trimmed.startsWith('/note ')) {
      final note = trimmed.substring(6).trim();
      if (note.isEmpty) return 'Write something after /note to save a note.';
      final notes = storage.loadNotes()..add(note);
      await storage.saveNotes(notes);
      return 'Saved to your local notes.';
    }

    if (trimmed == '/notes') {
      final notes = storage.loadNotes();
      if (notes.isEmpty) return 'You have no saved notes yet.';
      return notes.asMap().entries
          .map((entry) => '${entry.key + 1}. ${entry.value}')
          .join('\n');
    }

    return null;
  }
}
