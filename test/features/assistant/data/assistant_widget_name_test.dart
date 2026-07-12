import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';

void main() {
  group('AssistantRepository.isValidWidgetName', () {
    test('accepts simple names', () {
      expect(AssistantRepository.isValidWidgetName('property_card'), isTrue);
      expect(AssistantRepository.isValidWidgetName('emi-calculator'), isTrue);
      expect(AssistantRepository.isValidWidgetName('A1'), isTrue);
    });

    test('rejects path traversal and injection', () {
      expect(AssistantRepository.isValidWidgetName('../etc/passwd'), isFalse);
      expect(AssistantRepository.isValidWidgetName('a/b'), isFalse);
      expect(AssistantRepository.isValidWidgetName('a?x=1'), isFalse);
      expect(AssistantRepository.isValidWidgetName(''), isFalse);
      expect(AssistantRepository.isValidWidgetName('a b'), isFalse);
    });
  });
}
