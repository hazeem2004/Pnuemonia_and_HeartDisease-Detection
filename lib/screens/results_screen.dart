import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'hospital_map_screen.dart';

class ResultsScreen extends StatelessWidget {
  final String result;
  final double confidence;
  final String imagePath;
  final Uint8List? imageBytes;
  final bool isEcg;
  final Map<String, double>? ecgProbabilities;

  const ResultsScreen({
    Key? key,
    required this.result,
    required this.confidence,
    required this.imagePath,
    this.imageBytes,
    this.isEcg = false,
    this.ecgProbabilities,
  }) : super(key: key);

  void _findHospitals(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HospitalMapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check severity levels for dynamic coloring
    final bool isCritical = _isResultCritical();
    final Color themeColor = _getThemeColor();
    final Color cardBgColor = _getCardBgColor();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(isEcg ? 'ECG Diagnostic Report' : 'Lung Diagnostic Report'),
        backgroundColor: themeColor,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildResultCard(isCritical, cardBgColor, themeColor),
            const SizedBox(height: 25),
            _buildImageCard(themeColor),
            const SizedBox(height: 25),
            _buildConfidenceCard(themeColor),
            const SizedBox(height: 25),
            if (isEcg) _buildEcgActionCard(context, themeColor) else ...[
              if (result.toLowerCase().contains('detected') || result.toLowerCase().contains('positive'))
                _buildEmergencyActions(context, 'Pneumonia indicators detected. Please consult a pulmonologist.', Colors.red)
              else
                _buildNormalActions(context, Colors.green),
            ],
            const SizedBox(height: 25),
            _buildDisclaimer(),
          ],
        ),
      ),
    );
  }

  bool _isResultCritical() {
    final lower = result.toLowerCase();
    if (isEcg) {
      return lower.contains('infarction') || lower.contains('abnormal') || lower.contains('mi');
    } else {
      return lower.contains('detected') || lower.contains('positive');
    }
  }

  Color _getThemeColor() {
    final lower = result.toLowerCase();
    if (isEcg) {
      if (lower.contains('infarction') || lower.contains('mi')) {
        return Colors.red.shade900; // Deep emergency red
      }
      if (lower.contains('abnormal')) {
        return Colors.orange.shade800; // Arrhythmia orange
      }
      if (lower.contains('history')) {
        return Colors.purple.shade700; // History purple
      }
      return Colors.green.shade700; // Normal ECG green
    } else {
      return _isResultCritical() ? Colors.red.shade700 : Colors.green.shade700;
    }
  }

  Color _getCardBgColor() {
    final lower = result.toLowerCase();
    if (isEcg) {
      if (lower.contains('infarction') || lower.contains('mi')) {
        return Colors.red.shade50;
      }
      if (lower.contains('abnormal')) {
        return Colors.orange.shade50;
      }
      if (lower.contains('history')) {
        return Colors.purple.shade50;
      }
      return Colors.green.shade50;
    } else {
      return _isResultCritical() ? Colors.red.shade50 : Colors.green.shade50;
    }
  }

  IconData _getResultIcon() {
    final lower = result.toLowerCase();
    if (isEcg) {
      if (lower.contains('infarction') || lower.contains('mi')) {
        return Icons.favorite_rounded;
      }
      if (lower.contains('abnormal')) {
        return Icons.warning_amber_rounded;
      }
      if (lower.contains('history')) {
        return Icons.history_rounded;
      }
      return Icons.check_circle_rounded;
    } else {
      return _isResultCritical() ? Icons.warning_rounded : Icons.check_circle_rounded;
    }
  }

  Widget _buildResultCard(bool isCritical, Color cardBg, Color themeColor) {
    String subtitle = 'No abnormalities detected';
    if (isEcg) {
      final lower = result.toLowerCase();
      if (lower.contains('infarction') || lower.contains('mi')) {
        subtitle = 'CRITICAL: Acute cardiac event pattern detected. Urgent care required.';
      } else if (lower.contains('abnormal')) {
        subtitle = 'WARNING: Non-standard heartbeat / arrhythmia indicators detected.';
      } else if (lower.contains('history')) {
        subtitle = 'INFO: Post-Myocardial Infarction signs detected in trace history.';
      } else {
        subtitle = 'HEALTHY: ECG rhythm analysis registers normal sinus pattern.';
      }
    } else {
      subtitle = isCritical ? 'AI Lung Diagnostic: Pneumonia flags triggered.' : 'AI Lung Diagnostic: Lungs register clear.';
    }

    return Card(
      elevation: 4,
      shadowColor: themeColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: themeColor.withOpacity(0.2), width: 1.5),
      ),
      color: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Icon(
              _getResultIcon(),
              size: 70,
              color: themeColor,
            ),
            const SizedBox(height: 18),
            Text(
              result,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: themeColor,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 15,
                color: themeColor.withOpacity(0.85),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(Color themeColor) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEcg ? 'ECG Waveform Record' : 'Chest X-ray Scan',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: imagePath.isNotEmpty || imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: (kIsWeb && imageBytes != null
                          ? Image.memory(
                              imageBytes!,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(imagePath),
                              fit: BoxFit.cover,
                            )),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 50,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'ECG Simulation Capture',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceCard(Color themeColor) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diagnostic Certainty Metric',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: confidence / 100,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                minHeight: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${confidence.toStringAsFixed(1)}% Match',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                Text(
                  _getConfidenceLabel(confidence),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            // Render detailed multi-class breakdown if we are in ECG mode
            if (isEcg && ecgProbabilities != null && ecgProbabilities!.isNotEmpty) ...[
              const SizedBox(height: 25),
              const Divider(),
              const SizedBox(height: 15),
              const Text(
                'MOSHO-HANN Class Probability Distribution',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 15),
              _buildProbabilityBar('Normal Rhythm', ecgProbabilities!['normal'] ?? 0.0, Colors.green),
              const SizedBox(height: 10),
              _buildProbabilityBar('Abnormal Heartbeat', ecgProbabilities!['abnormal'] ?? 0.0, Colors.orange),
              const SizedBox(height: 10),
              _buildProbabilityBar('Myocardial Infarction', ecgProbabilities!['mi'] ?? 0.0, Colors.red),
              const SizedBox(height: 10),
              _buildProbabilityBar('Post-MI History', ecgProbabilities!['history'] ?? 0.0, Colors.purple),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProbabilityBar(String label, double val, Color col) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
            Text(
              '${val.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 13, color: col, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: val / 100,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(col.withOpacity(0.85)),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  String _getConfidenceLabel(double confidence) {
    if (confidence >= 90) return 'Highly Verified Signature';
    if (confidence >= 75) return 'Strong AI Correspondence';
    if (confidence >= 60) return 'Moderate Agreement';
    return 'Secondary Screening Threshold';
  }

  Widget _buildEcgActionCard(BuildContext context, Color themeColor) {
    final lower = result.toLowerCase();
    if (lower.contains('infarction') || lower.contains('mi')) {
      return _buildEmergencyActions(
        context,
        'ACUTE INFARCTION PATTERN DETECTED. Place the patient at rest, administer cardiac first aid, and seek immediately closest cardiology emergency care.',
        themeColor,
      );
    }
    if (lower.contains('abnormal')) {
      return _buildEmergencyActions(
        context,
        'ARRHYTHMIA DETECTED. Non-standard ventricular or atrial signals require prompt cardiological review.',
        themeColor,
      );
    }
    
    // Normal ECG Action View
    return _buildNormalActions(context, themeColor);
  }

  Widget _buildEmergencyActions(BuildContext context, String instructions, Color themeColor) {
    return Column(
      children: [
        Card(
          elevation: 2,
          shadowColor: themeColor.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: themeColor.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: themeColor, size: 28),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    instructions,
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _findHospitals(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.local_hospital_rounded, color: Colors.white),
            label: const Text(
              'Route to Closest Medical Center',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalActions(BuildContext context, Color themeColor) {
    return Column(
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommended Preventive Health Tips',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 15),
                _buildHealthTip('Practice daily active cardio exercise (30 mins).'),
                _buildHealthTip('Maintain a balanced diet, limiting sodium and saturated fats.'),
                _buildHealthTip('Ensure standard medical annual checkups and routine testing.'),
                _buildHealthTip('Reduce systemic stressors and prioritize standard sleep cycles.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            label: const Text(
              'Acknowledge Diagnostic',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthTip(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        'Note: This analysis report is generated by a clinical IoMT machine learning network and is provided for preliminary diagnostic guidance. Always confirm results with board-certified healthcare professionals before diagnostic interventions.',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
