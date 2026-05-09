import 'dart:typed_data';
import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final String targetWord;
  final List<MapEntry<String, double>> predictions;
  final Uint8List drawingBytes;
  final VoidCallback onPlayAgain;

  const ResultScreen({
    super.key,
    required this.targetWord,
    required this.predictions,
    required this.drawingBytes,
    required this.onPlayAgain,
  });

  bool get _matched =>
      predictions.any((e) => e.key.toLowerCase() == targetWord.toLowerCase());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _matched ? const Color(0xFFF0FFF4) : const Color(0xFFFFF0F0),
      appBar: AppBar(
        backgroundColor: _matched ? Colors.green : Colors.redAccent,
        foregroundColor: Colors.white,
        title: Text(_matched ? '🎉 Nice one!' : '❌ Not quite!'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildResultBanner(),
              const SizedBox(height: 20),
              _buildDrawingPreview(),
              const SizedBox(height: 20),
              _buildPredictionsList(),
              const SizedBox(height: 24),
              _buildPlayAgainButton(context),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: _matched ? Colors.green : Colors.redAccent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            _matched ? '✅ Correct!' : '😅 The AI couldn\'t guess it!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The word was "${targetWord.toUpperCase()}"',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your drawing:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Center(
          child: Builder(
            builder: (context) {
              final size = (MediaQuery.of(context).size.width *0.5).clamp(120.0, 200.0);
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(drawingBytes, fit: BoxFit.contain),
                ),
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI\'s top guesses:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ...predictions.asMap().entries.map((entry) {
          final index = entry.key;
          final pred = entry.value;
          final isMatch =
              pred.key.toLowerCase() == targetWord.toLowerCase();
          final percent = pred.value * 100;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMatch
                  ? Colors.green.shade50
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isMatch ? Colors.green : Colors.grey.shade200,
                width: isMatch ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isMatch
                        ? Colors.green
                        : Colors.deepPurple.shade100,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isMatch ? Colors.white : Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Label
                Expanded(
                  child: Text(
                    pred.key,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isMatch ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                ),
                // Confidence bar + percent
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        color: isMatch ? Colors.green : Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 80,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pred.value.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isMatch ? Colors.green : Colors.deepPurple,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlayAgainButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPlayAgain,
        icon: const Icon(Icons.replay),
        label: const Text(
          'Play Again',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _matched ? Colors.green : Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}