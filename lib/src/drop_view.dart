import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';

import 'drop_engine.dart';
import 'drop_rules.dart';

/// Üsse göre renk: sıcaktan soğuğa uzanan kendi paletimiz.
const _tileColors = [
  Color(0xFF90A4AE), Color(0xFF4FC3F7), Color(0xFF4DB6AC), Color(0xFF81C784), Color(0xFFDCE775),
  Color(0xFFFFD54F), Color(0xFFFFB74D), Color(0xFFFF8A65), Color(0xFFE57373), Color(0xFFF06292),
  Color(0xFFBA68C8), Color(0xFF9575CD), Color(0xFF7986CB), Color(0xFF64B5F6), Color(0xFF4DD0E1),
];

Color tileColor(int e) => _tileColors[e % _tileColors.length];

String tileLabel(int e) {
  final v = valueOf(e);
  if (v >= 1000000) return '${v ~/ 1000000}M';
  if (v >= 10000) return '${v ~/ 1000}K';
  return '$v';
}

class DropView extends StatefulWidget {
  final PlayContext ctx;
  const DropView({super.key, required this.ctx});

  @override
  State<DropView> createState() => _DropViewState();
}

class _DropViewState extends State<DropView> {
  late DropLevel level;
  late DropGame game;
  int? _hint;
  int _seconds = 0, _hints = 0;
  Timer? _timer;
  bool _ended = false;
  double _cell = 50;

  PlayContext get ctx => widget.ctx;
  bool get _tr => ctx.lang == 'tr';

  @override
  void initState() {
    super.initState();
    level = DropRules().finalize(ctx.generated as GeneratedLevel<DropLevel>);
    final snap = ctx.resume['snap'];
    game = snap is String ? DropGame.restore(level, snap) : DropGame(level);
    _seconds = (ctx.resume['secs'] as num?)?.toInt() ?? 0;
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_ended || !mounted) return;
      setState(() => _seconds++);
      if (level.timeLimit > 0 && _seconds >= level.timeLimit) _end();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _persist() => ctx.saveResume({'snap': game.serialize(), 'secs': _seconds, 'hints': _hints});

  void _drop(int x) {
    if (_ended) return;
    final s = game.drop(x);
    if (s == null) {
      ctx.sfx(Sfx.error);
      return;
    }
    ctx.sfx(s.merges > 1 ? Sfx.combo : (s.merges == 1 ? Sfx.clear : Sfx.place));
    setState(() => _hint = null);
    _persist();
    if (game.over) _end();
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    final goal = level.targetExp > 0;
    final won = goal ? game.won : game.score > 0;
    ctx.sfx(won ? Sfx.win : Sfx.lose);
    final stars = goal
        ? DropRules.stars(game)
        : (game.maxExp >= 11 ? 3 : game.maxExp >= 9 ? 2 : game.score > 0 ? 1 : 0);
    ctx.finish(RoundResult(
      won: won,
      score: game.score,
      stars: won ? stars : 0,
      seconds: _seconds,
      moves: game.moves,
      hintsUsed: _hints,
      undosUsed: 0,
      gameStats: {'merges': game.merges, 'best_chain': game.bestChain, 'best_tile': game.maxExp},
    ));
  }

  Future<void> _useHint() async {
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() => _hint = game.bestColumn());
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      _cell = math.max(24.0, math.min((cons.maxWidth - 24) / kDropCols, cons.maxHeight * 0.66 / (kDropRows + 1.3)));
      final w = _cell * kDropCols, h = _cell * kDropRows;
      return Column(children: [
        _hud(),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _tile(game.current, _cell * 0.95),
          const SizedBox(width: 16),
          Opacity(opacity: 0.55, child: _tile(game.next, _cell * 0.6)),
        ]),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTapUp: (d) => _drop((d.localPosition.dx / _cell).floor().clamp(0, kDropCols - 1)),
            child: Semantics(
              label: 'board',
              child: SizedBox(width: w, height: h, child: CustomPaint(painter: _Painter(this))),
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IconButton.filledTonal(
              onPressed: _ended ? null : _useHint, icon: const Icon(Icons.lightbulb), tooltip: ctx.t('hint')),
        ),
      ]);
    });
  }

  Widget _tile(int e, double s) => Container(
        width: s,
        height: s,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tileColor(e), borderRadius: BorderRadius.circular(s * 0.22)),
        child: Text(tileLabel(e),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: s * 0.36, color: Colors.black.withValues(alpha: 0.72))),
      );

  Widget _hud() {
    final goal = level.targetExp;
    final label = goal == 0
        ? (_tr ? 'Puan: ${game.score}' : 'Score: ${game.score}')
        : (_tr ? 'Hedef: ${tileLabel(goal)} · En büyük: ${tileLabel(math.max(1, game.maxExp))}'
            : 'Goal: ${tileLabel(goal)} · Best: ${tileLabel(math.max(1, game.maxExp))}');
    final left = level.moveLimit > 0 ? level.moveLimit - game.moves : null;
    final secs = level.timeLimit > 0 ? (level.timeLimit - _seconds).clamp(0, 9999) : _seconds;
    String two(int x) => x.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            if (goal > 0) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(value: (game.maxExp / goal).clamp(0, 1).toDouble()),
            ],
          ]),
        ),
        if (left != null) ...[const SizedBox(width: 10), const Icon(Icons.south, size: 18), Text(' $left')],
        const SizedBox(width: 10),
        const Icon(Icons.timer_outlined, size: 18),
        Text(' ${secs ~/ 60}:${two(secs % 60)}'),
      ]),
    );
  }
}

class _Painter extends CustomPainter {
  final _DropViewState v;
  _Painter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final c = v._cell;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
        Paint()..color = Colors.black.withValues(alpha: 0.12));
    for (var x = 0; x < kDropCols; x++) {
      if (x.isOdd) {
        canvas.drawRect(Rect.fromLTWH(x * c, 0, c, size.height), Paint()..color = Colors.white.withValues(alpha: 0.03));
      }
    }
    if (v._hint != null) {
      canvas.drawRect(Rect.fromLTWH(v._hint! * c, 0, c, size.height), Paint()..color = Colors.amber.withValues(alpha: 0.25));
    }
    final g = v.game;
    for (var i = 0; i < g.grid.length; i++) {
      final e = g.grid[i];
      if (e == 0) continue;
      final x = i % kDropCols, y = i ~/ kDropCols;
      final r = Rect.fromLTWH(x * c, (kDropRows - 1 - y) * c, c, c).deflate(3);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(c * 0.2)), Paint()..color = tileColor(e));
      final tp = TextPainter(
        text: TextSpan(
            text: tileLabel(e),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: c * 0.34, color: Colors.black.withValues(alpha: 0.72))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
