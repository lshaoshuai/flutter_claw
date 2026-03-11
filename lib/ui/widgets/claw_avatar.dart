import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../events/event_bus.dart';

/// Agent 的视觉具身化组件 (具备环境感知与物理形变能力)
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
  double _mouthSmile = 0.0; // 嘴巴弧度: 1.0(大笑), 0.0(平直), -1.0(悲伤)
  Color _eyeColor = Colors.cyanAccent;

  // --- 🌟 生物特征状态 ---
  bool _isSpeaking = false;
  bool _isBlinking = false;
  double _soundLevel = 0.0; // 当前感知到的主人音量 (决定声波震颤幅度)

  // 眼球微动偏移量 (模拟真实生命体的扫视)
  double _lookOffsetX = 0.0;
  double _lookOffsetY = 0.0;

  // --- 🌟 神经枢纽订阅 ---
  late StreamSubscription _faceSub;
  late StreamSubscription _speakingSub;
  late StreamSubscription _listeningSub;

  // --- 🌟 定时器与动画 ---
  late Timer _blinkTimer;
  late Timer _saccadeTimer;
  Timer? _emotionResetTimer; // 情绪回弹定时器

  late AnimationController _speakAnimController;

  @override
  void initState() {
    super.initState();

    // 1. 监听大模型的底层几何参数修改 (情绪突变)
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

        // 触发极端情绪后，设定 4 秒后自动回落到平静状态
        _emotionResetTimer?.cancel();
        _emotionResetTimer = Timer(const Duration(seconds: 4), _resetToNeutral);
      }
    });

    // 2. 监听 Agent 自身的说话状态 (嘴巴开合与呼吸感)
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

    // 3. 监听主人的说话音量 (听觉物理反馈)
    _listeningSub = EventBus().on<ListeningLevelEvent>().listen((event) {
      if (mounted) {
        setState(() {
          // 过滤掉微小底噪，放大有效音量，让视觉反馈更明显
          _soundLevel = event.level > 2.0 ? event.level : 0.0;
        });
      }
    });

    // 4. 启动生命体征引擎
    _startRandomBlinking();
    _startSaccadeEngine();
  }

  /// 情绪回落基准线 (恢复成高冷的平静状态)
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

  /// 眼球无意识微动引擎 (Saccades)
  void _startSaccadeEngine() {
    final random = math.Random();
    _saccadeTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted && !_isSpeaking && _soundLevel == 0) {
        // 偶尔向四周随机看一眼
        if (random.nextDouble() > 0.4) {
          setState(() {
            _lookOffsetX = (random.nextDouble() - 0.5) * 12;
            _lookOffsetY = (random.nextDouble() - 0.5) * 6;
          });
          // 300毫秒后立刻收回视线
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() { _lookOffsetX = 0; _lookOffsetY = 0; });
          });
        }
      }
    });
  }

  /// 随机眨眼机制
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
    _listeningSub.cancel();
    _blinkTimer.cancel();
    _saccadeTimer.cancel();
    _emotionResetTimer?.cancel();
    _speakAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      color: Colors.black87, // 极客深邃黑底
      child: Center(
        child: AnimatedBuilder(
          animation: _speakAnimController,
          builder: (context, child) {
            // --- 🌟 动态形变计算核心 ---

            // Agent 自身说话时的振幅
            double speakingEyeOffset = _isSpeaking ? (_speakAnimController.value * 4.0) : 0.0;
            double speakingMouthOpen = _isSpeaking ? (_speakAnimController.value * 1.0) : 0.0;

            // 监听主人声音时的物理压迫感 (声波越大，眼睛越宽越扁，显得极为专注)
            double soundDistortionX = _soundLevel * 0.4;
            double soundDistortionY = _soundLevel * 0.2;

            // 叠加所有状态计算最终高宽
            double baseHeight = _isBlinking ? 2.0 : _eyeHeight;
            double finalHeight = math.max(1.0, _isBlinking ? 2.0 : (baseHeight + speakingEyeOffset - soundDistortionY));
            double finalWidth = math.max(10.0, _eyeWidth + soundDistortionX);

            // 如果正在专心听主人说话，锁定视线，停止微动
            double currentOffsetX = _soundLevel > 0 ? 0.0 : _lookOffsetX;
            double currentOffsetY = _soundLevel > 0 ? 0.0 : _lookOffsetY;

            return AnimatedSlide(
              offset: Offset(currentOffsetX / 100, currentOffsetY / 100),
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
                        child: _AnimatedEye(
                          width: finalWidth,
                          height: finalHeight,
                          radius: _eyeRadius,
                          color: _eyeColor,
                          soundLevel: _soundLevel, // 传入音量，控制高频光晕闪烁
                        ),
                      ),
                      AnimatedContainer(duration: const Duration(milliseconds: 300), width: _spacing),
                      Transform.rotate(
                        angle: -_tiltAngle,
                        child: _AnimatedEye(
                          width: finalWidth,
                          height: finalHeight,
                          radius: _eyeRadius,
                          color: _eyeColor,
                          soundLevel: _soundLevel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // --- 嘴巴区域 ---
                  _AnimatedMouth(
                    smile: _mouthSmile,
                    // 如果正在听主人说话，嘴巴微微张开一条缝隙 (高度拟真)
                    open: math.max(speakingMouthOpen, _soundLevel > 0 ? 0.15 : 0.0),
                    color: _eyeColor,
                    soundLevel: _soundLevel,
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
// 🌟 1. 极致生动的眼睛组件 (加入听觉光晕暴击与高光反射)
// ============================================================================
class _AnimatedEye extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color color;
  final double soundLevel;

  const _AnimatedEye({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    this.soundLevel = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // 声波直接决定光晕爆发大小
    double blurRadius = 15.0 + (soundLevel * 1.2);
    double spreadRadius = 2.0 + (soundLevel * 0.5);

    return AnimatedContainer(
      // 🌟 极短的持续时间，完美还原声音的高频震颤感
      duration: const Duration(milliseconds: 60),
      curve: Curves.easeOut,
      width: width,
      height: math.max(1.0, height),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(math.max(0.1, radius)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(soundLevel > 0 ? 0.9 : 0.6), // 听到声音变极亮
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
      // 利用 ClipRRect 切割出眼球内部的高光反射
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.max(0.1, radius)),
        child: Align(
          alignment: const Alignment(0.3, -0.6), // 高光固定在右上方
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150), // 高光变化相对平缓
            width: width * 0.35,
            height: height * 0.25,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🌟 2. 参数化嘴巴包裹器 (管理丝滑过渡)
// ============================================================================
class _AnimatedMouth extends StatelessWidget {
  final double smile;
  final double open;
  final Color color;
  final double soundLevel;

  const _AnimatedMouth({
    required this.smile,
    required this.open,
    required this.color,
    this.soundLevel = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: smile, end: smile),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, currentSmile, child) {
        return CustomPaint(
          size: const Size(60, 20),
          painter: _MouthPainter(
            smile: currentSmile,
            open: open,
            color: color,
            soundLevel: soundLevel,
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
  final double soundLevel;

  _MouthPainter({
    required this.smile,
    required this.open,
    required this.color,
    this.soundLevel = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;

    // 嘴角控制
    final double cornerY = cy - (smile * 8.0);
    final double baseCenterY = cy + (smile * 8.0);

    // 嘴唇开合张力控制
    final double upperCy = baseCenterY - (open * 4.0);
    final double lowerCy = baseCenterY + (open * 18.0);

    // 绘制曲线路径
    final path = Path();
    path.moveTo(0, cornerY);
    path.quadraticBezierTo(size.width / 2, upperCy, size.width, cornerY);
    path.quadraticBezierTo(size.width / 2, lowerCy, 0, cornerY);
    path.close();

    // 听到声音时，嘴巴的外轮廓描边随着声波变粗并发出高光
    final strokePaint = Paint()
      ..color = color.withOpacity(soundLevel > 0 ? 1.0 : 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 + (soundLevel * 0.1)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5);

    // 张开嘴时内部的果冻感发光填充
    final fillPaint = Paint()
      ..color = color.withOpacity(math.min(1.0, open * 0.4 + (soundLevel * 0.01)))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MouthPainter oldDelegate) {
    return oldDelegate.smile != smile ||
        oldDelegate.open != open ||
        oldDelegate.color != color ||
        oldDelegate.soundLevel != soundLevel;
  }
}