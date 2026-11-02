import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/character_data.dart';

/// Single source of truth configuration for characters matching `polypet-demo.html`
class PetCharacterConfig {
  final String key;
  final String name;
  final String species;
  final Color accentColor;
  final String previewAsset;
  final String modelAsset;

  const PetCharacterConfig({
    required this.key,
    required this.name,
    required this.species,
    required this.accentColor,
    required this.previewAsset,
    required this.modelAsset,
  });

  static const List<PetCharacterConfig> characters = [
    PetCharacterConfig(
      key: 'fox',
      name: 'Maru',
      species: 'Fox',
      accentColor: AppColors.foxMaru, // #c4571c
      previewAsset: 'assets/characters/maru/previews/maru.png',
      modelAsset: 'assets/characters/maru/models/maru.glb',
    ),
    PetCharacterConfig(
      key: 'cat',
      name: 'Mimi',
      species: 'Cat',
      accentColor: AppColors.catMimi, // #6a4cc4
      previewAsset: 'assets/characters/mimi/previews/mimi.png',
      modelAsset: 'assets/characters/mimi/models/mimi.glb',
    ),
    PetCharacterConfig(
      key: 'panda',
      name: 'Pano',
      species: 'Panda',
      accentColor: AppColors.pandaPano, // #2c6e5e
      previewAsset: 'assets/characters/pano/previews/pano.png',
      modelAsset: 'assets/characters/pano/models/pano.glb',
    ),
    PetCharacterConfig(
      key: 'bunny',
      name: 'Bun',
      species: 'Bunny',
      accentColor: AppColors.bunnyBun, // #c23d7b
      previewAsset: 'assets/characters/bun/previews/bun.png',
      modelAsset: 'assets/characters/bun/models/bun.glb',
    ),
    PetCharacterConfig(
      key: 'penguin',
      name: 'Pip',
      species: 'Penguin',
      accentColor: AppColors.penguinPip, // #2c62c4
      previewAsset: 'assets/characters/pip/previews/pip.png',
      modelAsset: 'assets/characters/pip/models/pip.glb',
    ),
    PetCharacterConfig(
      key: 'lion',
      name: 'Leo',
      species: 'Lion',
      accentColor: AppColors.lionLeo, // #9a6a06
      previewAsset: 'assets/characters/leo/previews/leo.png',
      modelAsset: 'assets/characters/leo/models/leo.glb',
    ),
  ];

  static PetCharacterConfig getByKey(String key) {
    return characters.firstWhere(
      (c) => c.key == key,
      orElse: () => characters.first,
    );
  }

  CharacterModel toCharacterModel() {
    return CharacterRegistry.getByKey(key);
  }
}

