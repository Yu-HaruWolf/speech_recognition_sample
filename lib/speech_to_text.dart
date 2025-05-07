import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class SpeechToText extends StatefulWidget {
  @override
  _SpeechToTextState createState() => _SpeechToTextState();
}

class _SpeechToTextState extends State<SpeechToText> {
  int _recordDuration = 0;
  Timer? _timer;
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String _transcription = '';
  String _filePath = '';
  final String apiKey = dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? '';
  dynamic previousResult;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Permission.microphone.request();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    _filePath = '${dir.path}/speech.flac';

    await _audioRecorder.start(
      // RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000),
      RecordConfig(encoder: AudioEncoder.flac, numChannels: 1),
      path: _filePath,
    );
    setState(() {
      _isRecording = true;
      _recordDuration = 0;
    });
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration++;
        if (_recordDuration >= 59) {
          _stopRecording();
        }
      });
    });
    print('録音開始: $_filePath');
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    _timer?.cancel();
    setState(() => _isRecording = false);
    print('録音終了');

    _sendToSpeechToText();
  }

  Future<void> _sendToSpeechToText() async {
    if (apiKey.isEmpty) {
      setState(() => _transcription = 'APIキーが設定されていません。');
      return;
    }

    final audioFile = File(_filePath);
    final audioContent = base64Encode(audioFile.readAsBytesSync());

    final url = Uri.parse(
      'https://speech.googleapis.com/v1/speech:recognize?key=$apiKey',
    );
    final headers = {'Content-Type': 'application/json'};
    final requestBody = jsonEncode({
      'config': {
        'encoding': 'FLAC',
        'languageCode': 'en-US',
        'diarizationConfig': {'enableSpeakerDiarization': true},
        'model': 'medical_conversation',
      },
      'audio': {'content': audioContent},
    });

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        previousResult = jsonResponse;
        print(jsonResponse);
        if (jsonResponse.containsKey('results')) {
          setState(
            () =>
                _transcription =
                    jsonResponse['results'][0]['alternatives'][0]['transcript'],
          );
        } else {
          setState(() => _transcription = '文字起こし結果が見つかりませんでした。');
        }
      } else {
        setState(
          () =>
              _transcription =
                  'エラーが発生しました: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      setState(() => _transcription = 'エラーが発生しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('音声認識アプリ')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                Text(
                  _isRecording
                      ? '録音中: ${_recordDuration}秒'
                      : '録音停止: ${_recordDuration}秒',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  child: Text(_isRecording ? '停止' : '録画開始'),
                ),
                SizedBox(height: 20),
                Text('認識結果:', style: TextStyle(fontSize: 16)),
                SizedBox(height: 10),
                Text(_transcription, style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
