import 'package:flutter/material.dart';
import 'screens/portal_screen.dart';

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
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          elevation: 0,
        ),
      ),
      home: const PortalScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}