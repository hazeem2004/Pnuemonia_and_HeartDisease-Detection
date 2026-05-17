import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart';
import 'results_screen.dart';
import '../services/ai_service.dart';

class EcgScreen extends StatefulWidget {
  const EcgScreen({Key? key}) : super(key: key);

  @override
  _EcgScreenState createState() => _EcgScreenState();
}

class _EcgScreenState extends State<EcgScreen> {
  File? _selectedImage;
  XFile? _selectedXFile;
  Uint8List? _selectedImageBytes;
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedXFile = pickedFile;
          if (!kIsWeb) {
            _selectedImage = File(pickedFile.path);
          } else {
            _selectedImage = null;
          }
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      print('Error picking ECG image: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImageBytes == null && _selectedXFile == null) {
      _showSnackBar('Please select an ECG image first');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final aiService = Provider.of<AIService>(context, listen: false);
      final bytes = _selectedImageBytes ?? await _selectedXFile!.readAsBytes();
      final fileName = _selectedXFile?.name ?? 'ecg.jpg';

      final result = await aiService.analyzeEcgImage(bytes, fileName);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            result: result,
            confidence: aiService.ecgConfidence,
            imagePath: kIsWeb ? '' : (_selectedXFile?.path ?? ''),
            imageBytes: _selectedImageBytes,
            isEcg: true,
            ecgProbabilities: aiService.ecgProbabilities,
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Error analyzing ECG image: $e');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cardiac Diagnostics'),
        backgroundColor: Colors.red.shade700,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            _buildImageSelector(),
            const SizedBox(height: 30),
            _buildActionButtons(),
            const SizedBox(height: 40),
            _buildQuickStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cardiac Rhythm Scanner',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Upload an ECG printout or waveform capture for advanced InceptionV3 + WSO-LDA + HANN cardiac evaluation.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildImageSelector() {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.gallery),
      child: DottedBorder(
        color: Colors.red.shade300,
        dashPattern: const [8, 4],
        strokeWidth: 2,
        borderType: BorderType.RRect,
        radius: const Radius.circular(20),
        child: Container(
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: (_selectedImage == null && _selectedImageBytes == null)
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 60,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tap to upload ECG waveform',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Supported formats: JPG, PNG',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: kIsWeb
                      ? (_selectedImageBytes != null
                          ? Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 60,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ))
                      : Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text(
                  'Take Photo',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: const Text(
                  'From Gallery',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isAnalyzing ? null : _analyzeImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.favorite, color: Colors.white),
            label: Text(
              _isAnalyzing ? 'Running Spotted Hyena Neural Scan...' : 'Start ECG Diagnosis',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IoMT Diagnostic Guidelines',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade800,
          ),
        ),
        const SizedBox(height: 15),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoItem(
                  Icons.favorite_outline,
                  'Detects Normal Rhythm, Abnormal Heartbeats, Myocardial Infarctions, and Post-MI History.',
                ),
                const SizedBox(height: 15),
                _buildInfoItem(
                  Icons.security,
                  'Trained with MOSHO (Multi-Objective Spotted Hyena Optimization) to minimize False Negatives.',
                ),
                const SizedBox(height: 15),
                _buildInfoItem(
                  Icons.report_problem_outlined,
                  'Cardiac diagnostics require swift consultation. Seek emergency services for acute symptoms.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.red.shade700, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
