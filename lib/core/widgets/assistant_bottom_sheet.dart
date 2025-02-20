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
import 'package:flutter_tts/flutter_tts.dart';

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
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  String get _systemPrompt {
    if (_selectedCharacter == null) return '';
    return ApiKeys.systemPrompt
        .replaceAll('{subtitle}', _selectedCharacter!.subtitle)
        .replaceAll('{description}', _selectedCharacter!.description)
        .replaceAll('{personality}', _selectedCharacter!.personality)
        .replaceAll('{title}', _selectedCharacter!.title);
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
    _loadCharacters();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("en-US");

    // Default voice settings
    await _flutterTts.setSpeechRate(0.6);
    await _flutterTts.setVolume(1.0);

    // Get available voices
    final List<dynamic>? voices = await _flutterTts.getVoices;
    if (voices != null) {
      print('Available voices: $voices');
    }

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _setVoiceForCharacter(CharacterModel character) async {
    switch (character.title.toLowerCase()) {
      case 'grumpy banker':
        await _flutterTts.setLanguage("en-US");
        await _flutterTts
            .setVoice({"name": "en-us-x-sfb-local", "locale": "en-US"});
        await _flutterTts.setPitch(0.9);
        await _flutterTts.setSpeechRate(0.6);
        break;
      case 'iron man':
        await _flutterTts.setLanguage("en-US");
        await _flutterTts
            .setVoice({"name": "en-us-x-sfb-local", "locale": "en-US"});
        await _flutterTts.setPitch(1.1);
        await _flutterTts.setSpeechRate(0.55);
        break;
      case 'harvey spectre':
        await _flutterTts.setLanguage("en-US");
        await _flutterTts
            .setVoice({"name": "en-us-x-sfb-local", "locale": "en-US"});
        await _flutterTts.setPitch(0.95);
        await _flutterTts.setSpeechRate(0.5);
        break;
      case 'jethalal':
        await _flutterTts.setLanguage("hi-IN");
        await _flutterTts
            .setVoice({"name": "hi-in-x-hid-local", "locale": "hi-IN"});
        await _flutterTts.setPitch(1.0);
        await _flutterTts.setSpeechRate(0.5);
        break;
      default:
        await _flutterTts.setLanguage("en-US");
        await _flutterTts
            .setVoice({"name": "en-us-x-tpf-local", "locale": "en-US"});
        await _flutterTts.setPitch(1.0);
        await _flutterTts.setSpeechRate(0.5);
    }
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    // Set voice for current character before speaking
    if (_selectedCharacter != null) {
      await _setVoiceForCharacter(_selectedCharacter!);
    }

    setState(() => _isSpeaking = true);
    await _flutterTts.speak(text);
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
    _flutterTts.stop();
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
      print('Result: ${result.recognizedWords}');
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

          print('Parsed response: $parsedResponse');
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
          _scrollToBottom();

          // Speak the response
          await _speak(botResponse);
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

  Widget _buildCharacterSelector() {
    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _selectedCharacter?.color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: _selectedCharacter?.color ?? Colors.grey[200]!,
            width: 1,
          ),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _characters.length,
        itemBuilder: (context, index) {
          final character = _characters[index];
          final isSelected = character == _selectedCharacter;

          return GestureDetector(
            onTap: () async {
              setState(() => _selectedCharacter = character);
              // Update voice when character is selected
              await _setVoiceForCharacter(character);
            },
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? character.color.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? character.color
                      : Colors.grey.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: character.color.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isSelected
                        ? character.color
                        : character.color.withOpacity(0.1),
                    child: Icon(
                      character.icon,
                      color: isSelected ? Colors.white : character.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    character.title[0].toUpperCase() +
                        character.title.substring(1),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? character.color : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _selectedCharacter?.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    _buildCharacterSelector(),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _messages.isEmpty ? 1 : _messages.length,
                        itemBuilder: (context, index) {
                          if (_messages.isEmpty) {
                            return _buildEmptyState();
                          }
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            _selectedCharacter?.color.withOpacity(0.9) ??
                                Colors.blue.shade500,
                            _selectedCharacter?.color.withOpacity(0.7) ??
                                Colors.blue.shade400,
                            _selectedCharacter?.color.withOpacity(0.5) ??
                                Colors.blue.shade300,
                            _selectedCharacter?.color.withOpacity(0.3) ??
                                Colors.blue.shade200,
                            _selectedCharacter?.color.withOpacity(0.1) ??
                                Colors.blue.shade100,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
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
              );
            },
          ),
          if (_isListening || _isSpeaking)
            Positioned(
              left: 100,
              right: 100,
              bottom: 100,
              child: Lottie.asset(
                _isListening
                    ? 'assets/images/recording.json'
                    : 'assets/images/recording.json',
                width: 60,
                height: 60,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          CircleAvatar(
            radius: 40,
            backgroundColor: _selectedCharacter?.color.withOpacity(0.1),
            child: Icon(
              _selectedCharacter?.icon ?? Icons.chat,
              size: 40,
              color: _selectedCharacter?.color,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Chat with ${_selectedCharacter?.title ?? "Assistant"}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedCharacter?.description ?? "",
              style: TextStyle(
                color: _selectedCharacter?.color ?? Colors.grey[600],
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => !message.isUser ? _speak(message.text) : null,
        child: CustomPaint(
          painter: BubblePainter(
            isUser: message.isUser,
            color: message.isUser
                ? _selectedCharacter?.color ?? Colors.blue
                : Colors.grey[200]!,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: EdgeInsets.only(
              bottom: 12,
              right: message.isUser ? 8 : 0,
              left: message.isUser ? 0 : 8,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: message.isUser ? Colors.white : Colors.black87,
                    fontSize: 13,
                  ),
                ),
                if (message.isUser && message.originalText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    message.originalText!,
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black54,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
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
