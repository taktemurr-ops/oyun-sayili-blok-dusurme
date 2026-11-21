/// Sayılı Blok Düşürme: sayılı blokları sütunlara bırak, aynı sayıları birleştir.
/// Blok Oyunları merkez uygulamasının oyunu.
library;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';

import 'src/drop_rules.dart';
import 'src/drop_view.dart';

export 'src/drop_engine.dart';
export 'src/drop_rules.dart';

final sayiliBlokConfig = GameConfig(
  gameId: sayiliBlokId,
  title: const ['Sayılı Bloklar', 'Number Drop', 'Zahlenfall', 'Números que Caen', 'Chute de Nombres'],
  tagline: const [
    'Aynı sayıları birleştir, büyüt!',
    'Merge equal numbers, grow them!',
    'Gleiche Zahlen verbinden!',
    '¡Une números iguales!',
    'Fusionnez les nombres égaux !',
  ],
  seedColor: const Color(0xFFFF8A65),
  icon: Icons.filter_9_plus_rounded,
  rules: DropRules(),
  buildPlay: (ctx) => DropView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.touch_app, [
      'Bir sütuna dokun; sıradaki blok oraya düşer.',
      'Tap a column to drop the block there.',
      'Tippe eine Spalte an, um den Block fallen zu lassen.',
      'Toca una columna para soltar el bloque.',
      'Touchez une colonne pour y lâcher le bloc.',
    ]),
    TutorialStep(Icons.merge_type, [
      'Yan yana ya da üst üste gelen aynı sayılar birleşip büyür. Zincirler bonus verir.',
      'Equal numbers that touch merge and grow. Chains give a bonus.',
      'Gleiche Zahlen, die sich berühren, verschmelzen.',
      'Los números iguales que se tocan se fusionan.',
      'Les nombres égaux qui se touchent fusionnent.',
    ]),
  ],
);
