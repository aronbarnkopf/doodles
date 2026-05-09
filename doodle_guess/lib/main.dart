import 'package:flutter/material.dart';
import 'screens/game_screen.dart';
import 'services/classifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final classifier = Classifier();
  await classifier.load();
  runApp(DoodleGuessApp(classifier: classifier));
}

class DoodleGuessApp extends StatelessWidget {
  const DoodleGuessApp({super.key, required this.classifier});

  final Classifier classifier;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doodle Guess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: GameScreen(classifier: classifier),
    );
  }
}