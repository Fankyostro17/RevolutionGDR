import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'main_dashboard_screen.dart';

void main() => runApp(const RPGPortalApp());

class RPGPortalApp extends StatelessWidget {
  const RPGPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RPG Portal',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFF6A1B9A),
      ),
      home: const PortalScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PortalScreen extends StatefulWidget {
  const PortalScreen({super.key});

  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _glowController;
  late final AnimationController _auraController1;
  late final AnimationController _auraController2;
  late final AnimationController _auraController3;
  late final AnimationController _lightningRotationController;
  late final AnimationController _lightning1Controller;
  late final AnimationController _lightning2Controller;
  late final AnimationController _lightning3Controller;
  late final AnimationController _lightning4Controller;
  late final AnimationController _transitionController;
  
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _aura1Radius;
  late final Animation<double> _aura1Opacity;
  late final Animation<double> _aura2Radius;
  late final Animation<double> _aura2Opacity;
  late final Animation<double> _aura3Radius;
  late final Animation<double> _aura3Opacity;
  late final Animation<double> _lightning1Pulse;
  late final Animation<double> _lightning2Pulse;
  late final Animation<double> _lightning3Pulse;
  late final Animation<double> _lightning4Pulse;
  late final Animation<double> _scaleTransition;
  late final Animation<Color?> _bgTransition;
  late final Animation<double> _opacityTransition;
  
  bool _isAnimating = false;

  static const List<List<Offset>> _lightningPaths = [
    [Offset(100, 40), Offset(105, 55), Offset(100, 60), Offset(108, 75), Offset(100, 80)],
    [Offset(100, 160), Offset(95, 145), Offset(100, 140), Offset(92, 125), Offset(100, 120)],
    [Offset(160, 100), Offset(145, 105), Offset(140, 100), Offset(125, 108), Offset(120, 100)],
    [Offset(40, 100), Offset(55, 95), Offset(60, 100), Offset(75, 92), Offset(80, 100)],
  ];

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _auraController1 = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _auraController2 = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _auraController3 = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    )..repeat(reverse: true);

    _lightningRotationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _lightning1Controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _lightning2Controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _lightning3Controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _lightning4Controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _aura1Radius = Tween<double>(begin: 0.60, end: 0.80).animate(
      CurvedAnimation(parent: _auraController1, curve: Curves.easeInOut),
    );
    _aura1Opacity = Tween<double>(begin: 0.2, end: 0.4).animate(
      CurvedAnimation(parent: _auraController1, curve: Curves.easeInOut),
    );

    _aura2Radius = Tween<double>(begin: 0.45, end: 0.65).animate(
      CurvedAnimation(parent: _auraController2, curve: Curves.easeInOut),
    );
    _aura2Opacity = Tween<double>(begin: 0.3, end: 0.5).animate(
      CurvedAnimation(parent: _auraController2, curve: Curves.easeInOut),
    );

    _aura3Radius = Tween<double>(begin: 0.80, end: 1.00).animate(
      CurvedAnimation(parent: _auraController3, curve: Curves.easeInOut),
    );
    _aura3Opacity = Tween<double>(begin: 0.15, end: 0.3).animate(
      CurvedAnimation(parent: _auraController3, curve: Curves.easeInOut),
    );

    _lightning1Pulse = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _lightning1Controller, curve: Curves.easeInOut),
    );
    _lightning2Pulse = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _lightning2Controller, curve: Curves.easeInOut),
    );
    _lightning3Pulse = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _lightning3Controller, curve: Curves.easeInOut),
    );
    _lightning4Pulse = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _lightning4Controller, curve: Curves.easeInOut),
    );

    _scaleTransition = Tween<double>(begin: 1.0, end: 30.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeInCubic),
    );

    _bgTransition = ColorTween(begin: Colors.black, end: const Color(0xFFE0F7FA)).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeIn),
    );

    _opacityTransition = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _lightning2Controller.value = 0.25;
    _lightning3Controller.value = 0.50;
    _lightning4Controller.value = 0.75;
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _auraController1.dispose();
    _auraController2.dispose();
    _auraController3.dispose();
    _lightningRotationController.dispose();
    _lightning1Controller.dispose();
    _lightning2Controller.dispose();
    _lightning3Controller.dispose();
    _lightning4Controller.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _enterPortal() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);

    _transitionController.forward().whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainDashboardScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final portalSize = screenSize.width * 0.7;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _transitionController,
        _pulseController,
        _glowController,
        _rotationController,
        _auraController1,
        _auraController2,
        _auraController3,
        _lightningRotationController,
        _lightning1Controller,
        _lightning2Controller,
        _lightning3Controller,
        _lightning4Controller,
      ]),
      builder: (_, __) {
        return Scaffold(
          backgroundColor: _isAnimating ? _bgTransition.value : Colors.black,
          body: Opacity(
            opacity: _isAnimating ? _opacityTransition.value : 1.0,
            child: Stack(
              children: [
                Positioned(
                  bottom: screenSize.height * 0.12,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _isAnimating ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFE6C229), Color(0xFF00E5FF), Color(0xFFD500F9)],
                        stops: [0.2, 0.5, 0.8],
                      ).createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'Tocca per entrare',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4.0,
                          shadows: [
                            Shadow(color: Colors.cyanAccent, blurRadius: 12, offset: Offset.zero),
                            Shadow(color: Colors.purpleAccent, blurRadius: 18, offset: Offset.zero),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                Center(
                  child: IgnorePointer(
                    ignoring: _isAnimating,
                    child: GestureDetector(
                      onTap: _enterPortal,
                      child: Transform.scale(
                        scale: _isAnimating ? _scaleTransition.value : _pulseAnimation.value,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: portalSize,
                          height: portalSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: portalSize * _aura3Radius.value,
                                height: portalSize * _aura3Radius.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF80DEEA).withOpacity(_aura3Opacity.value),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: portalSize * _aura1Radius.value,
                                height: portalSize * _aura1Radius.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF5E35B1).withOpacity(_aura1Opacity.value),
                                    width: 3,
                                  ),
                                ),
                              ),
                              Container(
                                width: portalSize * _aura2Radius.value,
                                height: portalSize * _aura2Radius.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF00B0FF).withOpacity(_aura2Opacity.value),
                                    width: 2,
                                  ),
                                ),
                              ),
                              Transform.rotate(
                                angle: _lightningRotationController.value * 2 * math.pi,
                                child: CustomPaint(
                                  size: Size(portalSize, portalSize),
                                  painter: _LightningPainter(
                                    paths: _lightningPaths,
                                    pulses: [
                                      _lightning1Pulse.value,
                                      _lightning2Pulse.value,
                                      _lightning3Pulse.value,
                                      _lightning4Pulse.value,
                                    ],
                                  ),
                                ),
                              ),
                              Transform.rotate(
                                angle: _rotationController.value * 2 * math.pi,
                                child: Container(
                                  width: portalSize,
                                  height: portalSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF5E35B1).withOpacity(_glowAnimation.value),
                                        blurRadius: 80,
                                        spreadRadius: 20,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF00B0FF).withOpacity(_glowAnimation.value * 0.7),
                                        blurRadius: 60,
                                        spreadRadius: 10,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF80DEEA).withOpacity(_glowAnimation.value * 0.5),
                                        blurRadius: 40,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                    gradient: const RadialGradient(
                                      colors: [
                                        Color(0x00000000),
                                        Color(0x401A237E),
                                        Color(0x605E35B1),
                                        Color(0x8000B0FF),
                                        Color(0x0080DEEA),
                                      ],
                                      stops: [0.0, 0.4, 0.65, 0.85, 1.0],
                                      radius: 1.5,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: SvgPicture.asset(
                                      'assets/svg/portal.svg',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LightningPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<double> pulses;

  _LightningPainter({required this.paths, required this.pulses});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200;
    
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final pulse = pulses[i];
      
      final scaledPath = Path();
      for (int j = 0; j < path.length; j++) {
        final point = path[j];
        final scaledPoint = Offset(point.dx * scale, point.dy * scale);
        if (j == 0) {
          scaledPath.moveTo(scaledPoint.dx, scaledPoint.dy);
        } else {
          scaledPath.lineTo(scaledPoint.dx, scaledPoint.dy);
        }
      }

      final blurPaint = Paint()
        ..color = const Color(0xFF80DEEA).withOpacity(pulse * 0.4)
        ..strokeWidth = (1.0 + pulse * 3.0) * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawPath(scaledPath, blurPaint);

      final gradient = LinearGradient(
        colors: [
          Colors.white.withOpacity(pulse),
          const Color(0xFF80DEEA).withOpacity(pulse * 0.8),
          const Color(0xFF00B0FF).withOpacity(pulse * 0.6),
        ],
      );

      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      final corePaint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = (1.0 + pulse) * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(scaledPath, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightningPainter oldDelegate) {
    return true;
  }
}