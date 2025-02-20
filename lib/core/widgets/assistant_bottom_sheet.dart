import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sybot/core/constants/api_keys.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:sybot/features/character_bot/models/character_model.dart';
import 'package:sybot/features/character_bot/services/character_service.dart';

class Message {
  final String text;
  final String? originalText;
  final bool isUser;
  final DateTime timestamp;

  Message({
    required this.text,
    this.originalText,
    required this.isUser,
    required this.timestamp,
  });
}

class AssistantBottomSheet extends StatefulWidget {
  const AssistantBottomSheet({super.key});

  @override
  State<AssistantBottomSheet> createState() => _AssistantBottomSheetState();
}

class _AssistantBottomSheetState extends State<AssistantBottomSheet> {
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  late CharacterModel? _selectedCharacter;
  List<CharacterModel> _characters = [];
  bool _isLoading = true;

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
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final service = CharacterService(prefs);
      _characters = await service.getAllCharacters();
      if (_characters.isNotEmpty) {
        _selectedCharacter = _characters.first;
      }
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading characters: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            _isListening = false;
            setState(() {});
          }
        },
        onError: (error) {
          _isListening = false;
          setState(() {});
        },
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
      _scrollToBottom();
    }
  }

  Future<void> _sendToGemini(String text) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-thinking-exp-01-21:generateContent');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': ApiKeys.geminiApiKey,
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
          modelResponse = modelResponse
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();

          final parsedResponse = json.decode(modelResponse);
          final userText = parsedResponse['user_message']['script'];
          final originalText = parsedResponse['user_message']['text'];
          final botResponse = parsedResponse['response'];

          setState(() {
            _messages.add(Message(
              text: userText,
              originalText: originalText,
              isUser: true,
              timestamp: DateTime.now(),
            ));
            _messages.add(Message(
              text: botResponse,
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
        } catch (e) {
          print('Error parsing response: $e');
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_characters.isEmpty) {
      return const Center(child: Text('No characters available'));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            _selectedCharacter?.color.withOpacity(0.1),
                        child: Icon(
                          _selectedCharacter?.icon ?? Icons.assistant,
                          color: _selectedCharacter?.color ?? Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<CharacterModel>(
                        value: _selectedCharacter,
                        items: _characters.map((character) {
                          return DropdownMenuItem(
                            value: character,
                            child: Text(
                              character.title[0].toUpperCase() +
                                  character.title.substring(1),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (CharacterModel? value) {
                          if (value != null) {
                            setState(() => _selectedCharacter = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
                  ),
                  Column(
                    children: [
                      Lottie.asset(
                        'assets/images/recording.json',
                        width: 100,
                        height: 60,
                        repeat: _isListening,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _selectedCharacter?.color.withOpacity(0.8) ??
                                  Colors.blue.shade500,
                              _selectedCharacter?.color.withOpacity(0.6) ??
                                  Colors.blue.shade400,
                              _selectedCharacter?.color.withOpacity(0.4) ??
                                  Colors.blue.shade300,
                              _selectedCharacter?.color.withOpacity(0.2) ??
                                  Colors.blue.shade100,
                              Colors.white,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: _toggleListening,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: CustomPaint(
        painter: BubblePainter(
          isUser: message.isUser,
          color: message.isUser ? Colors.blue : Colors.grey[200]!,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: EdgeInsets.only(
            bottom: 8,
            right: message.isUser ? 8 : 0,
            left: message.isUser ? 0 : 8,
          ),
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: 10,
          ),
          child: Column(
            crossAxisAlignment: message.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black,
                ),
              ),
              if (message.isUser && message.originalText != null)
                Text(
                  message.originalText!,
                  style: TextStyle(
                    color: message.isUser
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BubblePainter extends CustomPainter {
  final bool isUser;
  final Color color;

  BubblePainter({required this.isUser, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const radius = 20.0;
    const smallTail = 8.0;
    const tailWidth = 8.0;

    if (isUser) {
      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height - smallTail),
        const Radius.circular(radius),
      ));

      final tailCenter = size.width - 24.0;
      path.moveTo(tailCenter - tailWidth / 2, size.height - smallTail);
      path.lineTo(tailCenter + 4, size.height);
      path.lineTo(tailCenter + tailWidth / 2, size.height - smallTail);
      path.close();
    } else {
      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height - smallTail),
        const Radius.circular(radius),
      ));

      const tailCenter = 24.0;
      path.moveTo(tailCenter - tailWidth / 2, size.height - smallTail);
      path.lineTo(tailCenter - 4, size.height);
      path.lineTo(tailCenter + tailWidth / 2, size.height - smallTail);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
