import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'dart:convert';

void main() {
  runApp(const LottoApp());
}

Color _ballColor(int n) {
  if (n <= 10) return const Color(0xFFFFB300);
  if (n <= 20) return const Color(0xFF2979FF);
  if (n <= 30) return const Color(0xFFE53935);
  if (n <= 40) return const Color(0xFF78909C);
  return const Color(0xFF43A047);
}

class LottoApp extends StatelessWidget {
  const LottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '로또 번호 생성기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E1123),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C4DFF),
          secondary: Color(0xFFFFD700),
        ),
        useMaterial3: true,
      ),
      home: const LottoHomePage(),
    );
  }
}

class LottoHomePage extends StatefulWidget {
  const LottoHomePage({super.key});

  @override
  State<LottoHomePage> createState() => _LottoHomePageState();
}

class _LottoHomePageState extends State<LottoHomePage> with TickerProviderStateMixin {
  List<List<int>> _numberSets = [];
  final Random _random = Random();
  bool _isGenerating = false;
  final GlobalKey _repaintKey = GlobalKey();
  Map<int, int> _frequency = {};
  bool _useStatistics = false;
  final List<AnimationController> _cardControllers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final String raw = await rootBundle.loadString('assets/result.txt');
      final List<dynamic> entries = json.decode(raw);

      final Map<int, int> freq = {};

      for (final e in entries) {
        for (int i = 1; i <= 6; i++) {
          final n = e['tm${i}WnNo'] as int;
          freq[n] = (freq[n] ?? 0) + 1;
        }
      }

      setState(() {
        _frequency = freq;
      });
    } catch (e) {
      debugPrint('Data load error: $e');
    }
  }

  @override
  void dispose() {
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generate() async {
    for (final c in _cardControllers) {
      c.dispose();
    }
    _cardControllers.clear();

    setState(() {
      _isGenerating = true;
      _numberSets = [];
    });

    await Future.delayed(const Duration(milliseconds: 200));

    for (int i = 0; i < 5; i++) {
      List<int> nums;
      int attempts = 50;

      do {
        nums = _useStatistics && _frequency.isNotEmpty
            ? _weightedRandom()
            : _pureRandom();
        nums.sort();
        attempts--;
      } while (attempts > 0 && _numberSets.any((s) => _sameList(s, nums)));

      final ctrl = AnimationController(
        duration: const Duration(milliseconds: 350),
        vsync: this,
      );
      _cardControllers.add(ctrl);

      setState(() => _numberSets.add(nums));
      ctrl.forward();
      await Future.delayed(const Duration(milliseconds: 180));
    }

    setState(() => _isGenerating = false);
  }

  List<int> _pureRandom() {
    final all = List.generate(45, (i) => i + 1)..shuffle(_random);
    return all.take(6).toList();
  }

  // 색상 구간별 1개씩 + 나머지 1개 전체 풀에서 가중치 랜덤
  List<int> _weightedRandom() {
    const zones = [
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      [11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
      [21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
      [31, 32, 33, 34, 35, 36, 37, 38, 39, 40],
      [41, 42, 43, 44, 45],
    ];

    final selected = <int>{};

    for (final zone in zones) {
      final weights = zone.map((n) => (_frequency[n] ?? 0) + 1.0).toList();
      final total = weights.fold(0.0, (s, w) => s + w);
      int pick;
      do {
        double r = _random.nextDouble() * total;
        pick = zone.last;
        for (int i = 0; i < zone.length; i++) {
          r -= weights[i];
          if (r <= 0) { pick = zone[i]; break; }
        }
      } while (selected.contains(pick));
      selected.add(pick);
    }

    // 6번째: 아직 선택 안 된 번호 중 가중치 랜덤
    final remaining = List.generate(45, (i) => i + 1).where((n) => !selected.contains(n)).toList();
    final rWeights = remaining.map((n) => (_frequency[n] ?? 0) + 1.0).toList();
    final rTotal = rWeights.fold(0.0, (s, w) => s + w);
    double r = _random.nextDouble() * rTotal;
    int extra = remaining.last;
    for (int i = 0; i < remaining.length; i++) {
      r -= rWeights[i];
      if (r <= 0) { extra = remaining[i]; break; }
    }
    selected.add(extra);

    return selected.toList();
  }

  bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _download() async {
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final png = bytes!.buffer.asUint8List();

      final blob = html.Blob([png]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'lotto_${DateTime.now().millisecondsSinceEpoch}.png')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('이미지 저장 완료'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1123),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _modeToggle(),
            Expanded(child: _body()),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF6F00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('🎰', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('로또 번호 생성기',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('5세트 자동생성',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
          const Spacer(),
          if (_numberSets.isNotEmpty)
            GestureDetector(
              onTap: _download,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2240),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.download_rounded, color: Color(0xFFFFD700), size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3C),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(children: [
          _toggleBtn('랜덤', false),
          _toggleBtn('통계 기반', true),
        ]),
      ),
    );
  }

  Widget _toggleBtn(String label, bool val) {
    final active = _useStatistics == val;
    return Expanded(
      child: GestureDetector(
        onTap: _frequency.isEmpty ? null : () => setState(() => _useStatistics = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF7C4DFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_numberSets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎱', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 14),
            Text(
              '아래 버튼을 눌러\n행운의 번호를 뽑아보세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.3), height: 1.7),
            ),
          ],
        ),
      );
    }

    return RepaintBoundary(
      key: _repaintKey,
      child: Container(
        color: const Color(0xFF0E1123),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          itemCount: _numberSets.length,
          itemBuilder: (_, i) => _card(i),
        ),
      ),
    );
  }

  Widget _card(int i) {
    final nums = _numberSets[i];
    const labels = ['A', 'B', 'C', 'D', 'E'];
    final card = Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF161B35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF252B4A), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(
                child: Text(labels[i],
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9B8FFF))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: nums.map(_ball).toList(),
              ),
            ),
          ],
        ),
      ),
    );

    if (i >= _cardControllers.length) return card;

    return AnimatedBuilder(
      animation: _cardControllers[i],
      builder: (_, child) {
        final t = _cardControllers[i].value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 20),
            child: child,
          ),
        );
      },
      child: card,
    );
  }

  Widget _ball(int n) {
    final c = _ballColor(n);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [c.withOpacity(0.85), c],
          center: const Alignment(-0.3, -0.3),
          radius: 0.8,
        ),
        boxShadow: [BoxShadow(color: c.withOpacity(0.25), blurRadius: 6, spreadRadius: 0)],
      ),
      child: Center(
        child: Text('$n',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1123),
        border: Border(top: BorderSide(color: Color(0xFF1A1F3C), width: 1)),
      ),
      child: GestureDetector(
        onTap: _isGenerating ? null : _generate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 52,
          decoration: BoxDecoration(
            gradient: _isGenerating
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: _isGenerating ? const Color(0xFF1A1F3C) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: _isGenerating
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text('번호 생성 중...', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        _useStatistics ? '통계 기반 번호 생성' : '행운의 번호 생성',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
