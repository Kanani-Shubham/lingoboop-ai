import 'package:flutter/material.dart';
import 'app_colors.dart';

class CharacterModel {
  final String key;
  final String name;
  final String species;
  final Color accentColor;
  final String previewAsset;
  final String modelAsset;
  final bool isFreeTier;
  final String description;

  const CharacterModel({
    required this.key,
    required this.name,
    required this.species,
    required this.accentColor,
    required this.previewAsset,
    required this.modelAsset,
    required this.isFreeTier,
    required this.description,
  });
}

class CharacterRegistry {
  CharacterRegistry._();

  static const List<CharacterModel> allCharacters = [
    CharacterModel(
      key: 'fox',
      name: 'Maru',
      species: 'Fox',
      accentColor: AppColors.foxMaru,
      previewAsset: 'assets/characters/maru/previews/maru.png',
      modelAsset: 'assets/characters/maru/models/maru.glb',
      isFreeTier: true,
      description: 'Curious, energetic companion. Loves quick conversations.',
    ),
    CharacterModel(
      key: 'cat',
      name: 'Mimi',
      species: 'Cat',
      accentColor: AppColors.catMimi,
      previewAsset: 'assets/characters/mimi/previews/mimi.png',
      modelAsset: 'assets/characters/mimi/models/mimi.glb',
      isFreeTier: true,
      description: 'Elegant and sharp. Patient with precise pronunciation.',
    ),
    CharacterModel(
      key: 'bunny',
      name: 'Bun',
      species: 'Bunny',
      accentColor: AppColors.bunnyBun,
      previewAsset: 'assets/characters/bun/previews/bun.png',
      modelAsset: 'assets/characters/bun/models/bun.glb',
      isFreeTier: true,
      description: 'Bubbly, playful pet that celebrates every small victory.',
    ),
    CharacterModel(
      key: 'panda',
      name: 'Pano',
      species: 'Panda',
      accentColor: AppColors.pandaPano,
      previewAsset: 'assets/characters/pano/previews/pano.png',
      modelAsset: 'assets/characters/pano/models/pano.glb',
      isFreeTier: false,
      description: 'Calm, methodical master. Focuses on deep vocabulary building.',
    ),
    CharacterModel(
      key: 'penguin',
      name: 'Pip',
      species: 'Penguin',
      accentColor: AppColors.penguinPip,
      previewAsset: 'assets/characters/pip/previews/pip.png',
      modelAsset: 'assets/characters/pip/models/pip.glb',
      isFreeTier: false,
      description: 'Friendly, focused buddy for daily language routines.',
    ),
    CharacterModel(
      key: 'lion',
      name: 'Leo',
      species: 'Lion',
      accentColor: AppColors.lionLeo,
      previewAsset: 'assets/characters/leo/previews/leo.png',
      modelAsset: 'assets/characters/leo/models/leo.glb',
      isFreeTier: false,
      description: 'Bold, encouraging coach that builds public speaking confidence.',
    ),
  ];

  static CharacterModel getByKey(String key) {
    return allCharacters.firstWhere(
      (c) => c.key == key,
      orElse: () => allCharacters.first,
    );
  }
}

