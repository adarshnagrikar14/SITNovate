import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sybot/features/character_bot/models/character_model.dart';
import 'package:sybot/features/character_bot/services/character_service.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _personalityController = TextEditingController();
  final _descriptionController = TextEditingController();
  IconData _selectedIcon = Icons.person;
  Color _selectedColor = Colors.blue;

  final List<IconData> _icons = [
    Icons.person,
    Icons.account_balance,
    Icons.movie,
    Icons.medical_services,
    Icons.school,
    Icons.restaurant,
    Icons.psychology,
    Icons.elderly,
    Icons.sports_esports,
    Icons.code,
    Icons.music_note,
    Icons.palette,
  ];

  final List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.brown,
    Colors.cyan,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Character'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Character Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subtitleController,
              decoration: const InputDecoration(
                labelText: 'Short Description',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _personalityController,
              decoration: const InputDecoration(
                labelText: 'Personality Traits (separate with •)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Character Background',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const Text('Select Icon'),
            const SizedBox(height: 8),
            Container(
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: _icons.length,
                itemBuilder: (context, index) {
                  final icon = _icons[index];
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _selectedIcon == icon
                            ? _selectedColor.withOpacity(0.1)
                            : Colors.transparent,
                        border: Border.all(
                          color: _selectedIcon == icon
                              ? _selectedColor
                              : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: _selectedIcon == icon
                            ? _selectedColor
                            : Colors.grey[600],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Color'),
            const SizedBox(height: 8),
            Container(
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: _colors.length,
                itemBuilder: (context, index) {
                  final color = _colors[index];
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(
                          color: _selectedColor == color
                              ? Colors.black
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saveCharacter,
              child: const Text('Create Character'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCharacter() async {
    if (_formKey.currentState?.validate() ?? false) {
      final character = CharacterModel(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text,
        subtitle: _subtitleController.text,
        personality: _personalityController.text,
        description: _descriptionController.text,
        icon: _selectedIcon,
        category: 'My Characters',
        color: _selectedColor,
        isCustom: true,
      );

      final service = CharacterService(await SharedPreferences.getInstance());
      await service.addCustomCharacter(character);

      if (mounted) {
        _titleController.clear();
        _subtitleController.clear();
        _personalityController.clear();
        _descriptionController.clear();
        _selectedIcon = Icons.person;
        _selectedColor = Colors.blue;
        setState(() {});

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Character "${character.title}" created successfully!'),
            backgroundColor: _selectedColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _personalityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
