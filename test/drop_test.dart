import 'package:flutter_test/flutter_test.dart';
import 'package:oyun_sayili_blok_dusurme/oyun_sayili_blok_dusurme.dart';
import 'package:studio_core/core/level_plan.dart';

void main() {
  final rules = DropRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('aynı sayılar birleşir, zincir sürer', () {
    final l = rules.build(planner.spec(1)).puzzle;
    final g = DropGame(l);
    g.grid = List<int>.filled(kDropCols * kDropRows, 0);
    // Alt sıra: 2 | _ | 4 ; ortaya düşen 2 soldakiyle 4 olur, sonra sağdakiyle 8.
    g.grid[0] = 1;
    g.grid[2] = 2;
    g.current = 1;
    final s = g.drop(1)!;
    expect(s.merges, 2);
    expect(g.maxExp, 3);
    expect(g.grid.where((v) => v != 0).length, 1);
  });

  test('kampanya bölümleri doğrulanır ve bot hedefe ulaşır', () {
    for (final lv in [1, 12, 50, 99, 230, 777, 2500, 9999, 33333, 49999]) {
      final gl = rules.build(planner.spec(lv));
      expect(gl.validation.ok, isTrue, reason: 'bölüm $lv: ${gl.validation.reason}');
      expect(gl.attempts, lessThan(40), reason: 'bölüm $lv kolaylaştırıldı');
      final l = rules.finalize(gl);
      final m = simulateDropLevel(l);
      expect(m, greaterThan(0), reason: 'bölüm $lv');
      if (l.moveLimit > 0) expect(m, lessThanOrEqualTo(l.moveLimit));
    }
  });

  test('kayıt geri yüklenince oyun aynı devam eder', () {
    final l = rules.build(planner.spec(88)).puzzle;
    final g = DropGame(l);
    for (var k = 0; k < 12; k++) {
      final x = g.bestColumn();
      if (x == null) break;
      g.drop(x);
    }
    final r = DropGame.restore(l, g.serialize());
    expect(r.serialize(), g.serialize());
    for (var k = 0; k < 5; k++) {
      final x = g.bestColumn();
      if (x == null) break;
      g.drop(x);
      r.drop(x);
    }
    expect(r.serialize(), g.serialize());
  });

  test('her kip üretilir', () {
    for (final m in rules.modes) {
      expect(rules.build(planner.spec(44, mode: m)).validation.ok, isTrue);
    }
  });
}
