import 'package:flutter_test/flutter_test.dart';
import 'package:aiboss/models/chat_message.dart';

void main() {
  test('AiBoss chat model preserves message data', () {
    final message = ChatMessage(
      role: 'assistant',
      content: 'Welcome to AiBoss',
      createdAt: DateTime.utc(2026, 11, 15),
    );

    final restored = ChatMessage.fromJson(message.toJson());

    expect(restored.role, 'assistant');
    expect(restored.content, 'Welcome to AiBoss');
    expect(restored.createdAt, DateTime.utc(2026, 11, 15));
  });
}
