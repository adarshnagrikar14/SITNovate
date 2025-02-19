import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sybot/features/character_bot/data/characters_data.dart';
import 'package:sybot/features/character_bot/models/character_model.dart';

class CharacterService {
  static const _key = 'custom_characters';
  final SharedPreferences _prefs;

  CharacterService(this._prefs);

  Future<List<CharacterModel>> getAllCharacters() async {
    final defaultList =
        defaultCharacters.map((json) => CharacterModel.fromJson(json)).toList();

    final customList = await getCustomCharacters();
    return [...defaultList, ...customList];
  }

  Future<List<CharacterModel>> getCustomCharacters() async {
    final String? jsonString = _prefs.getString(_key);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => CharacterModel.fromJson(json)).toList();
  }

  Future<void> addCustomCharacter(CharacterModel character) async {
    final characters = await getCustomCharacters();
    characters.add(character);

    final jsonString = json.encode(
      characters.map((c) => c.toJson()).toList(),
    );
    await _prefs.setString(_key, jsonString);
  }
}
