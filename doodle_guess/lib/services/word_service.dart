import 'dart:math';

class WordService {
  static const List<String> _words = [
    'apple', 'banana', 'bicycle', 
    'car', 'cat', 'chair', 'clock',
    'cloud', 'crown', 'fish',
    'flower', 'house', 'snake', 
    'spider', 'star', 'tree',
    'umbrella',
  ];

  static String getRandomWord() {
    return _words[Random().nextInt(_words.length)];
  }
}