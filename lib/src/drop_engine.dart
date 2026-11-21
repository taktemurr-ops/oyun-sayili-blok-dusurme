import 'dart:convert';

import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

/// Sayılı Blok Düşürme: sayılı blok seçilen sütuna düşer. Aynı sayılı
/// komşular (alt, sol, sağ) tek blokta birleşir; her birleşen komşu değeri
/// ikiye katlar. Birleşmeler zincirleme sürer. Değerler üs olarak tutulur
/// (1 = 2, 2 = 4, ...). y = 0 en alt sıradır.

const int kDropCols = 5;
const int kDropRows = 8;

int valueOf(int exp) => 1 << exp;

class DropLevel {
  final List<int> start; // kDropCols * kDropRows, 0 boş, yoksa üs
  final int targetExp; // ulaşılacak blok (üs); 0 = hedefsiz
  final int seed;
  final int difficulty;
  final bool zen;
  final int timeLimit;
  final int aiMoves;
  final int moveLimit;

  const DropLevel({
    required this.start,
    required this.targetExp,
    required this.seed,
    required this.difficulty,
    required this.zen,
    required this.timeLimit,
    this.aiMoves = 0,
    this.moveLimit = 0,
  });

  DropLevel withAi(int ai, int limit) => DropLevel(
        start: start,
        targetExp: targetExp,
        seed: seed,
        difficulty: difficulty,
        zen: zen,
        timeLimit: timeLimit,
        aiMoves: ai,
        moveLimit: limit,
      );
}

DropLevel generateDropLevel(LevelSpec spec) {
  final r = SeededRandom(mixSeed([spec.seed, 2048]));
  final d = spec.difficulty.clamp(1, 10);
  final zen = spec.mode == GameModeId.zen;
  final endless = zen || spec.mode == GameModeId.endless || spec.mode == GameModeId.timeAttack;
  final grid = List<int>.filled(kDropCols * kDropRows, 0);
  if (!endless && d >= 3) {
    // Başlangıçta birbirine değmeyen, farklı sayılı birkaç blok.
    final n = (d ~/ 2).clamp(1, 5);
    for (var k = 0; k < n; k++) {
      final x = r.nextInt(kDropCols);
      var y = 0;
      while (y < kDropRows && grid[y * kDropCols + x] != 0) {
        y++;
      }
      if (y >= 3) continue;
      final e = 1 + r.nextInt(4);
      final below = y > 0 ? grid[(y - 1) * kDropCols + x] : -1;
      final left = x > 0 ? grid[y * kDropCols + x - 1] : -1;
      final right = x < kDropCols - 1 ? grid[y * kDropCols + x + 1] : -1;
      if (e == below || e == left || e == right) continue;
      grid[y * kDropCols + x] = e;
    }
  }
  return DropLevel(
    start: grid,
    targetExp: endless ? 0 : 5 + (d + 1) ~/ 2, // 64 .. 1024
    seed: spec.seed,
    difficulty: d,
    zen: zen,
    timeLimit: spec.mode == GameModeId.timeAttack ? 120 : (spec.has('timer') ? 180 + (10 - d) * 15 : 0),
  );
}

class DropStep {
  final int merges;
  final int points;
  final int landed; // indeks
  const DropStep(this.merges, this.points, this.landed);
}

class DropGame {
  final DropLevel level;
  late List<int> grid;
  late SeededRandom _rng;
  int _draws = 0;
  int current = 1, next = 1;
  int score = 0, moves = 0, merges = 0, bestChain = 0;
  bool lost = false;

  DropGame(this.level) {
    grid = List<int>.of(level.start);
    _rng = SeededRandom(mixSeed([level.seed, 4096]));
    current = _draw();
    next = _draw();
  }

  DropGame._copy(this.level);

  DropGame clone() {
    final g = DropGame._copy(level);
    g.grid = List<int>.of(grid);
    g._rng = _rng.copy();
    g._draws = _draws;
    g.current = current;
    g.next = next;
    g.score = score;
    g.moves = moves;
    g.merges = merges;
    g.bestChain = bestChain;
    g.lost = lost;
    return g;
  }

  int get maxExp => grid.fold<int>(0, (a, b) => b > a ? b : a);

  /// Gelen blok: en büyük bloğa göre 2..(en büyük / 16) arası.
  int _draw() {
    _draws++;
    final top = (maxExp - 4).clamp(1, 6);
    final w = List<int>.generate(top + 1, (i) => i == 0 ? 0 : (top + 2 - i) * (top + 2 - i));
    return _rng.weighted(w).clamp(1, 6);
  }

  int idx(int x, int y) => y * kDropCols + x;

  int landingRow(int x) {
    for (var y = 0; y < kDropRows; y++) {
      if (grid[idx(x, y)] == 0) return y;
    }
    return -1;
  }

  bool canDrop(int x) => !lost && landingRow(x) >= 0;

  bool get won => level.targetExp > 0 && maxExp >= level.targetExp;
  bool get outOfMoves => level.moveLimit > 0 && moves >= level.moveLimit;
  bool get over => lost || won || outOfMoves;

  void _gravity() {
    for (var x = 0; x < kDropCols; x++) {
      var w = 0;
      for (var y = 0; y < kDropRows; y++) {
        final v = grid[idx(x, y)];
        if (v != 0) {
          grid[idx(x, y)] = 0;
          grid[idx(x, w)] = v;
          w++;
        }
      }
    }
  }

  /// [at] karesindeki bloğu komşularıyla birleştirir; birleşme sayısı.
  int _mergeAt(int at) {
    final x = at % kDropCols, y = at ~/ kDropCols;
    final v = grid[at];
    if (v == 0) return 0;
    final n = <int>[];
    if (y > 0 && grid[idx(x, y - 1)] == v) n.add(idx(x, y - 1));
    if (x > 0 && grid[idx(x - 1, y)] == v) n.add(idx(x - 1, y));
    if (x < kDropCols - 1 && grid[idx(x + 1, y)] == v) n.add(idx(x + 1, y));
    if (y < kDropRows - 1 && grid[idx(x, y + 1)] == v) n.add(idx(x, y + 1));
    if (n.isEmpty) return 0;
    for (final i in n) {
      grid[i] = 0;
    }
    // Birleşen blok bu karede kalır; ardından yerçekimiyle iner.
    grid[at] = v + n.length;
    return n.length;
  }

  DropStep? drop(int x) {
    if (over || !canDrop(x)) return null;
    final y = landingRow(x);
    var at = idx(x, y);
    grid[at] = current;
    moves++;
    var chain = 0;
    var pts = 0;
    while (true) {
      final m = _mergeAt(at);
      if (m == 0) {
        // Yerçekiminden sonra başka bir blok birleşebilir mi?
        var found = -1;
        for (var i = 0; i < grid.length && found < 0; i++) {
          if (grid[i] != 0 && _hasTwin(i)) found = i;
        }
        if (found < 0) break;
        at = found;
        continue;
      }
      chain++;
      pts += valueOf(grid[at]);
      final v = grid[at];
      final ax = at % kDropCols;
      _gravity();
      // Birleşen bloğun yeni yeri.
      at = -1;
      for (var yy = 0; yy < kDropRows; yy++) {
        if (grid[idx(ax, yy)] == v) at = idx(ax, yy);
      }
      if (at < 0) break;
    }
    merges += chain;
    if (chain > bestChain) bestChain = chain;
    score += pts * (chain > 1 ? chain : 1);
    current = next;
    next = _draw();
    if (!List.generate(kDropCols, canDrop).any((e) => e)) {
      if (level.zen) {
        for (var i = kDropCols * (kDropRows ~/ 2); i < grid.length; i++) {
          grid[i] = 0;
        }
      } else {
        lost = true;
      }
    }
    return DropStep(chain, pts, at);
  }

  bool _hasTwin(int i) {
    final x = i % kDropCols, y = i ~/ kDropCols, v = grid[i];
    if (x < kDropCols - 1 && grid[idx(x + 1, y)] == v) return true;
    if (y < kDropRows - 1 && grid[idx(x, y + 1)] == v) return true;
    return false;
  }

  int? bestColumn() {
    int? best;
    var bestV = -1e18;
    for (var x = 0; x < kDropCols; x++) {
      if (!canDrop(x)) continue;
      final g = clone();
      final s = g.drop(x);
      if (s == null) continue;
      var v = s.points * 2.0 + g.maxExp * 30 - _height(g) * 6 - _rough(g) * 4;
      if (g.lost) v -= 1e6;
      // Bir adım ileri: sıradaki blok için en iyi sütun.
      if (g.won) v += 1e6;
      var look = g.over ? 0.0 : -1e9;
      for (var x2 = 0; x2 < kDropCols && !g.over; x2++) {
        if (!g.canDrop(x2)) continue;
        final g2 = g.clone();
        final s2 = g2.drop(x2);
        if (s2 == null) continue;
        final v2 = s2.points * 1.5 - _height(g2) * 4 - (g2.lost ? 1e5 : 0);
        if (v2 > look) look = v2;
      }
      v += look * 0.6;
      if (v > bestV) {
        bestV = v;
        best = x;
      }
    }
    return best;
  }

  static int _height(DropGame g) => g.grid.where((v) => v != 0).length;

  static int _rough(DropGame g) {
    var r = 0, prev = -1;
    for (var x = 0; x < kDropCols; x++) {
      final h = g.landingRow(x) < 0 ? kDropRows : g.landingRow(x);
      if (prev >= 0) r += (h - prev).abs();
      prev = h;
    }
    return r;
  }

  String serialize() => jsonEncode({
        'g': grid,
        'd': _draws,
        'r': _rng.state,
        'c': [current, next],
        's': [score, moves, merges, bestChain, lost ? 1 : 0],
      });

  static DropGame restore(DropLevel l, String snap) {
    final j = jsonDecode(snap) as Map<String, dynamic>;
    final g = DropGame(l);
    g.grid = [for (final v in j['g'] as List) (v as num).toInt()];
    g._rng = SeededRandom((j['r'] as num).toInt());
    g._draws = (j['d'] as num).toInt();
    final c = j['c'] as List;
    g.current = (c[0] as num).toInt();
    g.next = (c[1] as num).toInt();
    final s = [for (final v in j['s'] as List) (v as num).toInt()];
    g
      ..score = s[0]
      ..moves = s[1]
      ..merges = s[2]
      ..bestChain = s[3]
      ..lost = s[4] == 1;
    return g;
  }
}

int simulateDropLevel(DropLevel l, {int maxMoves = 400}) {
  final g = DropGame(l);
  while (g.moves < maxMoves && !g.over) {
    final x = g.bestColumn();
    if (x == null) return -1;
    g.drop(x);
  }
  return g.won ? g.moves : -1;
}
