import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'screens/portal_screen.dart';
import 'services/adventure_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  
  runApp(const RPGPortalApp());
}

class RPGPortalApp extends StatefulWidget {
  const RPGPortalApp({super.key});

  @override
  State<RPGPortalApp> createState() => _RPGPortalAppState();
}

class _RPGPortalAppState extends State<RPGPortalApp> with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();
  String? _pendingCode;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    final initialLink = await _appLinks.getInitialLink();
    
    if (initialLink != null) {
      _handleLink(initialLink.toString());
    }

    _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) {
        _handleLink(uri.toString());
      }
    });
  }

  void _handleLink(String link) {
    if (link.contains('code=')) {
      final code = Uri.parse(link).queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        setState(() => _pendingCode = code);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _pendingCode != null) {
            _showJoinDialog(_pendingCode!);
          }
        });
      }
    }
  }

  void _showJoinDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Unisciti alla Campagna', style: TextStyle(color: Colors.white)),
        content: Text(
          'Hai ricevuto un invito con codice: *$code*\n\nVuoi unirti ora?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _pendingCode = null);
              Navigator.pop(ctx);
            },
            child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B0FF)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _performJoin(code);
            },
            child: const Text('Unisciti Ora', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _performJoin(String code) async {
    final authService = AuthService();
    if (!authService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devi effettuare il login prima di unirti.'), backgroundColor: Colors.orange),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mi sto unendo con il codice: $code...'), backgroundColor: const Color(0xFF00B0FF)),
    );

    final success = await AdventureService.joinCampaign(campaignCode: code);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unitto con successo! Vai alla tab Giocatore.'), backgroundColor: Color(0xFF00C853)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'unione. Codice non valido o campagna piena.'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _pendingCode = null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.inactive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

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