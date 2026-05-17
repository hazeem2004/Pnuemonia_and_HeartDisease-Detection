import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pneumoai/services/ai_service.dart';

void main() {
  group('Model Confidence Tests', () {
    late AIService aiService;

    setUp(() async {
      aiService = AIService();
      await aiService.initializeModel();
    });

    test('Test confidence levels with sample images', () async {
      final testDir = Directory('C:\\Users\\01-135231-091\\Desktop\\ai_project\\test_image');
      
      expect(testDir.existsSync(), true, reason: 'Test image directory should exist');

      final imageFiles = testDir
          .listSync()
          .where((f) => f is File && 
                (f.path.endsWith('.jpg') || 
                 f.path.endsWith('.png') || 
                 f.path.endsWith('.jpeg')))
          .cast<File>()
          .toList();

      expect(imageFiles.isNotEmpty, true, reason: 'Should have test images');

      print('\n========================================');
      print('Testing ${imageFiles.length} X-ray images');
      print('========================================\n');

      for (var i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];
        final fileName = imageFile.path.split('\\').last;

        print('${i + 1}. Testing: $fileName');
        print('   ${'─' * 50}');

        final bytes = await imageFile.readAsBytes();
        final result = await aiService.analyzeImage(bytes, fileName);
        final confidence = aiService.confidence;

        print('   Result: $result');
        print('   Confidence: ${confidence.toStringAsFixed(2)}%');
        print('');

        expect(result, isNotEmpty);
        expect(confidence, greaterThan(0));
        expect(confidence, lessThanOrEqualTo(100));
      }

      print('========================================');
      print('All tests completed!');
      print('========================================\n');
    });

    tearDown(() {
      aiService.dispose();
    });
  });
}
