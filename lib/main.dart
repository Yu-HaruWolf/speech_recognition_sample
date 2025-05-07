import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'speech_to_text.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  runApp(const AudioRecordingApp());
}

class AudioRecordingApp extends StatelessWidget {
  const AudioRecordingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech Recognition Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SpeechToText(),
    );
  }
}
