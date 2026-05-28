/// Continuous facial / mood parameters used by the rendering layer.
///
/// Philosophy: emotions are not discrete buckets, they're a continuous N-dim
/// space.  AI either picks a semantic label + intensity (and we map it to
/// params) or — for advanced control — sends raw param values directly.
/// The renderer (CustomPainter) reads these floats and tweens between
/// successive states for organic, frame-rate-free transitions.
///
/// All values are designed to be safe at 0 (= neutral baseline), so an empty
/// [EmotionParams] gives a calm, alert face.
class EmotionParams {
  /// 眼睛开合度. `0`=完全闭眼, `1`=正常, `1.5`=惊愕大瞪.
  final double eyeOpen;

  /// 眼睛形状. `-1`=向下弧形 (sad ‿‿), `0`=圆睁, `+1`=向上弧形 (happy ^^).
  final double eyeShape;

  /// 眉毛角度. `-1`=外角下垂 (sad ╲╱), `0`=平直 / 无, `+1`=内角下压 (angry ╱╲).
  final double browAngle;

  /// 嘴弧度. `-1`=苦脸 frown, `0`=平直, `+1`=大笑 ︶.
  final double mouthCurve;

  /// 嘴开合度. `0`=闭嘴, `1`=张大 (说话 / 喊叫).
  final double mouthOpen;

  /// 脸颊红晕透明度. `0`=无, `1`=满红.
  final double cheekFlush;

  /// 身体色相偏移. `-1`=偏冷 (sad / 冷漠), `0`=正常 peach, `+1`=偏红 (angry / 害羞).
  final double bodyHueShift;

  /// 颤抖强度. `0`=静止, `1`=剧烈抖动 (用于愤怒 / 恐惧 / 兴奋).
  final double tremor;

  /// 瞳孔水平偏移. `-1`=向左看, `+1`=向右看 (在思考 / 害羞时配合用).
  final double pupilX;

  /// 瞳孔垂直偏移. `-1`=往下看 (难过 / 害羞), `+1`=向上看 (期待 / 仰望).
  final double pupilY;

  /// 整体强度. 1.0=完整表达, 0.0=回归 neutral. 用来给 secondary 情绪降权,
  /// 或者表达"有点开心" (intensity=0.4) vs "极度开心" (intensity=1.0).
  final double intensity;

  const EmotionParams({
    this.eyeOpen = 1.0,
    this.eyeShape = 0.0,
    this.browAngle = 0.0,
    this.mouthCurve = 0.0,
    this.mouthOpen = 0.0,
    this.cheekFlush = 0.0,
    this.bodyHueShift = 0.0,
    this.tremor = 0.0,
    this.pupilX = 0.0,
    this.pupilY = 0.0,
    this.intensity = 1.0,
  });

  // —————————————————— Presets ——————————————————

  static const neutral = EmotionParams();
  static const happy = EmotionParams(
      mouthCurve: 1.0, eyeShape: 0.6, cheekFlush: 0.3);
  static const sad = EmotionParams(
      mouthCurve: -0.8,
      eyeShape: -0.5,
      browAngle: -0.6,
      pupilY: -0.3,
      bodyHueShift: -0.3);
  static const angry = EmotionParams(
      mouthCurve: -0.5,
      browAngle: 0.9,
      eyeOpen: 1.1,
      bodyHueShift: 1.0,
      tremor: 0.5);
  static const surprised = EmotionParams(
      eyeOpen: 1.4, mouthOpen: 0.7, eyeShape: 0.0, browAngle: -0.2);
  static const shy = EmotionParams(
      cheekFlush: 0.9, pupilY: -0.3, eyeShape: 0.3, mouthCurve: 0.2);
  static const thinking = EmotionParams(
      pupilX: 0.5, pupilY: -0.4, mouthCurve: -0.1, browAngle: 0.2);
  static const sleeping = EmotionParams(eyeOpen: 0.0, mouthCurve: 0.1);
  static const love = EmotionParams(
      cheekFlush: 0.7, mouthCurve: 0.7, eyeShape: 0.8, eyeOpen: 0.95);
  static const wink = EmotionParams(mouthCurve: 0.5, eyeShape: 0.4);
  static const speaking = EmotionParams(mouthOpen: 0.4, eyeShape: 0.2);
  static const calm = neutral;
  static const bored = EmotionParams(
      eyeShape: -0.2, mouthCurve: -0.2, eyeOpen: 0.7, pupilY: -0.2);
  static const excited = EmotionParams(
      mouthCurve: 0.9, eyeOpen: 1.2, eyeShape: 0.5, tremor: 0.25,
      cheekFlush: 0.4);
  static const confused = EmotionParams(
      browAngle: 0.4, mouthCurve: -0.15, pupilX: -0.3, pupilY: 0.2);
  static const fear = EmotionParams(
      eyeOpen: 1.3, mouthOpen: 0.3, browAngle: -0.5, tremor: 0.6,
      bodyHueShift: -0.5);

  static const Map<String, EmotionParams> byName = {
    'neutral': neutral,
    'calm': calm,
    'happy': happy,
    'sad': sad,
    'angry': angry,
    'surprised': surprised,
    'shy': shy,
    'thinking': thinking,
    'sleeping': sleeping,
    'love': love,
    'wink': wink,
    'speaking': speaking,
    'bored': bored,
    'excited': excited,
    'confused': confused,
    'fear': fear,
  };

  // —————————————————— Math ——————————————————

  /// Reduce all emotion deltas by [t] (0..1), pulling the face back toward
  /// neutral.  Intensity itself is set to [t] for downstream blending.
  EmotionParams scaled(double t) {
    final c = t.clamp(0.0, 1.0).toDouble();
    return EmotionParams(
      eyeOpen: _lerpD(1.0, eyeOpen, c),
      eyeShape: eyeShape * c,
      browAngle: browAngle * c,
      mouthCurve: mouthCurve * c,
      mouthOpen: mouthOpen * c,
      cheekFlush: cheekFlush * c,
      bodyHueShift: bodyHueShift * c,
      tremor: tremor * c,
      pupilX: pupilX * c,
      pupilY: pupilY * c,
      intensity: c,
    );
  }

  /// Convex blend two emotions (e.g. mostly angry, a bit sad) — used when
  /// AI supplies a secondary emotion + secondaryWeight.
  EmotionParams blend(EmotionParams other, double weight) =>
      lerp(this, other, weight.clamp(0.0, 1.0).toDouble());

  /// Smooth interpolation between two parameter sets — used by the renderer
  /// to animate transitions between successive AI outputs.
  static EmotionParams lerp(EmotionParams a, EmotionParams b, double t) {
    final c = t.clamp(0.0, 1.0).toDouble();
    return EmotionParams(
      eyeOpen: _lerpD(a.eyeOpen, b.eyeOpen, c),
      eyeShape: _lerpD(a.eyeShape, b.eyeShape, c),
      browAngle: _lerpD(a.browAngle, b.browAngle, c),
      mouthCurve: _lerpD(a.mouthCurve, b.mouthCurve, c),
      mouthOpen: _lerpD(a.mouthOpen, b.mouthOpen, c),
      cheekFlush: _lerpD(a.cheekFlush, b.cheekFlush, c),
      bodyHueShift: _lerpD(a.bodyHueShift, b.bodyHueShift, c),
      tremor: _lerpD(a.tremor, b.tremor, c),
      pupilX: _lerpD(a.pupilX, b.pupilX, c),
      pupilY: _lerpD(a.pupilY, b.pupilY, c),
      intensity: _lerpD(a.intensity, b.intensity, c),
    );
  }

  static double _lerpD(double a, double b, double t) => a + (b - a) * t;

  EmotionParams copyWith({
    double? eyeOpen,
    double? eyeShape,
    double? browAngle,
    double? mouthCurve,
    double? mouthOpen,
    double? cheekFlush,
    double? bodyHueShift,
    double? tremor,
    double? pupilX,
    double? pupilY,
    double? intensity,
  }) {
    return EmotionParams(
      eyeOpen: eyeOpen ?? this.eyeOpen,
      eyeShape: eyeShape ?? this.eyeShape,
      browAngle: browAngle ?? this.browAngle,
      mouthCurve: mouthCurve ?? this.mouthCurve,
      mouthOpen: mouthOpen ?? this.mouthOpen,
      cheekFlush: cheekFlush ?? this.cheekFlush,
      bodyHueShift: bodyHueShift ?? this.bodyHueShift,
      tremor: tremor ?? this.tremor,
      pupilX: pupilX ?? this.pupilX,
      pupilY: pupilY ?? this.pupilY,
      intensity: intensity ?? this.intensity,
    );
  }

  // —————————————————— JSON ——————————————————

  /// Parse the wire protocol.  Accepts either:
  ///
  /// **Semantic mode** (preferred for AI):
  /// ```json
  /// { "emotion": "angry", "intensity": 0.85,
  ///   "secondary": "sad", "secondaryWeight": 0.2 }
  /// ```
  ///
  /// **Raw mode** (advanced):
  /// ```json
  /// { "params": { "eyeOpen": 0.3, "browAngle": -0.8,
  ///               "mouthCurve": -0.6, "bodyHueShift": 0.9, "tremor": 0.4 } }
  /// ```
  ///
  /// Mixed objects (`params` + semantic siblings) are allowed; semantic
  /// fields are applied first, then raw params override on top.
  factory EmotionParams.fromJson(dynamic json) {
    if (json is! Map) return neutral;
    final map = Map<String, dynamic>.from(json);

    var base = neutral;

    final emotion = map['emotion'] as String?;
    final intensity =
        (map['intensity'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 1.0;
    if (emotion != null) {
      final preset = byName[emotion.toLowerCase()] ?? neutral;
      base = preset.scaled(intensity.toDouble());
    }

    final secondary = map['secondary'] as String?;
    final secondaryWeight =
        (map['secondaryWeight'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0;
    if (secondary != null && secondaryWeight > 0) {
      final sec = (byName[secondary.toLowerCase()] ?? neutral)
          .scaled(intensity.toDouble());
      base = base.blend(sec, secondaryWeight.toDouble());
    }

    final params = map['params'];
    if (params is Map) {
      double? d(String k) => (params[k] as num?)?.toDouble();
      base = base.copyWith(
        eyeOpen: d('eyeOpen'),
        eyeShape: d('eyeShape'),
        browAngle: d('browAngle'),
        mouthCurve: d('mouthCurve'),
        mouthOpen: d('mouthOpen'),
        cheekFlush: d('cheekFlush'),
        bodyHueShift: d('bodyHueShift'),
        tremor: d('tremor'),
        pupilX: d('pupilX'),
        pupilY: d('pupilY'),
        intensity: d('intensity'),
      );
    }

    return base;
  }

  Map<String, dynamic> toJson() => {
        'params': {
          'eyeOpen': eyeOpen,
          'eyeShape': eyeShape,
          'browAngle': browAngle,
          'mouthCurve': mouthCurve,
          'mouthOpen': mouthOpen,
          'cheekFlush': cheekFlush,
          'bodyHueShift': bodyHueShift,
          'tremor': tremor,
          'pupilX': pupilX,
          'pupilY': pupilY,
          'intensity': intensity,
        },
      };

  @override
  bool operator ==(Object other) =>
      other is EmotionParams &&
      other.eyeOpen == eyeOpen &&
      other.eyeShape == eyeShape &&
      other.browAngle == browAngle &&
      other.mouthCurve == mouthCurve &&
      other.mouthOpen == mouthOpen &&
      other.cheekFlush == cheekFlush &&
      other.bodyHueShift == bodyHueShift &&
      other.tremor == tremor &&
      other.pupilX == pupilX &&
      other.pupilY == pupilY &&
      other.intensity == intensity;

  @override
  int get hashCode => Object.hash(eyeOpen, eyeShape, browAngle, mouthCurve,
      mouthOpen, cheekFlush, bodyHueShift, tremor, pupilX, pupilY, intensity);
}
