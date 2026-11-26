// Onaylı tasarım: oyun merkez benzeri ev sahibinde (koyu palet) açılır;
// üst bilgi, düğmeler ve dokunuşla açılan pencereler okunur (3:1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyun_sayili_blok_dusurme/oyun_sayili_blok_dusurme.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/core/level_plan.dart';

import 'studio_readability.dart';

void main() {
  for (final lv in const [3, 40]) {
    testWidgets('bölüm $lv: onaylı koyu tasarımda yazılar okunur', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final cfg = sayiliBlokConfig;
      final rules = cfg.rules;
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);
      final gl = rules.build(planner.spec(lv));
      final ctx = PlayContext(
        spec: gl.spec,
        generated: gl,
        resume: const {},
        pieceColors: const [Color(0xFF3075C4), Color(0xFF2BB3B1), Color(0xFFE2574C), Color(0xFFF2A93B), Color(0xFF7BA05B), Color(0xFF9763BC), Color(0xFFE58FB0), Color(0xFFC9A66B)],
        background: const [Color(0xFF1A2E5C), Color(0xFF3A6FC4)],
        colorBlind: false,
        reducedMotion: false,
        leftHanded: false,
        lang: 'tr',
        t: (k, [p = const {}]) => k,
        finish: (_) {},
        saveResume: (_) {},
        requestHint: () async => true,
        requestBooster: () async => true,
        requestContinue: () async => false,
        sfx: (_) {},
      );
      await tester.pumpWidget(studioHost(cfg.buildPlay(ctx), seed: cfg.seedColor));
      await tester.pump(const Duration(milliseconds: 400));
      final issues = await sweepReadability(tester, cfg.gameId, rows: 7, cols: 5, top: 40);
      expect(issues, isEmpty, reason: issues.join('; '));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
