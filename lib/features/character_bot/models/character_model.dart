import 'package:flutter/material.dart';

class CharacterModel {
  final String id;
  final String title;
  final String subtitle;
  final String personality;
  final String description;
  final IconData icon;
  final String category;
  final Color color;
  final bool isCustom;

  CharacterModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.personality,
    required this.description,
    required this.icon,
    required this.category,
    required this.color,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'personality': personality,
        'description': description,
        'icon': icon.codePoint,
        'category': category,
        'color': color.value,
        'isCustom': isCustom,
      };

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      personality: json['personality'],
      description: json['description'],
      icon: IconData(
        json['icon'],
        fontFamily: 'MaterialIcons',
      ),
      category: json['category'],
      color: Color(json['color']),
      isCustom: json['isCustom'] ?? false,
    );
  }
}
