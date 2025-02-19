import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();
  final String _systemPrompt =
      '''You are a helpful assistant. You MUST follow these rules:

IMPORTANT: Respond ONLY with a valid JSON object, no markdown, no code blocks, no additional text.

JSON format must be:
{
  "user_message": {
    "text": "<original text>",
    "script": "<converted text in appropriate script>"
  },
  "response": "<response in same script as user_message.script>"
}

Language rules:
- English: Respond in English
- Hindi: Convert to Devanagari and respond in Devanagari
- Bengali: Convert to Bengali and respond in Bengali
- Other languages: Use their native script

Response MUST be in the SAME LANGUAGE as the input message.''';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: _onSpeechResult);
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) async {
    if (result.finalResult) {
      _speech.stop();
      setState(() => _isListening = false);
      await _sendToGemini(result.recognizedWords);
    }
  }

  Future<void> _sendToGemini(String text) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent');

    try {
      print('Sending text: $text');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': 'AIzaSyBrrZV1jVomWwNotN-5cehcN7aK7f2skDM',
        },
        body: json.encode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''$_systemPrompt

User Message: $text
Assistant: '''
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String modelResponse =
            data['candidates'][0]['content']['parts'][0]['text'];

        try {
          // Clean the response if it contains markdown markers
          modelResponse = modelResponse
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();

          print('Cleaned response: $modelResponse');

          final parsedResponse = json.decode(modelResponse);
          final userText = parsedResponse['user_message']['script'];
          final botResponse = parsedResponse['response'];

          setState(() {
            _messages.add(Message(
              text: userText,
              isUser: true,
              timestamp: DateTime.now(),
            ));
            _messages.add(Message(
              text: botResponse,
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          _scrollToBottom();
          _textController.clear();
        } catch (e) {
          print('Error parsing response: $e');
          print('Raw response: $modelResponse');
        }
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Chat'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/splash.jpg',
                              width: 80,
                              height: 80,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Start a conversation!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Try asking:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  SizedBox(height: 8),
                                  Text('• What can you help me with?'),
                                  Text('• Tell me a joke'),
                                  Text('• नमस्ते, कैसे हो आप?'),
                                  Text('• তুমি কেমন আছো?'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 100,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return Align(
                            alignment: message.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: message.isUser
                                    ? Colors.blue
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                message.text,
                                style: TextStyle(
                                  color: message.isUser
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _sendToGemini(text);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.red.withOpacity(0.8)
                          : Colors.blue,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                spreadRadius: 4,
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: Colors.white,
                      ),
                      onPressed: _toggleListening,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_textController.text.trim().isNotEmpty) {
                          _sendToGemini(_textController.text);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isListening)
            Positioned(
              left: 100,
              right: 100,
              bottom: 100,
              child: Lottie.asset(
                'assets/images/recording.json',
                width: 60,
                height: 60,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _speech.stop();
    _scrollController.dispose();
    super.dispose();
  }
}
