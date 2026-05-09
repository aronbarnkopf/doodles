import 'dart:async';
import '../services/classifier.dart';
import 'package:flutter/material.dart';
import '../models/drawing_point.dart';
import '../widgets/drawing_canvas.dart';
import '../services/word_service.dart';
import 'package:screenshot/screenshot.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final Classifier classifier;
  const GameScreen({super.key, required this.classifier});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  static const int _totalSeconds = 30;
  bool _isClassifying = false;

  late String _currentWord;
  List<DrawingPoint?> _points = [];
  int _secondsLeft = _totalSeconds;
  Timer? _timer;
  bool _submitted = false;

  // Tool state
  Color _selectedColor = Colors.black;
  double _strokeWidth = 30.0;

  @override
  void initState() {
    super.initState();
    _currentWord = WordService.getRandomWord();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        _handleTimeUp();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _handleTimeUp() {
    if (!_submitted) {
      setState(() => _submitted = true);
      _showTimeUpDialog();
    }
  }

  Future<void> _handleSubmit() async {
    if (_submitted) return;
    _timer?.cancel();
    setState(() => _submitted = true);

    final imageBytes = await _screenshotController.capture(pixelRatio: 1.0);
    if (imageBytes == null) return;

    await widget.classifier.debugPreprocess(imageBytes);

    setState(() => _isClassifying = true);

    // Decode image on main thread (dart:ui requirement)
    final pixels = await widget.classifier.preprocessImage(imageBytes);

    // Run inference on background isolate
    final results = widget.classifier.classifyPixels(pixels);

    setState(() => _isClassifying = false);

    debugPrint('Top predictions:');
    for (final r in results) {
      debugPrint('  ${r.key}: ${(r.value * 100).toStringAsFixed(1)}%');
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            targetWord: _currentWord,
            predictions: results,
            drawingBytes: imageBytes,
            onPlayAgain: () {
              Navigator.pop(context);
              _newRound();
            },
          ),
        ),
      );
    }
  }


  void _newRound() {
    _timer?.cancel();
    setState(() {
      _currentWord = WordService.getRandomWord();
      _points = [];
      _secondsLeft = _totalSeconds;
      _submitted = false;
    });
    _startTimer();
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Time's up!"),
        content: Text('The word was "$_currentWord".'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _newRound();
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Color get _timerColor {
    if (_secondsLeft > 15) return Colors.green;
    if (_secondsLeft > 8) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text('Doodle Guess'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New word',
            onPressed: _newRound,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildToolbar(),
          _buildCanvas(),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.deepPurple.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Draw this word:',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              Text(
                _currentWord.toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          // Timer
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _timerColor.withOpacity(0.15),
              border: Border.all(color: _timerColor, width: 2.5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$_secondsLeft',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _timerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: _selectedColor == Colors.black
                  ? Colors.deepPurple
                  : Colors.black45,
            ),
            tooltip: 'Pen',
            onPressed: () => setState(() => _selectedColor = Colors.black),
          ),
          SizedBox(
            width: 120,
            child: Slider(
              value: _strokeWidth,
              min: 25,
              max: 45,
              activeColor: Colors.black,
              onChanged: (v) => setState(() => _strokeWidth = v),
            ),
          ),

          const Spacer(),

          // Eraser
          IconButton(
            icon: Icon(
              Icons.auto_fix_normal,
              color: _selectedColor == Colors.white
                  ? Colors.deepPurple
                  : Colors.black45,
            ),
            tooltip: 'Eraser',
            onPressed: () => setState(() => _selectedColor = Colors.white),
          ),

          // Clear
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black45),
            tooltip: 'Clear',
            onPressed: () => setState(() {
              _points = [];
              _selectedColor = Colors.black;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Screenshot(
              controller: _screenshotController,
              child: ColoredBox(          // 👈 guaranteed white, no transparency
                color: Colors.white,
                child: DrawingCanvas(
                  selectedColor: _selectedColor,
                  strokeWidth: _strokeWidth,
                  points: _points,
                  onPointsChanged: (updated) =>
                      setState(() => _points = updated),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: (_submitted || _isClassifying) ? null : () => _handleSubmit(),
          icon: _isClassifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send),
          label: Text(
            _isClassifying ? 'Analysing...' : 'Submit Drawing',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
