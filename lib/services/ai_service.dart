import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AIService extends ChangeNotifier {
  bool _isModelLoaded = false;
  bool _isEcgModelLoaded = false;
  
  String _lastResult = '';
  double _confidence = 0.0;
  
  String _lastEcgResult = '';
  double _ecgConfidence = 0.0;
  Map<String, double> _ecgProbabilities = {};
  
  // Automatically target local server in development, and Render in production
  static const String apiUrl = kDebugMode
      ? 'http://localhost:8000'
      : 'https://pneumoai-666p.onrender.com';

  Future<void> initializeModel() async {
    try {
      // Check backend health
      final response = await http.get(Uri.parse('$apiUrl/health')).timeout(
        const Duration(seconds: 30),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _isModelLoaded = data['xray_model_loaded'] ?? false;
        _isEcgModelLoaded = data['ecg_model_loaded'] ?? false;
        print('✅ Backend API connected - XRay Loaded: $_isModelLoaded, ECG Loaded: $_isEcgModelLoaded');
      } else {
        _isModelLoaded = false;
        _isEcgModelLoaded = false;
        print('❌ Backend API returned ${response.statusCode}');
      }
      notifyListeners();
    } catch (e) {
      print('❌ Failed to connect to backend: $e');
      _isModelLoaded = false;
      _isEcgModelLoaded = false;
      notifyListeners();
    }
  }

  Future<String> analyzeImage(Uint8List imageBytes, String fileName) async {
    if (!_isModelLoaded) {
      await initializeModel();
    }

    try {
      print('📤 Sending image to backend API...');
      print('   API URL: $apiUrl/predict');
      print('   File name: $fileName');
      print('   File size: ${imageBytes.length} bytes');
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/predict'),
      );
      
      // Determine content type based on file extension
      String contentType = 'image/jpeg'; // default
      if (fileName.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      }
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fileName,
          contentType: http.MediaType.parse(contentType),
        ),
      );
      
      print('   Content-Type: $contentType');

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Received response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _lastResult = data['result'] ?? 'Unknown';
        _confidence = (data['confidence'] ?? 0.0).toDouble();
        
        print('✅ Analysis Successful: $_lastResult ($_confidence%)');
        
        notifyListeners();
        return _lastResult;
      } else {
        _lastResult = 'API Error: ${response.statusCode}';
        _confidence = 0.0;
        print('❌ API Error: ${response.body}');
        notifyListeners();
        return _lastResult;
      }
    } catch (e) {
      print('❌ Error analyzing image: $e');
      _lastResult = 'Analysis Failed: ${e.toString()}';
      _confidence = 0.0;
      notifyListeners();
      return _lastResult;
    }
  }

  Future<String> analyzeEcgImage(Uint8List imageBytes, String fileName) async {
    // Attempt connecting if healthy check hasn't run
    if (!_isEcgModelLoaded) {
      await initializeModel();
    }

    try {
      print('📤 Sending ECG image to backend API...');
      print('   API URL: $apiUrl/predict_ecg');
      print('   File name: $fileName');
      print('   File size: ${imageBytes.length} bytes');
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/predict_ecg'),
      );
      
      // Determine content type
      String contentType = 'image/jpeg';
      if (fileName.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      }
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fileName,
          contentType: http.MediaType.parse(contentType),
        ),
      );

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Received response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _lastEcgResult = data['result'] ?? 'Unknown';
        _ecgConfidence = (data['confidence'] ?? 0.0).toDouble();
        
        // Parse probability distributions
        final rawProbs = data['probabilities'] as Map<String, dynamic>? ?? {};
        _ecgProbabilities = rawProbs.map((key, value) => MapEntry(key, (value ?? 0.0).toDouble()));
        
        print('✅ ECG Analysis Successful: $_lastEcgResult ($_ecgConfidence%)');
        
        notifyListeners();
        return _lastEcgResult;
      } else {
        _lastEcgResult = 'API Error: ${response.statusCode}';
        _ecgConfidence = 0.0;
        _ecgProbabilities = {};
        print('❌ API Error: ${response.body}');
        notifyListeners();
        return _lastEcgResult;
      }
    } catch (e) {
      print('❌ Error analyzing ECG: $e');
      _lastEcgResult = 'Analysis Failed: ${e.toString()}';
      _ecgConfidence = 0.0;
      _ecgProbabilities = {};
      notifyListeners();
      return _lastEcgResult;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Getters
  String get lastResult => _lastResult;
  double get confidence => _confidence;
  bool get isModelLoaded => _isModelLoaded;
  
  String get lastEcgResult => _lastEcgResult;
  double get ecgConfidence => _ecgConfidence;
  bool get isEcgModelLoaded => _isEcgModelLoaded;
  Map<String, double> get ecgProbabilities => _ecgProbabilities;
}
