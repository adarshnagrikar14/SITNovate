import 'dart:convert';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

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

class CharacterChatScreen extends StatefulWidget {
  final String title;
  final String character;
  final String personality;
  final Color primaryColor;
  final IconData characterIcon;

  const CharacterChatScreen({
    super.key,
    required this.title,
    required this.character,
    required this.personality,
    required this.primaryColor,
    required this.characterIcon,
  });

  @override
  State<CharacterChatScreen> createState() => _CharacterChatScreenState();
}

class _CharacterChatScreenState extends State<CharacterChatScreen> {
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();

  String get _systemPrompt =>
      '''You are ${widget.character}. ${widget.personality}
You MUST stay in character at all times and only respond about topics related to your character.

IMPORTANT: Respond ONLY with a valid JSON object, no markdown, no code blocks, no additional text.
Language rules:
- English: Respond in English
- Hindi: Convert to Devanagari and respond in Devanagari
- Bengali: Convert to Bengali and respond in Bengali
- Other languages: Use their native script

JSON format must be:
{
  "user_message": {
    "text": "<original text>",
    "script": "<converted text in appropriate script>"
  },
  "response": "<response in same script as user_message.script while maintaining character personality>"
}

Response MUST be in the SAME LANGUAGE as the input message while maintaining character personality.''';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' && mounted) {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
      );
      if (available && mounted) {
        setState(() => _isListening = true);
        _speech.listen(onResult: _onSpeechResult);
      }
    } else {
      if (mounted) {
        setState(() => _isListening = false);
      }
      _speech.stop();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) async {
    if (result.finalResult) {
      _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
        await _sendToGemini(result.recognizedWords);
      }
    }
  }

  Future<void> _sendToGemini(String text) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent');

    try {
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
          _scrollToBottom();
          _textController.clear();
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        toolbarHeight: 78,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
              ),
            ),
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(widget.characterIcon, color: Colors.white),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title[0].toUpperCase() + widget.title.substring(1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.character[0].toUpperCase() +
                        widget.character.substring(1),
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        titleSpacing: 8,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 100,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _buildMessageBubble(_messages[index]),
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
                        hintText: 'Message ${widget.title}...',
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
                          : widget.primaryColor,
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
                      color: widget.primaryColor,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: widget.primaryColor.withOpacity(0.1),
            child: Icon(
              widget.characterIcon,
              size: 40,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Chat with ${widget.title[0].toUpperCase() + widget.title.substring(1)}',
            style: const TextStyle(
              fontSize: 20,
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
              widget.personality,
              style: TextStyle(color: widget.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: CustomPaint(
        painter: BubblePainter(
          isUser: message.isUser,
          color: message.isUser ? widget.primaryColor : Colors.grey[200]!,
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: message.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
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

  @override
  void dispose() {
    _textController.dispose();
    _speech.cancel();
    _scrollController.dispose();
    super.dispose();
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
