import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../events/event_bus.dart';

class ClawAvatar extends StatefulWidget {
  const ClawAvatar({super.key});

  @override
  State<ClawAvatar> createState() => _ClawAvatarState();
}

class _ClawAvatarState extends State<ClawAvatar> with SingleTickerProviderStateMixin {
  // --- 🌟 AI 面部核心参数 ---
  double _eyeWidth = 30.0;
  double _eyeHeight = 40.0;
  double _eyeRadius = 15.0;
  double _tiltAngle = 0.0;
  double _spacing = 40.0;
  double _mouthSmile = 0.0; // 新增：嘴巴弧度
  Color _eyeColor = Colors.cyanAccent;

  // --- 生物特征状态 ---
  bool _isSpeaking = false;
  bool _isBlinking = false;

  // 🌟 新增：眼球微动偏移量 (模拟真实生命体的扫视)
  double _lookOffsetX = 0.0;
  double _lookOffsetY = 0.0;

  late StreamSubscription _faceSub;
  late StreamSubscription _speakingSub;

  // --- 定时器 ---
  late Timer _blinkTimer;
  late Timer _saccadeTimer; // 控制微动
  Timer? _emotionResetTimer; // 🌟 情绪回弹定时器

  late AnimationController _speakAnimController;

  @override
  void initState() {
    super.initState();

    // 1. 监听大模型的底层几何参数修改
    _faceSub = EventBus().on<FaceExpressionEvent>().listen((event) {
      if (mounted) {
        setState(() {
          _eyeWidth = event.eyeWidth;
          _eyeHeight = event.eyeHeight;
          _eyeRadius = event.eyeRadius;
          _tiltAngle = event.tiltAngle;
          _spacing = event.spacing;
          _mouthSmile = event.mouthSmile;
          _eyeColor = _hexToColor(event.colorHex);
        });

        // 🌟 核心：触发极端情绪后，设定 4 秒后自动回落到平静状态！
        _emotionResetTimer?.cancel();
        _emotionResetTimer = Timer(const Duration(seconds: 4), _resetToNeutral);
      }
    });

    // 2. 监听说话状态
    _speakAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _speakingSub = EventBus().on<SpeakingStatusEvent>().listen((event) {
      if (mounted) {
        _isSpeaking = event.isSpeaking;
        if (_isSpeaking) {
          _speakAnimController.repeat(reverse: true);
        } else {
          _speakAnimController.stop();
          _speakAnimController.value = 0.0;
        }
      }
    });

    // 3. 启动生命体征引擎
    _startRandomBlinking();
    _startSaccadeEngine();
  }

  /// 🌟 情绪回落基准线 (恢复成高冷的平静状态)
  void _resetToNeutral() {
    if (mounted && !_isSpeaking) {
      setState(() {
        _eyeWidth = 30.0;
        _eyeHeight = 40.0;
        _eyeRadius = 15.0;
        _tiltAngle = 0.0;
        _spacing = 40.0;
        _mouthSmile = 0.0;
        _eyeColor = Colors.cyanAccent;
      });
    }
  }

  /// 🌟 眼球无意识微动引擎
  void _startSaccadeEngine() {
    final random = math.Random();
    _saccadeTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted && !_isSpeaking) {
        // 偶尔向四周随机看一眼
        if (random.nextDouble() > 0.4) {
          setState(() {
            _lookOffsetX = (random.nextDouble() - 0.5) * 12; // X轴微动
            _lookOffsetY = (random.nextDouble() - 0.5) * 6;  // Y轴微动
          });
          // 300毫秒后立刻收回视线，形成“灵动的一瞥”
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() { _lookOffsetX = 0; _lookOffsetY = 0; });
          });
        }
      }
    });
  }

  void _startRandomBlinking() {
    _blinkTimer = Timer(Duration(milliseconds: 2000 + (DateTime.now().millisecond % 4000)), () {
      if (mounted) {
        setState(() => _isBlinking = true);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _isBlinking = false);
        });
        _startRandomBlinking();
      }
    });
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.cyanAccent;
    }
  }

  @override
  void dispose() {
    _faceSub.cancel();
    _speakingSub.cancel();
    _blinkTimer.cancel();
    _saccadeTimer.cancel();
    _emotionResetTimer?.cancel();
    _speakAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140, // 稍微拉高一点，给嘴巴留空间
      width: double.infinity,
      color: Colors.black87,
      child: Center(
        child: AnimatedBuilder(
          animation: _speakAnimController,
          builder: (context, child) {
            double speakingEyeOffset = _isSpeaking ? (_speakAnimController.value * 4.0) : 0.0;
            double speakingMouthOpen = _isSpeaking ? (_speakAnimController.value * 1.0) : 0.0;

            double baseHeight = _isBlinking ? 2.0 : _eyeHeight;
            double finalHeight = math.max(1.0, _isBlinking ? 2.0 : (baseHeight + speakingEyeOffset));

            // 🌟 加入微动偏移量
            return AnimatedSlide(
              offset: Offset(_lookOffsetX / 100, _lookOffsetY / 100),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutQuad,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- 眼睛区域 ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.rotate(
                        angle: _tiltAngle,
                        child: _AnimatedEye(width: _eyeWidth, height: finalHeight, radius: _eyeRadius, color: _eyeColor),
                      ),
                      AnimatedContainer(duration: const Duration(milliseconds: 300), width: _spacing),
                      Transform.rotate(
                        angle: -_tiltAngle,
                        child: _AnimatedEye(width: _eyeWidth, height: finalHeight, radius: _eyeRadius, color: _eyeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // --- 🌟 嘴巴区域 ---
                  _AnimatedMouth(
                    smile: _mouthSmile,
                    open: speakingMouthOpen,
                    color: _eyeColor,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// 🌟 1. 极致生动的眼睛组件 (加入瞳孔高光反射)
// ============================================================================
class _AnimatedEye extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color color;

  const _AnimatedEye({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: width,
      height: math.max(1.0, height),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(math.max(0.1, radius)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      // 🌟 新增：利用 ClipRRect 切割出眼球内部的高光反射！
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.max(0.1, radius)),
        child: Align(
          alignment: const Alignment(0.3, -0.6), // 高光永远固定在右上方
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            // 高光的大小会随着眼睛的整体大小等比例缩放
            width: width * 0.35,
            height: height * 0.25,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5), // 半透明白色模拟玻璃反光
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🌟 2. 参数化嘴巴包裹器
// ============================================================================
class _AnimatedMouth extends StatelessWidget {
  final double smile; // -1.0(悲伤) 到 1.0(大笑)
  final double open;  // 0.0(闭嘴) 到 1.0(张大嘴)
  final Color color;

  const _AnimatedMouth({
    required this.smile,
    required this.open,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 使得从“大笑”恢复到“平静”时的曲线过渡极其丝滑
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: smile, end: smile),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, currentSmile, child) {
        return CustomPaint(
          size: const Size(60, 20), // 嘴巴的物理画板大小
          painter: _MouthPainter(
            smile: currentSmile,
            open: open,
            color: color,
          ),
        );
      },
    );
  }
}

// ============================================================================
// 🌟 3. 双贝塞尔曲线真实口型渲染引擎
// ============================================================================
class _MouthPainter extends CustomPainter {
  final double smile;
  final double open;
  final Color color;

  _MouthPainter({
    required this.smile,
    required this.open,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;

    // --- 核心数学逻辑 ---

    // 1. 计算嘴角的 Y 坐标 (受 smile 影响)
    // 如果 smile=1 (笑)，嘴角上扬 (Y变小)；如果 smile=-1 (悲伤)，嘴角下垂 (Y变大)
    final double cornerY = cy - (smile * 8.0);

    // 2. 计算嘴唇中心的基准 Y 坐标
    // 如果是笑脸，嘴巴中心会往下压，配合上扬的嘴角形成 U 型
    final double baseCenterY = cy + (smile * 8.0);

    // 3. 计算上嘴唇和下嘴唇的控制点 (受说话张嘴张力 open 影响)
    // 说话时，上嘴唇微抬，下嘴唇大幅度向下拉伸
    final double upperCy = baseCenterY - (open * 4.0);
    final double lowerCy = baseCenterY + (open * 18.0);

    // --- 绘制路径 ---
    final path = Path();
    path.moveTo(0, cornerY); // 左嘴角

    // 画上嘴唇曲线 (向右)
    path.quadraticBezierTo(size.width / 2, upperCy, size.width, cornerY);

    // 画下嘴唇曲线 (向左画回去，形成闭合口型)
    path.quadraticBezierTo(size.width / 2, lowerCy, 0, cornerY);
    path.close();

    // --- 画笔配置 ---
    // 描边画笔：保证无论是否张嘴，嘴巴都有一条发光的轮廓线
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5);

    // 填充画笔：张开嘴时，内部有半透明的果冻感发光填充
    final fillPaint = Paint()
      ..color = color.withOpacity(open * 0.4) // 张得越大，内部越亮
      ..style = PaintingStyle.fill;

    // 先画内部填充，再画发光外轮廓
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MouthPainter oldDelegate) {
    return oldDelegate.smile != smile ||
        oldDelegate.open != open ||
        oldDelegate.color != color;
  }
}

