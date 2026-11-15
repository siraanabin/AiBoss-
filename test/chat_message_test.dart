import 'package:flutter_test/flutter_test.dart';
import 'package:aiboss/models/chat_message.dart';

void main() {
  test('ChatMessage round-trips through JSON', () {
    final original = ChatMessage(
      role: 'user',
      content: 'Hello AiBoss',
      createdAt: DateTime.utc(2026, 11, 15),
    );

    final restored = ChatMessage.fromJson(original.toJson());

    expect(restored.role, original.role);
    expect(restored.content, original.content);
    expect(restored.createdAt, original.createdAt);
  });
}
