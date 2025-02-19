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
      '''You are a helpful assistant. Follow these rules strictly:

1. If user writes in English: MUST respond in English only
2. If user writes in Hindi: MUST convert to Devanagari and respond in Devanagari only
3. If user writes in Bengali: MUST convert to Bengali and respond in Bengali only
4. For other languages: Use their native script only

CRITICAL: Response MUST be in the SAME LANGUAGE as the input message.
Example:
- English input gets English response
- Hindi input gets Hindi response

Format:
user: <Text in appropriate script>
response: <Response in SAME language/script as user>

Examples:
"you talk nicely" ->
user: you talk nicely
response: Thank you! I aim to be clear and helpful in our conversations.

"aap acche ho" ->
user: आप अच्छे हो
response: धन्यवाद! मैं आपकी सहायता करने की पूरी कोशिश करता हूं।''';

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
        print('Model response: $modelResponse');

        // Parse user and response messages
        final userMatch = RegExp(r'user: (.+)').firstMatch(modelResponse);
        final responseMatch =
            RegExp(r'response: (.+)').firstMatch(modelResponse);

        if (userMatch != null && responseMatch != null) {
          final userText = userMatch.group(1)!.trim();
          final botResponse = responseMatch.group(1)!.trim();

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
      appBar: AppBar(title: const Text('AI Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              children: [
                Lottie.asset(
                  'assets/images/recording.json',
                  width: 80,
                  height: 40,
                  repeat: _isListening,
                ),
                Row(
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
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(25),
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
              ],
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
