import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/adventure.dart';
import '../services/auth_service.dart';
import '../services/game_socket_service.dart';

class DiceRoll {
  final String id;
  final String author;
  final String expression;
  final List<int> individualRolls;
  final int total;
  final DateTime timestamp;
  final bool isHidden;
  final bool isMasterRoll;

  DiceRoll({
    required this.id,
    required this.author,
    required this.expression,
    required this.individualRolls,
    required this.total,
    required this.timestamp,
    this.isHidden = false,
    this.isMasterRoll = false,
  });

  String getDisplayContent(bool viewerIsMaster) {
    if (isHidden && !viewerIsMaster) {
      return '🎲 **Roll Nascosto** di $author';
    }
    final rolls = individualRolls.join(', ');
    return '🎲 `$expression`: [$rolls] = **$total** ${isMasterRoll ? '🛡️' : ''}';
  }
}

// 🔹 FIX #2: Parser dadi CORRETTO con Random e calcoli precisi
class DiceParser {
  static final _random = Random();
  
  // Regex per trovare pattern NdM (es: 2d8, d6, 10d20)
  static final _diceRegex = RegExp(r'(\d*)d(\d+)', caseSensitive: false);
  
  static DiceRollResult parse(String expression, String author, bool isMaster, {bool isHidden = false}) {
    // Rimuovi spazi per parsing più semplice
    final cleanExpr = expression.replaceAll(' ', '').toLowerCase();
    
    int total = 0;
    final List<int> allRolls = [];
    final List<String> rollDetails = [];
    
    // 🔹 Step 1: Estrai e calcola tutti i dadi
    String remainingExpr = cleanExpr;
    
    for (final match in _diceRegex.allMatches(cleanExpr)) {
      final countStr = match.group(1);
      final sidesStr = match.group(2);
      
      if (sidesStr == null) continue;
      
      final count = countStr != null && countStr.isNotEmpty ? int.parse(countStr) : 1;
      final sides = int.parse(sidesStr);
      
      // 🔹 FIX: Genera valori casuali INDIPENDENTI per ogni dado
      final rolls = List.generate(count, (_) => _random.nextInt(sides) + 1);
      final sum = rolls.reduce((a, b) => a + b);
      
      total += sum;
      allRolls.addAll(rolls);
      rollDetails.add('${count}d$sides: [$rolls]');
      
      // Rimuovi il dado processato dall'espressione per gestire i modificatori
      remainingExpr = remainingExpr.replaceFirst(match.group(0)!, '');
    }
    
    // 🔹 Step 2: Estrai e applica i modificatori numerici (+4, -2, ecc.)
    // Regex per numeri con segno: +4, -2, +10, ecc.
    final modifierRegex = RegExp(r'[+\-]\d+');
    for (final match in modifierRegex.allMatches(remainingExpr)) {
      final value = int.tryParse(match.group(0)!) ?? 0;
      total += value;
    }
    
    // 🔹 Step 3: Se ci sono numeri "nudi" senza segno all'inizio, aggiungili (es: "5 + 2d6" → il 5 è bonus)
    final bareNumberRegex = RegExp(r'^\d+');
    final bareMatch = bareNumberRegex.firstMatch(remainingExpr);
    if (bareMatch != null) {
      total += int.tryParse(bareMatch.group(0)!) ?? 0;
    }
    
    return DiceRollResult(
      expression: expression,
      total: total,
      individualRolls: allRolls,
      details: rollDetails.join(' + '),
      author: author,
      isHidden: isHidden,
      isMasterRoll: isMaster,
    );
  }
}

class DiceRollResult {
  final String expression;
  final int total;
  final List<int> individualRolls;
  final String details;
  final String author;
  final bool isHidden;
  final bool isMasterRoll;

  DiceRollResult({
    required this.expression,
    required this.total,
    required this.individualRolls,
    required this.details,
    required this.author,
    this.isHidden = false,
    this.isMasterRoll = false,
  });
}

class GameSessionScreen extends StatefulWidget {
  final Adventure adventure;
  const GameSessionScreen({super.key, required this.adventure});

  @override
  State<GameSessionScreen> createState() => _GameSessionScreenState();
}

class _GameSessionScreenState extends State<GameSessionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  
  bool _isSidebarOpen = true;
  bool _isMaster = false;
  bool _isHosting = false;
  double _sidebarWidth = 340;
  
  final _socketService = GameSocketService();
  
  Timer? _connectionTimeoutTimer;
  int _timeoutSecondsRemaining = 5;
  
  final AudioPlayer _bgMusicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  double _musicVolume = 0.5;
  String? _currentTrack;
  final List<Map<String, dynamic>> _tracks = [
    {'id': 't1', 'name': 'Taverna Medievale', 'type': 'music', 'url': 'assets/audio/tavern.mp3'},
    {'id': 't2', 'name': 'Foresta Oscura', 'type': 'music', 'url': 'assets/audio/forest.mp3'},
    {'id': 't3', 'name': 'Battaglia Epica', 'type': 'music', 'url': 'assets/audio/battle.mp3'},
  ];
  final List<Map<String, dynamic>> _sfx = [
    {'id': 's1', 'name': '🌧️ Pioggia', 'url': 'assets/sfx/rain.mp3'},
    {'id': 's2', 'name': '🔥 Fuoco', 'url': 'assets/sfx/fire.mp3'},
    {'id': 's3', 'name': '⚔️ Spade', 'url': 'assets/sfx/swords.mp3'},
    {'id': 's4', 'name': '🌬️ Vento', 'url': 'assets/sfx/wind.mp3'},
  ];

  final List<DiceRoll> _diceRolls = [];
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  bool _hideRollFromPlayers = false;

  final List<Map<String, dynamic>> _files = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isMaster = AuthService().currentUser?.id == widget.adventure.createdBy;
    
    if (!_isMaster) {
      _socketService.onHostStatusChanged = _onRemoteHostStatusChanged;
      _socketService.onNewMessage = _onRemoteMessageReceived;
      _socketService.onSystemMessage = _addSystemMessage;
      
      _socketService.connect(
        widget.adventure.id,
        AuthService().currentUser?.id ?? 'unknown',
        AuthService().currentUser?.nickname ?? 'Guest',
      );
    }
    
    if (!_isMaster && !_isHosting) {
      _timeoutSecondsRemaining = 5;
      _connectionTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _timeoutSecondsRemaining--;
          if (_timeoutSecondsRemaining <= 0) {
            timer.cancel();
            _handleConnectionTimeout();
          }
        });
      });
    }
    
    _addSystemMessage('🎮 Sessione caricata. ${_isMaster ? "Sei il Master. Avvia l'host per i giocatori." : "Attendi che il Master avvii la sessione (timeout: 5s)..."}');
    _files.add({'name': 'Mappa_Iniziale.png', 'type': 'image', 'size': '2.4 MB'});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _bgMusicPlayer.dispose();
    _sfxPlayer.dispose();
    _connectionTimeoutTimer?.cancel();
    
    if (!_isMaster) {
      _socketService.disconnect();
    }
    
    super.dispose();
  }

  // 🔹 NUOVO: Gestisce cambio stato host ricevuto dal server
  void _onRemoteHostStatusChanged(bool isHosting) {
    if (mounted) {
      setState(() => _isHosting = isHosting);
      
      // Se l'host è appena stato avviato e siamo un giocatore, cancella il timeout
      if (isHosting && !_isMaster && _connectionTimeoutTimer?.isActive == true) {
        _connectionTimeoutTimer?.cancel();
        _addSystemMessage('🟢 Host rilevato! Connessione stabilita.');
      }
    }
  }

  // 🔹 NUOVO: Gestisce messaggi chat/dadi ricevuti dal server
  void _onRemoteMessageReceived(Map<String, dynamic> msg) {
    if (!mounted) return;
    
    setState(() {
      if (msg['type'] == 'dice') {
        // Ricostruisci DiceRoll dal JSON ricevuto
        final diceRoll = DiceRoll(
          id: msg['id'] as String,
          author: msg['author'] as String,
          expression: msg['expression'] as String,
          individualRolls: List<int>.from(msg['individualRolls'] as List),
          total: msg['total'] as int,
          timestamp: DateTime.parse(msg['timestamp'] as String),
          isHidden: msg['isHidden'] as bool? ?? false,
          isMasterRoll: msg['isMasterRoll'] as bool? ?? false,
        );
        _diceRolls.insert(0, diceRoll);
        _chatMessages.add({
          'type': 'dice',
          'diceRoll': diceRoll,
          'time': DateTime.now(),
        });
      } else {
        // Chat normale
        _chatMessages.add({
          'type': 'chat',
          'content': msg['content'] as String,
          'author': msg['author'] as String,
          'time': DateTime.parse(msg['time'] as String),
        });
      }
    });
    _scrollChatToBottom();
  }

  // 🔹 FIX #5: Timeout connessione - esci automaticamente dopo 5 secondi
  void _handleConnectionTimeout() {
    if (mounted && !_isMaster && !_isHosting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ Timeout: impossibile connettersi all\'host'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context); // Torna alla dashboard
    }
  }

  // 🔹 Aggiungi messaggio di sistema
  void _addSystemMessage(String content) {
    setState(() {
      _chatMessages.add({
        'type': 'system',
        'content': content,
        'time': DateTime.now(),
      });
    });
    _scrollChatToBottom();
  }

  void _addChatMessage(String content, {String? author}) {
    if (content.trim().isEmpty) return;
    
    final currentUser = AuthService().currentUser;
    final senderName = author ?? currentUser?.nickname ?? 'Tu';
    
    if (content.trim().startsWith('/rd')) {
      final expr = content.substring(3).trim();
      if (expr.isNotEmpty) {
        _parseAndRollDice(expr, senderName);
        _chatCtrl.clear();
        return;
      }
    }
    
    final messageData = {
      'type': 'chat',
      'content': content,
      'author': senderName,
      'time': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _chatMessages.add({
        'type': 'chat',
        'content': content,
        'author': senderName,
        'time': DateTime.now(),
      });
    });
    _chatCtrl.clear();
    _scrollChatToBottom();
    
    if (_isMaster || _isHosting) {
      _socketService.sendMessage(
        widget.adventure.id,
        messageData,
      );
    }
  }

  void _parseAndRollDice(String expression, String author) {
    try {
      final result = DiceParser.parse(
        expression,
        author,
        _isMaster,
        isHidden: _hideRollFromPlayers && _isMaster,
      );
      
      final diceRoll = DiceRoll(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        author: author,
        expression: expression,
        individualRolls: result.individualRolls,
        total: result.total,
        timestamp: DateTime.now(),
        isHidden: _hideRollFromPlayers && _isMaster,
        isMasterRoll: _isMaster,
      );
      
      final messageData = {
        'type': 'dice',
        'id': diceRoll.id,
        'author': diceRoll.author,
        'expression': diceRoll.expression,
        'individualRolls': diceRoll.individualRolls,
        'total': diceRoll.total,
        'timestamp': diceRoll.timestamp.toIso8601String(),
        'isHidden': diceRoll.isHidden,
        'isMasterRoll': diceRoll.isMasterRoll,
      };
      
      setState(() {
        _diceRolls.insert(0, diceRoll);
        _chatMessages.add({
          'type': 'dice',
          'diceRoll': diceRoll,
          'time': DateTime.now(),
        });
      });
      
      _scrollChatToBottom();
      
      if (_isMaster || _isHosting) {
        _socketService.sendMessage(
          widget.adventure.id,
          messageData,
        );
      }
      
    } catch (e) {
      _addSystemMessage('❌ Errore nel lancio: "$expression" non è valido');
    }
  }

  // 🔹 Toggle per nascondere il risultato ai giocatori
  void _toggleHiddenRoll() {
    setState(() => _hideRollFromPlayers = !_hideRollFromPlayers);
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _canInteract => _isMaster || _isHosting;

  // 🔹 Upload file (solo Master)
  Future<void> _uploadFile() async {
    if (!_isMaster) return;
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'map'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _files.add({
          'name': result.files.single.name,
          'type': result.files.single.extension == 'pdf' ? 'document' : 'image',
          'size': '${(result.files.single.size / 1024 / 1024).toStringAsFixed(1)} MB',
        });
      });
      _addSystemMessage('📁 ${AuthService().currentUser?.nickname ?? 'Master'} ha caricato: ${result.files.single.name}');
    }
  }

  // 🔹 Audio controls
  Future<void> _playTrack(String url, String name) async {
    if (!_isMaster) return;
    await _bgMusicPlayer.stop();
    await _bgMusicPlayer.setVolume(_musicVolume);
    await _bgMusicPlayer.play(UrlSource(url));
    setState(() => _currentTrack = name);
  }

  Future<void> _playSfx(String url) async {
    if (!_isMaster) return;
    await _sfxPlayer.play(UrlSource(url));
  }

  void _toggleHosting() {
    final newHostingState = !_isHosting;
    setState(() => _isHosting = newHostingState);
    
    if (_isMaster) {
      _socketService.sendHostToggle(
        widget.adventure.id,    // String (primo)
        newHostingState,        // bool (secondo)
      );
    }
    
    _addSystemMessage(newHostingState 
      ? '🟢 Host avviato. I giocatori possono connettersi.' 
      : '🔴 Host fermato. I giocatori sono stati disconnessi.');
  }

  @override
  Widget build(BuildContext context) {
    final isPlayerBlocked = !_isMaster && !_isHosting;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A2E),
                        border: Border(bottom: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.adventure.title,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_isMaster)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isHosting ? Colors.redAccent : const Color(0xFF00B0FF),
                                foregroundColor: _isHosting ? Colors.white : Colors.black,
                              ),
                              onPressed: _toggleHosting,
                              icon: Icon(_isHosting ? Icons.stop : Icons.wifi_tethering),
                              label: Text(_isHosting ? 'Ferma Host' : 'Avvia Host'),
                            ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(_isSidebarOpen ? Icons.chevron_right : Icons.chevron_left),
                            onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    
                    // Mappa/Canvas
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F1A),
                          image: const DecorationImage(
                            image: NetworkImage('https://placehold.co/1200x800/1a1a2e/00b0ff?text=Mappa+di+Gioco'),
                            fit: BoxFit.contain,
                            opacity: 0.3,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_outlined, size: 64, color: Colors.white38),
                              const SizedBox(height: 12),
                              Text('Area Mappa/Canvas', style: TextStyle(color: Colors.white54, fontSize: 16)),
                              const SizedBox(height: 8),
                              Text('Trascina token, misura distanze, applica effetti', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 🔹 BARRA LATERALE (Chat, Dadi, File, Audio)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isSidebarOpen ? _sidebarWidth : 0,
                decoration: const BoxDecoration(
                  color: Color(0xFF12121E),
                  border: Border(left: BorderSide(color: Colors.white10)),
                ),
                child: _isSidebarOpen
                    ? Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            indicatorColor: const Color(0xFF00B0FF),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white54,
                            tabs: const [
                              Tab(icon: Icon(Icons.chat), text: 'Chat & Dadi'),
                              Tab(icon: Icon(Icons.folder), text: 'File'),
                              Tab(icon: Icon(Icons.music_note), text: 'Audio'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                // 🔹 TAB 1: CHAT & DADI (FIX #3: unificati)
                                _buildChatAndDiceTab(),
                                // 🔹 TAB 2: FILE
                                _buildFilesTab(),
                                // 🔹 TAB 3: AUDIO
                                _buildAudioTab(),
                              ],
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ],
          ),

          // 🔹 FIX #4 e #5: Overlay blocco per giocatori se host non attivo
          if (isPlayerBlocked)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 64, color: Colors.white54),
                    const SizedBox(height: 16),
                    const Text(
                      '⏳ In attesa che il Master avvii l\'host...',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connectionTimeoutTimer?.isActive == true
                          ? 'Uscita automatica tra ${_timeoutSecondsRemaining}s'
                          : 'Non puoi interagire finché la sessione non è attiva',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🔹 FIX #3: Chat & Dadi unificati nella sidebar
  Widget _buildChatAndDiceTab() {
    return Column(
      children: [
        // 🔹 Toggle "Roll Nascosto" (solo Master)
        if (_isMaster)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.visibility_off, size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                const Text('Nascondi ai giocatori', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                Switch(
                  value: _hideRollFromPlayers,
                  activeColor: const Color(0xFF00B0FF),
                  onChanged: (_) => _toggleHiddenRoll(),
                ),
              ],
            ),
          ),
        
        // 🔹 Input unificato per chat e comandi dadi
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl, // 🔹 FIX #3: stesso controller per chat e dadi
                  enabled: _canInteract,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _canInteract ? 'Scrivi o usa /rd 2d8+4...' : 'Host non attivo...',
                    hintStyle: TextStyle(color: _canInteract ? Colors.white38 : Colors.white24),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: _canInteract ? const Color(0xFF0F0F1A) : Colors.grey.shade900,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: const Icon(Icons.chat, color: Color(0xFF00B0FF), size: 20),
                  ),
                  onSubmitted: (val) => _addChatMessage(val), // 🔹 FIX #3: stessa funzione per chat e dadi
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF00B0FF)),
                onPressed: _canInteract ? () => _addChatMessage(_chatCtrl.text) : null,
              ),
            ],
          ),
        ),

        // 🔹 Pulsanti dadi rapidi (shortcut per /rd NdM)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['d4','d6','d8','d10','d12','d20','d100']
                .map((d) => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E3F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size(40, 32),
                      ),
                      onPressed: _canInteract ? () => _addChatMessage('/rd 1$d') : null, // 🔹 FIX #3: invia come messaggio chat che viene parsato
                      child: Text(d, style: const TextStyle(fontSize: 11)),
                    ))
                .toList(),
          ),
        ),

        const Divider(color: Colors.white24, height: 16),

        // 🔹 Lista messaggi chat + dadi
        Expanded(
          child: ListView.builder(
            controller: _chatScrollCtrl,
            padding: const EdgeInsets.all(12),
            itemCount: _chatMessages.length,
            reverse: true,
            itemBuilder: (ctx, index) {
              final msg = _chatMessages[_chatMessages.length - 1 - index];
              
              if (msg['type'] == 'system') {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    msg['content'],
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              
              if (msg['type'] == 'dice') {
                final dice = msg['diceRoll'] as DiceRoll;
                final viewerIsMaster = _isMaster;
                return _DiceRollCard(diceRoll: dice, viewerIsMaster: viewerIsMaster);
              }
              
              // Chat normale
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF00B0FF).withOpacity(0.3),
                      child: Text(
                        (msg['author'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFF00B0FF), fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                msg['author'] ?? 'Sconosciuto',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('HH:mm').format(msg['time']),
                                style: TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                          Text(
                            msg['content'],
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilesTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (_isMaster)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00B0FF),
                side: const BorderSide(color: Color(0xFF00B0FF)),
              ),
              onPressed: _canInteract ? _uploadFile : null,
              icon: const Icon(Icons.upload_file),
              label: const Text('Carica'),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _files.length,
              itemBuilder: (ctx, i) {
                final f = _files[i];
                return ListTile(
                  leading: Icon(
                    f['type'] == 'image' ? Icons.image : Icons.description,
                    color: const Color(0xFF00B0FF),
                  ),
                  title: Text(f['name'], style: const TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text(f['size'], style: TextStyle(color: Colors.white54, fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.white54),
                    onPressed: () {},
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎵 Musica', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (ctx, i) {
                final t = _tracks[i];
                final isActive = _currentTrack == t['name'];
                return ListTile(
                  leading: Icon(
                    isActive ? Icons.play_circle_fill : Icons.play_circle_outline,
                    color: isActive ? const Color(0xFF00B0FF) : Colors.white54,
                  ),
                  title: Text(t['name'], style: TextStyle(color: isActive ? Colors.white : Colors.white70)),
                  trailing: _isMaster
                      ? Switch(
                          value: isActive,
                          activeColor: const Color(0xFF00B0FF),
                          onChanged: (v) => v ? _playTrack(t['url'], t['name']) : _bgMusicPlayer.stop(),
                        )
                      : (isActive ? const Icon(Icons.volume_up, color: Color(0xFF00B0FF), size: 20) : null),
                );
              },
            ),
          ),
          const Divider(color: Colors.white24),
          const Text('🔊 Effetti', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sfx.map((s) => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E3F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: _canInteract ? () => _playSfx(s['url']) : null,
                  icon: const Icon(Icons.speaker_phone, size: 14),
                  label: Text(s['name']),
                )).toList(),
          ),
        ],
      ),
    );
  }
}

// 🔹 Widget helper per visualizzare un lancio di dadi
class _DiceRollCard extends StatelessWidget {
  final DiceRoll diceRoll;
  final bool viewerIsMaster;

  const _DiceRollCard({required this.diceRoll, required this.viewerIsMaster});

  @override
  Widget build(BuildContext context) {
    final displayContent = diceRoll.getDisplayContent(viewerIsMaster);
    final isHidden = diceRoll.isHidden && !viewerIsMaster;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isHidden ? const Color(0xFF1E1E3F).withOpacity(0.5) : const Color(0xFF1E1E3F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHidden ? Colors.white24 : (diceRoll.isMasterRoll ? const Color(0xFF7E57C2) : const Color(0xFF00B0FF)),
          width: isHidden ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHidden ? Icons.visibility_off : Icons.casino,
                size: 14,
                color: isHidden ? Colors.white38 : (diceRoll.isMasterRoll ? const Color(0xFF7E57C2) : const Color(0xFF00B0FF)),
              ),
              const SizedBox(width: 6),
              Text(
                diceRoll.author,
                style: TextStyle(
                  color: isHidden ? Colors.white38 : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('HH:mm').format(diceRoll.timestamp),
                style: TextStyle(color: isHidden ? Colors.white24 : Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            displayContent,
            style: TextStyle(
              color: isHidden ? Colors.white54 : Colors.white,
              fontSize: 13,
              fontWeight: isHidden ? FontWeight.normal : FontWeight.w500,
            ),
          ),
          if (!isHidden && diceRoll.individualRolls.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              'Dettagli: ${diceRoll.individualRolls.join(', ')}',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}