import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sybot/features/character_bot/models/character_model.dart';
import 'package:sybot/features/character_bot/services/character_service.dart';
import 'package:sybot/features/story/ui/story_screen.dart';
import 'package:sybot/features/character_bot/ui/character_chat_screen.dart';

class CharacterBotScreen extends StatefulWidget {
  const CharacterBotScreen({super.key});

  @override
  State<CharacterBotScreen> createState() => _CharacterBotScreenState();
}

class _CharacterBotScreenState extends State<CharacterBotScreen> {
  Future<List<CharacterModel>> _charactersFuture = Future.value([]);

  // Add icon map
  final Map<String, IconData> iconMap = {
    'account_balance': Icons.account_balance,
    'person': Icons.person,
    'movie': Icons.movie,
    'medical_services': Icons.medical_services,
    'school': Icons.school,
    'restaurant': Icons.restaurant,
    'psychology': Icons.psychology,
    'elderly': Icons.elderly,
  };

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  void _loadCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final service = CharacterService(prefs);
      _charactersFuture = service.getAllCharacters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Characters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoryScreen()),
              );
              _loadCharacters();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<CharacterModel>>(
        future: _charactersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No characters found'));
          }

          final characters = snapshot.data!;
          final categorizedCharacters = _categorizeCharacters(characters);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final category in categorizedCharacters.keys) ...[
                _buildSection(
                  category,
                  categorizedCharacters[category]!
                      .map(
                        (character) => _buildCharacterTile(character),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
            ],
          );
        },
      ),
    );
  }

  Map<String, List<CharacterModel>> _categorizeCharacters(
    List<CharacterModel> characters,
  ) {
    final Map<String, List<CharacterModel>> map = {};

    for (var character in characters) {
      if (!map.containsKey(character.category)) {
        map[character.category] = [];
      }
      map[character.category]!.add(character);
    }

    return map;
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _buildCharacterTile(CharacterModel character) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: character.color.withOpacity(0.1),
          child: Icon(
            character.icon,
            size: 30,
            color: character.color,
          ),
        ),
        title: Text(
          character.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              character.subtitle,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                character.personality,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              character.description,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CharacterChatScreen(
                title: character.title,
                character: character.subtitle,
                personality: '''${character.description}
                
Character traits: ${character.personality}

Stay in character and only respond about topics related to being ${character.title}.''',
                primaryColor: character.color,
                characterIcon: character.icon,
              ),
            ),
          );
        },
      ),
    );
  }
}
