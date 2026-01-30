import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:html' as html;

void main() {
  runApp(const LottoApp());
}

class LottoApp extends StatelessWidget {
  const LottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '로또 번호 생성기',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
  late AnimationController _popController;
  late AnimationController _iconController;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _popController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _generateNumbers() async {
    setState(() {
      _isGenerating = true;
      _numberSets = [];
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // 5세트 생성
    for (int i = 0; i < 5; i++) {
      List<int> allNumbers = List.generate(45, (index) => index + 1);
      allNumbers.shuffle(_random);
      List<int> numbers = allNumbers.take(6).toList();
      numbers.sort();
      
      setState(() {
        _numberSets.add(numbers);
      });
      
      _popController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 400));
    }

    setState(() {
      _isGenerating = false;
    });
  }

  Future<void> _downloadImage() async {
    try {
      RenderRepaintBoundary boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData!.buffer.asUint8List();

      final blob = html.Blob([pngBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'lotto_numbers_${DateTime.now().millisecondsSinceEpoch}.png')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지가 다운로드되었습니다!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다운로드 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _iconController,
              builder: (context, child) {
                final rotation = _iconController.value * 2 * pi;
                final scale = 1.0 + sin(_iconController.value * 4 * pi) * 0.2;
                return Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(
                    scale: scale,
                    child: const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            const Text('로또 번호 생성기'),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _iconController,
              builder: (context, child) {
                final scale = 1.0 + sin(_iconController.value * 4 * pi + pi) * 0.2;
                return Transform.scale(
                  scale: scale,
                  child: const Text('🍀', style: TextStyle(fontSize: 24)),
                );
              },
            ),
          ],
        ),
        actions: [
          if (_numberSets.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadImage,
              tooltip: '이미지 다운로드',
            ),
        ],
      ),
      body: Column(
        children: [
          // 번호 생성 버튼
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateNumbers,
              icon: _isGenerating 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.casino),
              label: Text(_isGenerating ? '생성 중...' : '행운의 번호 생성 (5세트)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          // 생성된 번호들
          Expanded(
            child: RepaintBoundary(
              key: _repaintKey,
              child: Container(
                color: Colors.white,
                child: _numberSets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _iconController,
                              builder: (context, child) {
                                final bounce = sin(_iconController.value * 2 * pi) * 20;
                                return Transform.translate(
                                  offset: Offset(0, bounce),
                                  child: const Text('🎰', style: TextStyle(fontSize: 80)),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '버튼을 눌러 5세트의 번호를 생성하세요',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _numberSets.length,
                        itemBuilder: (context, index) {
                          return AnimatedBuilder(
                            animation: _popController,
                            builder: (context, child) {
                              final scale = index == _numberSets.length - 1
                                  ? 0.8 + (_popController.value * 0.2)
                                  : 1.0;
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: Card(
                              elevation: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          '✨ ',
                                          style: TextStyle(fontSize: 20),
                                        ),
                                        Text(
                                          '${String.fromCharCode(65 + index)}조',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      children: _numberSets[index].map((number) {
                                        return Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _getNumberColor(number),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                spreadRadius: 1,
                                                blurRadius: 5,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              number.toString(),
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 번호 범위에 따라 다른 색상 지정
  Color _getNumberColor(int number) {
    if (number <= 10) {
      return Colors.orange;
    } else if (number <= 20) {
      return Colors.blue;
    } else if (number <= 30) {
      return Colors.red;
    } else if (number <= 40) {
      return Colors.grey;
    } else {
      return Colors.green;
    }
  }
}
