// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'package:sybot/core/constants/api_constants.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class Message {
  final String text;
  final String? videoPath;
  final bool isUser;
  final DateTime timestamp;

  Message({
    required this.text,
    this.videoPath,
    required this.isUser,
    required this.timestamp,
  });
}

class LearningBotScreen extends StatefulWidget {
  const LearningBotScreen({super.key});

  @override
  State<LearningBotScreen> createState() => _LearningBotScreenState();
}

class _LearningBotScreenState extends State<LearningBotScreen> {
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isLoading = false;
  final TextEditingController _textController = TextEditingController();
  final Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _generateAnimation(String prompt) async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.animationEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        // Save video file
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final videoPath = '${directory.path}/video_$timestamp.mp4';

        File videoFile = File(videoPath);
        await videoFile.writeAsBytes(response.bodyBytes);

        // Initialize video controller
        final controller = VideoPlayerController.file(videoFile);
        await controller.initialize();
        // Add completion listener
        controller.addListener(() {
          if (controller.value.position >= controller.value.duration) {
            setState(() {}); // Rebuild UI when video ends
          }
        });
        _videoControllers[videoPath] = controller;

        setState(() {
          _messages.add(Message(
            text: prompt,
            isUser: true,
            timestamp: DateTime.now(),
          ));
          _messages.add(Message(
            text: 'Generated animation for: $prompt',
            videoPath: videoPath,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
        _textController.clear();
      }
    } on SocketException catch (e) {
      print('Network error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cannot connect to server. Check if server is running and IP is correct'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to generate animation'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
        await _generateAnimation(result.recognizedWords);
      }
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

  Widget _buildMessageBubble(Message message) {
    if (message.videoPath != null &&
        _videoControllers.containsKey(message.videoPath)) {
      final controller = _videoControllers[message.videoPath]!;

      // Add listener to detect video completion
      controller.addListener(() {
        final position = controller.value.position;
        final duration = controller.value.duration;
        if (position >= duration) {
          setState(() {}); // Trigger rebuild to show replay button
        }
      });

      // Check if video has finished
      bool isFinished = controller.value.position >= controller.value.duration;
      bool hideOverlay = controller.value.isPlaying && !isFinished;

      return Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Bubble with text description.
            CustomPaint(
              painter: BubblePainter(
                isUser: message.isUser,
                color: message.isUser ? Colors.blue : Colors.grey[200]!,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                margin: EdgeInsets.only(
                  bottom: message.videoPath != null ? 8 : 16,
                  right: message.isUser ? 8 : 0,
                  left: message.isUser ? 0 : 8,
                ),
                padding: const EdgeInsets.all(12),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: message.isUser ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            // Video container with rounded corners.
            Container(
              width: MediaQuery.of(context).size.width * 0.75,
              margin: const EdgeInsets.only(bottom: 16, left: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(controller),
                      // Show controls based on video state
                      if (!hideOverlay)
                        Container(
                          color: Colors.black26,
                          child: Center(
                            child: IconButton(
                              iconSize: 48,
                              icon: Icon(
                                isFinished
                                    ? Icons.replay
                                    : Icons.play_circle_filled,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (isFinished) {
                                  controller.seekTo(Duration.zero);
                                }
                                controller.play();
                              },
                            ),
                          ),
                        ),
                      // Progress bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          colors: const VideoProgressColors(
                            playedColor: Colors.blue,
                            bufferedColor: Colors.grey,
                            backgroundColor: Colors.black12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Text-only message bubble.
      return Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
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
              bottom: 16,
              right: message.isUser ? 8 : 0,
              left: message.isUser ? 0 : 8,
            ),
            padding: const EdgeInsets.all(12),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Learning Bot'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
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
                                'Ask me to explain any math concept!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
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
                                    Text('• Explain area of circle'),
                                    Text('• Show me pythagoras theorem'),
                                    Text('• Demonstrate linear equations'),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                        hintText: 'Ask about any math concept...',
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
                          _generateAnimation(text);
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
                          _generateAnimation(_textController.text);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
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
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
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
