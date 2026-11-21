import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';

import 'drop_engine.dart';

const sayiliBlokId = 'oyun-sayili-blok-dusurme';

class DropRules extends GameRules<DropLevel> {
  @override
  String get gameId => sayiliBlokId;

  @override
  List<String> get optionalMechanics => const ['timer'];

  @override
  List<GameModeId> get modes => const [
        GameModeId.campaign,
        GameModeId.endless,
        GameModeId.timeAttack,
        GameModeId.zen,
        GameModeId.daily,
        GameModeId.weekly,
        GameModeId.challenge,
      ];

  @override
  List<GameStat> get gameStats => const [
        GameStat('merges', 'Birleştirme', 'Merges', scale: 40),
        GameStat('best_chain', 'En uzun zincir', 'Longest chain', scale: 3),
        GameStat('best_tile', 'En büyük blok (üs)', 'Best tile (power)', scale: 1),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('merges', 'merges', [20, 50, 120]),
        MissionTemplate('chain', 'best_chain', [2, 3, 4]),
      ];

  @override
  DropLevel generate(LevelSpec spec) => generateDropLevel(spec);

  @override
  Validation validate(DropLevel level, LevelSpec spec) {
    if (level.start.length != kDropCols * kDropRows) return const Validation.fail('bad board');
    final g = DropGame(level);
    if (!List.generate(kDropCols, g.canDrop).any((e) => e)) return const Validation.fail('full');
    if (level.targetExp == 0) return const Validation.ok();
    final m = simulateDropLevel(level);
    if (m < 0) return const Validation.fail('AI could not solve');
    return Validation.ok(m);
  }

  DropLevel finalize(GeneratedLevel<DropLevel> g) {
    final l = g.puzzle;
    if (l.targetExp == 0) return l;
    final ai = g.validation.metric;
    final slack = 2.2 - l.difficulty * 0.08;
    final limit = l.difficulty >= 5 ? (ai * slack).ceil() + 6 : 0;
    return l.withAi(ai, limit);
  }

  static int stars(DropGame g) {
    if (!g.won) return 0;
    final ai = g.level.aiMoves;
    if (ai <= 0 || g.moves <= ai + 3) return 3;
    if (g.moves <= (ai * 1.4).ceil() + 3) return 2;
    return 1;
  }
}
