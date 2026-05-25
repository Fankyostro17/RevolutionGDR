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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<Color?> _bgAnimation;
  late final Animation<double> _opacityAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 30.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInCubic,
    ));

    _bgAnimation = ColorTween(
      begin: Colors.black,
      end: const Color(0xFFE0F7FA),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enterPortal() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);

    _controller.forward().whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainDashboardScreen(), // ✅ Ora punta al file esterno
          transitionDuration: Duration.zero,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Scaffold(
          backgroundColor: _bgAnimation.value,
          body: Opacity(
            opacity: _opacityAnimation.value,
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
                            Shadow(
                              color: Colors.cyanAccent,
                              blurRadius: 12,
                              offset: Offset.zero,
                            ),
                            Shadow(
                              color: Colors.purpleAccent,
                              blurRadius: 18,
                              offset: Offset.zero,
                            ),
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
                        scale: _scaleAnimation.value,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: screenSize.width * 0.7,
                          height: screenSize.width * 0.7,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF5E35B1).withOpacity(0.4),
                                  blurRadius: 80,
                                  spreadRadius: 20,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF00B0FF).withOpacity(0.3),
                                  blurRadius: 60,
                                  spreadRadius: 10,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF80DEEA).withOpacity(0.2),
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
                                'assets/portal.svg',
                                fit: BoxFit.cover,
                              ),
                            ),
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