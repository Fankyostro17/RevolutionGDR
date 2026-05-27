import 'package:flutter/material.dart';
import '../widgets/adventure_card.dart';
import '../models/adventure.dart';
import '../services/auth_service.dart';
import '../services/adventure_service.dart';
import '../models/user.dart';
import 'login_screen.dart';
import 'create_campaign_screen.dart';
import 'campaign_detail_screen.dart';
import 'join_campaign_screen.dart'; // ← Nuova schermata per unirsi (la creiamo dopo)

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AuthService _authService;
  
  bool _isLoggedIn = false;
  AppUser? _user;
  
  List<Adventure> _masterAdventures = [];
  List<Adventure> _playerAdventures = [];
  bool _isLoadingAdventures = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _authService = AuthService();
    _initAuth();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _authService.dispose();
    super.dispose();
  }

  Future<void> _initAuth() async {
    await _authService.init();
    if (mounted) {
      setState(() {
        _isLoggedIn = _authService.isAuthenticated;
        _user = _authService.currentUser;
      });
      if (_isLoggedIn) _fetchAdventures();
    }
  }

  Future<void> _fetchAdventures() async {
    if (!_isLoggedIn) return;
    
    setState(() => _isLoadingAdventures = true);
    
    try {
      final results = await Future.wait([
        AdventureService.fetchAdventures(role: AdventureRole.master),
        AdventureService.fetchAdventures(role: AdventureRole.player),
      ]);
      
      if (mounted) {
        setState(() {
          _masterAdventures = results[0];
          _playerAdventures = results[1];
          _isLoadingAdventures = false;
        });
      }
    } catch (e) {
      print('❌ Errore fetch avventure: $e');
      if (mounted) {
        setState(() => _isLoadingAdventures = false);
      }
    }
  }

  void _refreshAuth() {
    setState(() {
      _isLoggedIn = _authService.isAuthenticated;
      _user = _authService.currentUser;
    });
  }

  Future<void> _navigateToLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    
    if (result == true && mounted) {
      _refreshAuth();
      _fetchAdventures();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Benvenuto, ${_user?.displayName ?? 'avventuriero'}!'),
          backgroundColor: const Color(0xFF00C853),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _navigateToCreateCampaign() async {
    if (!_isLoggedIn) {
      _navigateToLogin();
      return;
    }
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateCampaignScreen()),
    );
    
    if (result == true && mounted) {
      await _fetchAdventures();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Campagna creata con successo!'),
          backgroundColor: Color(0xFF00C853),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _navigateToJoinCampaign() async {
    if (!_isLoggedIn) {
      _navigateToLogin();
      return;
    }
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const JoinCampaignScreen()),
    );
    
    if (result == true && mounted) {
      await _fetchAdventures();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Unitto alla campagna!'),
          backgroundColor: Color(0xFF00C853),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _navigateToCampaignDetail(String adventureId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignDetailScreen(adventureId: adventureId),
      ),
    );
    
    if (result == true && mounted) {
      await _fetchAdventures();
    }
  }

  Widget _buildAdventureList(bool isMasterView) {
    if (_isLoadingAdventures) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00B0FF)),
      );
    }
    
    final adventures = isMasterView ? _masterAdventures : _playerAdventures;

    if (adventures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMasterView ? Icons.book_outlined : Icons.diamond_outlined,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              isMasterView 
                ? 'Nessuna campagna attiva\nCrea la tua prima avventura!' 
                : 'Nessuna avventura in corso\nUnisciti a una campagna!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // 🔹 FIX #1 e #2: Bottone condizionale basato su login e ruolo
            if (!_isLoggedIn)
              // ❌ Non loggato: mostra "Accedi per unirti" per entrambi
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B0FF),
                  foregroundColor: Colors.black,
                ),
                onPressed: _navigateToLogin,
                icon: const Icon(Icons.login),
                label: const Text('Accedi per unirti'),
              )
            else if (isMasterView)
              // ✅ Loggato + Master: mostra "Crea Campagna"
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B0FF),
                  foregroundColor: Colors.black,
                ),
                onPressed: _navigateToCreateCampaign,
                icon: const Icon(Icons.add),
                label: const Text('Crea Campagna'),
              )
            else
              // ✅ Loggato + Player: mostra "Accedi alla Campagna" (con codice)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B0FF),
                  foregroundColor: Colors.black,
                ),
                onPressed: _navigateToJoinCampaign,
                icon: const Icon(Icons.qr_code),
                label: const Text('Accedi alla Campagna'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: adventures.length + (isMasterView ? 1 : 0),
      itemBuilder: (ctx, index) {
        // 🔹 Pulsante "Nuova Campagna" o "Unisciti" in fondo alla lista
        if (index == adventures.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00B0FF),
                side: const BorderSide(color: Color(0xFF00B0FF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isMasterView 
                ? _navigateToCreateCampaign 
                : _navigateToJoinCampaign, // ← Player: unisciti con codice
              icon: Icon(isMasterView ? Icons.add : Icons.qr_code),
              label: Text(isMasterView ? 'Nuova Campagna' : 'Unisciti con Codice'),
            ),
          );
        }

        final adventure = adventures[index];
        
        return AdventureCard(
          title: adventure.title,
          subtitle: adventure.subtitle,
          description: adventure.description,
          role: adventure.role,
          nextSession: adventure.nextSession,
          lastSession: adventure.lastSession,
          levelMin: adventure.levelMin,
          levelMax: adventure.levelMax,
          maxPlayers: adventure.maxPlayers,
          currentPlayers: adventure.currentPlayers,
          joinCode: adventure.joinCode,
          isOneShot: adventure.isOneShot,
          adventureId: adventure.id,
          createdBy: adventure.createdBy,
          status: adventure.status,
          isLocked: adventure.status == AdventureStatus.locked || adventure.status == AdventureStatus.ended,
          onTap: adventure.isAccessible ? () {
            _navigateToCampaignDetail(adventure.id);
          } : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('🐉 Il Tavolo'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        
        // 🔹 FIX #3: Rimuovi la freccia indietro quando loggato
        leading: _isLoggedIn ? null : null, // ← null = nessun leading, niente freccia
        
        actions: [
          if (_isLoggedIn && _user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF00B0FF).withOpacity(0.3),
                    child: Text(
                      _user!.initial,
                      style: const TextStyle(color: Color(0xFF00B0FF), fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _user!.displayName,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 20, color: Colors.white54),
                    onPressed: () async {
                      await _authService.logout();
                      if (mounted) {
                        setState(() {
                          _isLoggedIn = false;
                          _user = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('👋 Logout effettuato'),
                            backgroundColor: Color(0xFF6A1B9A),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.white),
              onPressed: _navigateToLogin,
              tooltip: 'Accedi',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00B0FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.shield), text: 'Master'),
            Tab(icon: Icon(Icons.person), text: 'Giocatore'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAdventureList(true),
          _buildAdventureList(false),
        ],
      ),
    );
  }
}