import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/adventure.dart';
import '../services/auth_service.dart';
import '../services/game_socket_service.dart';
import '../config.dart';

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

class DiceParser {
  static final _random = Random();
  
  static DiceRollResult parse(String expression, String author, bool isMaster, {bool isHidden = false}) {
    final cleanExpr = expression.replaceAll(' ', '');
    int total = 0;
    final List<int> allRolls = [];
    final List<String> rollDetails = [];
    final tokenRegex = RegExp(r'([+-]?\d*d\d+)|([+-]?\d+)', caseSensitive: false);
    
    for (final match in tokenRegex.allMatches(cleanExpr)) {
      final diceMatch = match.group(1);
      final numberMatch = match.group(2);
      
      if (diceMatch != null) {
        final isNegative = diceMatch.startsWith('-');
        final cleanDice = diceMatch.replaceAll(RegExp(r'^[+-]'), '');
        final parts = cleanDice.split('d');
        final count = int.tryParse(parts[0]) ?? 1;
        final sides = int.tryParse(parts[1]) ?? 6;
        
        final rolls = List.generate(count, (_) => _random.nextInt(sides) + 1);
        int sum = rolls.reduce((a, b) => a + b);
        if (isNegative) sum = -sum; 
        
        total += sum;
        allRolls.addAll(rolls); 
        rollDetails.add('${isNegative ? "-" : ""}${count}d$sides: [${rolls.join(', ')}]');
      } else if (numberMatch != null) {
        total += int.tryParse(numberMatch) ?? 0;
      }
    }
    return DiceRollResult(
      expression: expression, total: total, individualRolls: allRolls,
      details: rollDetails.join(' | '), author: author, isHidden: isHidden, isMasterRoll: isMaster,
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
    required this.expression, required this.total, required this.individualRolls,
    required this.details, required this.author, this.isHidden = false, this.isMasterRoll = false,
  });
}

class GameSessionScreen extends StatefulWidget {
  final Adventure adventure;
  const GameSessionScreen({super.key, required this.adventure});

  @override
  State<GameSessionScreen> createState() => _GameSessionScreenState();
}

class _GameSessionScreenState extends State<GameSessionScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  
  bool _isSidebarOpen = true;
  bool _isMaster = false;
  bool _isHosting = false;
  double _sidebarWidth = 340;
  
  final _socketService = GameSocketService();
  Timer? _connectionTimeoutTimer;
  int _timeoutSecondsRemaining = 15;
  
  final AudioPlayer _bgMusicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  double _musicVolume = 0.5;
  
  final ValueNotifier<String?> _currentTrackNotifier = ValueNotifier<String?>(null);
  String? get _currentTrack => _currentTrackNotifier.value;
  
  final List<Map<String, dynamic>> _tracks = [
    {'id': 't1', 'name': 'Taverna Medievale', 'type': 'music', 'url': 'audio/tavern.mp3'},
    {'id': 't2', 'name': 'Foresta Magica', 'type': 'music', 'url': 'audio/magicForest.mp3'},
    {'id': 't3', 'name': 'Battaglia Epica', 'type': 'music', 'url': 'audio/battle.mp3'},
    {'id': 't4', 'name': 'Foresta', 'type': 'music', 'url': 'audio/forest.mp3'},
  ];
  final List<Map<String, dynamic>> _sfx = [
    {'id': 's1', 'name': '🌧️ Pioggia', 'url': 'sfx/rain.mp3'},
    {'id': 's2', 'name': '🔥 Fuoco', 'url': 'sfx/fire.mp3'},
    {'id': 's3', 'name': '⚔️ Spade', 'url': 'sfx/swords.mp3'},
    {'id': 's4', 'name': '🌬️ Vento', 'url': 'sfx/wind.mp3'},
  ];

  final List<DiceRoll> _diceRolls = [];
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  final ScrollController _mobileChatScrollCtrl = ScrollController();
  bool _hideRollFromPlayers = false;

  final List<Map<String, dynamic>> _files = [];
  final List<Map<String, dynamic>> _customTracks = [];
  final List<Map<String, dynamic>> _customSfx = [];
  String? _currentMapUrl;

  @override
  void initState() {
    super.initState();

    final audioContext = AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    );

    _bgMusicPlayer.setAudioContext(audioContext);
    _sfxPlayer.setAudioContext(audioContext);

    _tabController = TabController(length: 3, vsync: this);
    _isMaster = AuthService().currentUser?.id == widget.adventure.createdBy;
    
    _socketService.onHostStatusChanged = _onRemoteHostStatusChanged;
    _socketService.onNewMessage = _onRemoteMessageReceived;
    _socketService.onSystemMessage = _addSystemMessage;
    _socketService.onHostClosed = _handleHostClosed;
    
    _socketService.onFileUploaded = _onRemoteFileUploaded;
    _socketService.onFileDeleted = _onRemoteFileDeleted;
    _socketService.onAudioUploaded = _onRemoteAudioUploaded;
    _socketService.onAudioDeleted = _onRemoteAudioDeleted;

    _socketService.onPlayTrack = _onRemotePlayTrack;
    _socketService.onStopTrack = _onRemoteStopTrack;
    _socketService.onPlaySfx = _onRemotePlaySfx;

    _socketService.onMapChanged = _onRemoteMapChanged;
    
    _socketService.connect(
      widget.adventure.id,
      AuthService().currentUser?.id ?? 'unknown',
      AuthService().currentUser?.nickname ?? 'Guest',
    );

    if (!_isMaster) {
      _startConnectionTimeout();  
    }
    
    _addSystemMessage('🎮 Sessione caricata. ${_isMaster ? "Sei il Master. Avvia l'host per i giocatori." : "Attendi che il Master avvii la sessione (timeout: 15s)..."}');

    _loadAdventureFiles();
  }

  void _startConnectionTimeout() {
    _timeoutSecondsRemaining = 15;
    _connectionTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _timeoutSecondsRemaining--;
        if (_timeoutSecondsRemaining <= 0) {
          timer.cancel();
          _handleConnectionTimeout();
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _mobileChatScrollCtrl.dispose();
    _bgMusicPlayer.stop();
    _sfxPlayer.stop();
    _bgMusicPlayer.dispose();
    _sfxPlayer.dispose();
    _connectionTimeoutTimer?.cancel();
    _socketService.disconnect();
    super.dispose();
  }

    Future<void> _loadAdventureFiles() async {
    try {
      final token = AuthService().getToken;
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/adventures/${widget.adventure.id}/files'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List filesJson = data['files'] ?? [];
        
        setState(() {
          _files.clear();
          _customTracks.clear();
          _customSfx.clear();
          
          for (final f in filesJson) {
            final fileType = f['type'] as String;
            final fileData = {
              'name': f['name'],
              'url': f['url'],
              'type': fileType,
              'size': f['size'],
            };
            
            if (fileType == 'image' || fileType == 'document') {
              _files.add(fileData);
              if (fileType == 'image' && _currentMapUrl == null) {
                _currentMapUrl = f['url'];
              }
            } else if (fileType == 'music') {
              _customTracks.add(fileData);
            } else if (fileType == 'sfx') {
              _customSfx.add(fileData);
            }
          }
        });
        
        if (filesJson.isNotEmpty) {
          _addSystemMessage('📁 ${filesJson.length} file caricati dalla sessione precedente');
        }
      }
    } catch (e) {
      print('Errore caricamento file: $e');
    }
  }

  void _onRemotePlaySfx(String sfxName, String sfxUrl) {
    if (!mounted || _isMaster) return;
    _playSfxLocalWithDucking(sfxUrl);
  }

  void _onRemoteMapChanged(String? mapUrl) {
    if (!mounted) return;
    setState(() {
      _currentMapUrl = mapUrl;
    });
  }

  void _setAsMap(String url) {
    if (!_isMaster) return;
    
    setState(() {
      _currentMapUrl = url;
    });
    
    _socketService.sendMapChanged(widget.adventure.id, url);
    
    _addSystemMessage('🗺️ Il Master ha impostato una nuova mappa.');
  }

  Future<void> _playSfxLocalWithDucking(String url) async {
    try {
      final source = url.startsWith('http') ? UrlSource(url) : AssetSource(url);
      
      final duckedVolume = _musicVolume * 0.3;
      await _bgMusicPlayer.setVolume(duckedVolume);
      
      await _sfxPlayer.play(source);
      
      bool volumeRestored = false;
      void restoreVolume() {
        if (volumeRestored || !mounted) return;
        volumeRestored = true;
        _bgMusicPlayer.setVolume(_musicVolume);
      }

      _sfxPlayer.onPlayerComplete.listen((_) => restoreVolume());
      Future.delayed(const Duration(seconds: 3), restoreVolume);
      
    } catch (e) {
      print('ERRORE RIPRODUZIONE SFX (Player): $e');
      _bgMusicPlayer.setVolume(_musicVolume);
    }
  }

  Future<void> _playSfx(String url, String name) async {
    if (!_isMaster) return;
    try {
      final source = url.startsWith('http') ? UrlSource(url) : AssetSource(url);
      
      final duckedVolume = _musicVolume * 0.3;
      await _bgMusicPlayer.setVolume(duckedVolume);
      
      await _sfxPlayer.play(source);
      
      bool volumeRestored = false;
      void restoreVolume() {
        if (volumeRestored || !mounted) return;
        volumeRestored = true;
        _bgMusicPlayer.setVolume(_musicVolume);
      }

      _sfxPlayer.onPlayerComplete.listen((_) => restoreVolume());
      
      Future.delayed(const Duration(seconds: 3), restoreVolume);

      _socketService.sendPlaySfx(widget.adventure.id, name, url);
      
    } catch (e) {
      print('ERRORE RIPRODUZIONE SFX: $e');
      _bgMusicPlayer.setVolume(_musicVolume);
    }
  }

  void _onRemotePlayTrack(String trackName, String trackUrl) {
    if (!mounted || _isMaster) return;
    _playTrackLocal(trackUrl, trackName);
  }

  void _onRemoteStopTrack() {
    if (!mounted || _isMaster) return;
    _stopTrackLocal();
  }

  Future<void> _playTrackLocal(String url, String name) async {
    try {
      final source = url.startsWith('http') ? UrlSource(url) : AssetSource(url);
      await _bgMusicPlayer.play(source);
      await _bgMusicPlayer.setVolume(_musicVolume);
      if (mounted) {
        _currentTrackNotifier.value = name;
        setState(() {});
      }
    } catch (e) {
      print('ERRORE RIPRODUZIONE TRACK (Player): $e');
    }
  }

  Future<void> _stopTrackLocal() async {
    await _bgMusicPlayer.stop();
    if (mounted) {
      _currentTrackNotifier.value = null;
      setState(() {});
    }
  }

  Future<void> _playTrack(String url, String name) async {
    if (!_isMaster) return;
    
    _currentTrackNotifier.value = name;
    if (mounted) setState(() {});
    
    try {
      final source = url.startsWith('http') ? UrlSource(url) : AssetSource(url);
      await _bgMusicPlayer.play(source);
      await _bgMusicPlayer.setVolume(_musicVolume);
      
      _socketService.sendPlayTrack(widget.adventure.id, name, url);
    } catch (e) {
      print('ERRORE RIPRODUZIONE TRACK: $e');
      _currentTrackNotifier.value = null;
      if (mounted) setState(() {});
    }
  }

  Future<void> _stopTrack() async {
    if (!_isMaster) return;
    
    _currentTrackNotifier.value = null;
    if (mounted) setState(() {});
    
    await _bgMusicPlayer.stop();
    _socketService.sendStopTrack(widget.adventure.id);
  }

  Future<void> _uploadFile() async {
    if (!_isMaster) return;
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, 
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes == null) {
        _addSystemMessage('Errore: Impossibile leggere il file.');
        return;
      }
      
      _addSystemMessage('Caricamento del file in corso...');
      
      final request = http.MultipartRequest(
        'POST', 
        Uri.parse(AppConfig.getAdventureUploadUrl(widget.adventure.id))
      );
      
      final token = AuthService().getToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      } else {
        _addSystemMessage('Errore: Sessione scaduta. Effettua nuovamente il login.');
        return;
      }
      
      request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));

      final fileExt = file.name.split('.').last.toLowerCase();
      if (fileExt == 'pdf') {
        request.fields['file_type'] = 'document';
      } else {
        request.fields['file_type'] = 'image';
      }
      
      try {
        final response = await request.send();
        
        if (response.statusCode == 200) {
          final respStr = await response.stream.bytesToString();
          final data = jsonDecode(respStr);
          
          final fileName = data['file_name'] as String;
          final fileUrl = data['url'] as String;
          final isImage = fileName.toLowerCase().endsWith('.jpg') || 
                          fileName.toLowerCase().endsWith('.jpeg') || 
                          fileName.toLowerCase().endsWith('.png');
          
          final fileData = {
            'name': fileName,
            'url': fileUrl,
            'type': isImage ? 'image' : 'document',
            'size': '${(data['size'] / 1024 / 1024).toStringAsFixed(1)} MB',
          };

          setState(() {
            _files.add(fileData);
          });
          
          _addSystemMessage('File caricato con successo: $fileName');
          
          _socketService.sendFileUploaded(widget.adventure.id, fileData);
          
          _socketService.sendMessage(widget.adventure.id, {
            'type': 'system', 
            'content': '📁 ${AuthService().currentUser?.nickname ?? 'Master'} ha caricato: $fileName'
          });
          
        } else {
          final errorBody = await response.stream.bytesToString();
          _addSystemMessage('Errore caricamento (Codice ${response.statusCode}): $errorBody');
        }
      } catch (e) {
        _addSystemMessage('Errore di rete durante l\'upload: $e');
      }
    }
  }

  Future<void> _uploadAudio(bool isMusic) async {
    if (!_isMaster) return;
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: isMusic ? ['mp3', 'wav', 'ogg', 'm4a'] : ['mp3', 'wav', 'ogg'],
      withData: true,
    );
    
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes == null) {
        _addSystemMessage('Errore: Impossibile leggere il file.');
        return;
      }

      _addSystemMessage('Caricamento audio in corso...');
      
      final request = http.MultipartRequest(
        'POST', 
        Uri.parse(AppConfig.getAdventureUploadUrl(widget.adventure.id)),
      );
      
      final token = AuthService().getToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));
      
      request.fields['audio_type'] = isMusic ? 'music' : 'sfx';

      try {
        final response = await request.send();
        if (response.statusCode == 200) {
          final respStr = await response.stream.bytesToString();
          final data = jsonDecode(respStr);
          
          final audioData = {
            'name': data['file_name'] as String,
            'url': data['url'] as String,
            'type': isMusic ? 'music' : 'sfx',
          };
          
          setState(() {
            if (isMusic) {
              _customTracks.add(audioData);
            } else {
              _customSfx.add(audioData);
            }
          });
          _currentTrackNotifier.value = _currentTrackNotifier.value;
          
          _addSystemMessage('Audio caricato: ${data['file_name']}');
          
          _socketService.sendAudioUploaded(widget.adventure.id, audioData);
          
        } else {
          final errorBody = await response.stream.bytesToString();
          _addSystemMessage('Errore caricamento audio: $errorBody');
        }
      } catch (e) {
        _addSystemMessage('Errore di rete durante l\'upload audio: $e');
      }
    }
  }

  void _onRemoteFileUploaded(Map<String, dynamic> fileData) {
    if (!mounted) return;
    setState(() {
      if (!_files.any((f) => f['url'] == fileData['url'])) {
        _files.add(fileData);
      }
    });
  }

  void _onRemoteFileDeleted(String filename) {
    if (!mounted) return;
    setState(() {
      _files.removeWhere((f) => f['name'] == filename || f['url'].contains(filename));
      if (_currentMapUrl?.contains(filename) ?? false) {
        _currentMapUrl = null;
      }
    });
  }

  void _onRemoteAudioUploaded(Map<String, dynamic> audioData) {
    if (!mounted) return;
    setState(() {
      if (audioData['type'] == 'music' && !_customTracks.any((t) => t['url'] == audioData['url'])) {
        _customTracks.add(audioData);
      } else if (audioData['type'] == 'sfx' && !_customSfx.any((s) => s['url'] == audioData['url'])) {
        _customSfx.add(audioData);
      }
    });
    _currentTrackNotifier.value = _currentTrackNotifier.value;
  }

  Future<void> _deleteFile(String fileName, String fileUrl) async {
    if (!_isMaster) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('🗑️ Eliminare File?', style: TextStyle(color: Colors.white)),
        content: Text('Sei sicuro di voler eliminare "$fileName"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Elimina')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final urlFileName = fileUrl.split('/').last;
        final token = AuthService().getToken;
        
        final response = await http.delete(
          Uri.parse('${AppConfig.baseUrl}/adventures/${widget.adventure.id}/files/$urlFileName'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          setState(() {
            _files.removeWhere((f) => f['url'].contains(urlFileName));
            if (_currentMapUrl?.contains(urlFileName) ?? false) {
              _currentMapUrl = null;
            }
          });
          _socketService.sendFileDeleted(widget.adventure.id, urlFileName);
          _addSystemMessage('🗑️ File eliminato: $fileName');
        } else {
          _addSystemMessage('Errore nell\'eliminazione del file');
        }
      } catch (e) {
        _addSystemMessage('Errore di rete durante l\'eliminazione');
      }
    }
  }

  void _removeMap() {
    if (!_isMaster) return;
    
    setState(() {
      _currentMapUrl = null;
    });
    
    _socketService.sendMapChanged(widget.adventure.id, null);
    _addSystemMessage('Il Master ha rimosso la mappa.');
  }

  void _onRemoteAudioDeleted(String filename) {
    if (!mounted) return;
    setState(() {
      _customTracks.removeWhere((t) => t['url'].contains(filename));
      _customSfx.removeWhere((s) => s['url'].contains(filename));
      
      if (_currentTrack != null && _currentTrack!.contains(filename)) {
        _currentTrackNotifier.value = null;
        _bgMusicPlayer.stop();
      }
    });
    _currentTrackNotifier.value = _currentTrackNotifier.value;
  }

  Future<void> _deleteAudio(String fileName, String fileUrl, bool isMusic) async {
    if (!_isMaster) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('🗑️ Eliminare Audio?', style: TextStyle(color: Colors.white)),
        content: Text('Sei sicuro di voler eliminare "$fileName"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Elimina')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final urlFileName = fileUrl.split('/').last;
        final token = AuthService().getToken;
        
        final response = await http.delete(
          Uri.parse('${AppConfig.baseUrl}/adventures/${widget.adventure.id}/files/$urlFileName'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          setState(() {
            if (isMusic) {
              _customTracks.removeWhere((t) => t['url'].contains(urlFileName));
              if (_currentTrack != null && _currentTrack!.contains(urlFileName)) {
                _currentTrackNotifier.value = null;
                _bgMusicPlayer.stop();
              }
            } else {
              _customSfx.removeWhere((s) => s['url'].contains(urlFileName));
            }
          });
          _currentTrackNotifier.value = _currentTrackNotifier.value;
          
          _socketService.sendAudioDeleted(widget.adventure.id, urlFileName);
          _addSystemMessage('🗑️ Audio eliminato: $fileName');
        } else {
          _addSystemMessage('Errore nell\'eliminazione dell\'audio');
        }
      } catch (e) {
        _addSystemMessage('Errore di rete durante l\'eliminazione');
      }
    }
  }

  void _onRemoteHostStatusChanged(bool isHosting) {
    if (mounted) {
      setState(() => _isHosting = isHosting);
      if (isHosting && !_isMaster && _connectionTimeoutTimer?.isActive == true) {
        _connectionTimeoutTimer?.cancel();
        _addSystemMessage('🟢 Host rilevato! Connessione stabilita.');
      }
    }
  }

  void _onRemoteMessageReceived(Map<String, dynamic> msg) {
    if (!mounted) return;
    setState(() {
      if (msg['type'] == 'dice') {
        final diceRoll = DiceRoll(
          id: msg['id'] as String, author: msg['author'] as String, expression: msg['expression'] as String,
          individualRolls: List<int>.from(msg['individualRolls'] as List), total: msg['total'] as int,
          timestamp: DateTime.parse(msg['timestamp'] as String), isHidden: msg['isHidden'] as bool? ?? false, isMasterRoll: msg['isMasterRoll'] as bool? ?? false,
        );
        _diceRolls.insert(0, diceRoll);
        _chatMessages.add({'type': 'dice', 'diceRoll': diceRoll, 'time': DateTime.now()});
      } else {
        _chatMessages.add({'type': msg['type'] ?? 'chat', 'content': msg['content'] as String, 'author': msg['author'] as String, 'time': DateTime.parse(msg['time'] as String)});
      }
    });
    _scrollChatToBottom();
  }

  void _handleConnectionTimeout() {
    if (mounted && !_isMaster && !_isHosting) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏰ Timeout: impossibile connettersi all\'host'), backgroundColor: Colors.red, duration: Duration(seconds: 3)));
      Navigator.pop(context);
    }
  }

  void _addSystemMessage(String content) {
    setState(() {
      _chatMessages.add({'type': 'system', 'content': content, 'time': DateTime.now()});
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
    final messageData = {'type': 'chat', 'content': content, 'author': senderName, 'time': DateTime.now().toIso8601String()};
    setState(() {
      _chatMessages.add({'type': 'chat', 'content': content, 'author': senderName, 'time': DateTime.now()});
    });
    _chatCtrl.clear();
    _scrollChatToBottom();
    if (_isMaster || _isHosting) {
      _socketService.sendMessage(widget.adventure.id, messageData);
    }
  }

  void _parseAndRollDice(String expression, String author) {
    try {
      final result = DiceParser.parse(expression, author, _isMaster, isHidden: _hideRollFromPlayers && _isMaster);
      final diceRoll = DiceRoll(
        id: DateTime.now().millisecondsSinceEpoch.toString(), author: author, expression: expression,
        individualRolls: result.individualRolls, total: result.total, timestamp: DateTime.now(),
        isHidden: _hideRollFromPlayers && _isMaster, isMasterRoll: _isMaster,
      );
      final messageData = {
        'type': 'dice', 'id': diceRoll.id, 'author': diceRoll.author, 'expression': diceRoll.expression,
        'individualRolls': diceRoll.individualRolls, 'total': diceRoll.total, 'timestamp': diceRoll.timestamp.toIso8601String(),
        'isHidden': diceRoll.isHidden, 'isMasterRoll': diceRoll.isMasterRoll,
      };
      setState(() {
        _diceRolls.insert(0, diceRoll);
        _chatMessages.add({'type': 'dice', 'diceRoll': diceRoll, 'time': DateTime.now()});
      });
      _scrollChatToBottom();
      if (_isMaster || _isHosting) {
        _socketService.sendMessage(widget.adventure.id, messageData);
      }
    } catch (e) {
      _addSystemMessage('Errore nel lancio: "$expression" non è valido');
    }
  }

  void _toggleHiddenRoll() {
    setState(() => _hideRollFromPlayers = !_hideRollFromPlayers);
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(_chatScrollCtrl.position.minScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
      if (_mobileChatScrollCtrl.hasClients) {
        _mobileChatScrollCtrl.animateTo(_mobileChatScrollCtrl.position.minScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  bool get _canInteract => _isMaster || _isHosting;

  void _toggleHosting() {
    final newHostingState = !_isHosting;
    setState(() => _isHosting = newHostingState);
    if (_isMaster) {
      _socketService.sendHostToggle(widget.adventure.id, newHostingState);
    }
    _addSystemMessage(newHostingState ? '🟢 Host avviato. I giocatori possono connettersi.' : '🔴 Host fermato. I giocatori sono stati disconnessi.');
  }

  void _leaveSession() {
    _socketService.disconnect();
    Navigator.pop(context);
  }

  void _handleHostClosed() {
    if (!mounted || _isMaster) return;
    setState(() {
      _isHosting = false;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28), SizedBox(width: 12), Text('Sessione Terminata', style: TextStyle(color: Colors.white))]),
        content: const Text('Il Master ha chiuso la sessione.\nPuoi uscire ora.', style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B0FF), foregroundColor: Colors.black),
            onPressed: () { Navigator.pop(context); _leaveSession(); },
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Esci'),
          ),
        ],
      ),
    );
  }

  void _openMobileChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: Color(0xFF12121E), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Container(padding: const EdgeInsets.symmetric(vertical: 12), child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)))),
              if (_isMaster)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_off, size: 16, color: Colors.white54),
                      const SizedBox(width: 8),
                      const Text('Roll nascosto', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const Spacer(),
                      Switch(value: _hideRollFromPlayers, activeColor: const Color(0xFF00B0FF), onChanged: (_) => _toggleHiddenRoll()),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatCtrl,
                        enabled: _canInteract,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _canInteract ? 'Scrivi o /rd 2d8+4...' : 'Host non attivo...',
                          hintStyle: TextStyle(color: _canInteract ? Colors.white38 : Colors.white24),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: const Color(0xFF0F0F1A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          prefixIcon: const Icon(Icons.chat, color: Color(0xFF00B0FF), size: 20),
                        ),
                        onSubmitted: (val) => _addChatMessage(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.send, color: Color(0xFF00B0FF)), onPressed: _canInteract ? () => _addChatMessage(_chatCtrl.text) : null),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['d4','d6','d8','d10','d12','d20','d100']
                      .map((d) => ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E3F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: const Size(44, 36)),
                            onPressed: _canInteract ? () => _addChatMessage('/rd 1$d') : null,
                            child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ))
                      .toList(),
                ),
              ),
              const Divider(color: Colors.white24, height: 16),
              Expanded(
                child: ListView.builder(
                  controller: _mobileChatScrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: _chatMessages.length,
                  reverse: true,
                  itemBuilder: (ctx, index) {
                    final msg = _chatMessages[_chatMessages.length - 1 - index];
                    if (msg['type'] == 'system') {
                      return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(msg['content'], style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic), textAlign: TextAlign.center));
                    }
                    if (msg['type'] == 'dice') {
                      return _DiceRollCard(diceRoll: msg['diceRoll'] as DiceRoll, viewerIsMaster: _isMaster);
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 14, backgroundColor: const Color(0xFF00B0FF).withOpacity(0.3), child: Text((msg['author'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Color(0xFF00B0FF), fontSize: 11))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(msg['author'] ?? 'Sconosciuto', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                                    const SizedBox(width: 6),
                                    Text(DateFormat('HH:mm').format(msg['time'] as DateTime), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                  ],
                                ),
                                Text(msg['content'], style: const TextStyle(color: Colors.white, fontSize: 13)),
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPlayerBlocked = !_isMaster && !_isHosting;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: Stack(
        children: [
          isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
          if (isPlayerBlocked)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 64, color: Colors.white54),
                    const SizedBox(height: 16),
                    const Text('⏳ In attesa che il Master avvii l\'host...', style: TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      _connectionTimeoutTimer?.isActive == true ? 'Uscita automatica tra ${_timeoutSecondsRemaining}s' : 'Non puoi interagire finché la sessione non è attiva',
                      style: const TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      onPressed: _leaveSession,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Esci dalla sessione', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.adventure.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isMaster)
                IconButton(
                  icon: Icon(
                    _isHosting ? Icons.stop : Icons.wifi_tethering,
                    color: _isHosting ? Colors.redAccent : const Color(0xFF00B0FF),
                    size: 22,
                  ),
                  onPressed: _toggleHosting,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70, size: 22),
                color: const Color(0xFF1A1A2E),
                onSelected: (value) {
                  if (value == 'files') _showMobileFilesSheet();
                  if (value == 'audio') _showMobileAudioSheet();
                  if (value == 'remove_map') _removeMap();
                  if (value == 'exit') _leaveSession();
                },
                itemBuilder: (context) {
                  final List<PopupMenuEntry<String>> items = [];
                  
                  if (_isMaster) {
                    items.add(const PopupMenuItem(
                      value: 'files',
                      child: ListTile(
                        leading: Icon(Icons.folder, color: Color(0xFF00B0FF)),
                        title: Text('File e Mappe', style: TextStyle(color: Colors.white)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ));
                    items.add(const PopupMenuItem(
                      value: 'audio',
                      child: ListTile(
                        leading: Icon(Icons.music_note, color: Color(0xFF00B0FF)),
                        title: Text('Audio', style: TextStyle(color: Colors.white)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ));
                    items.add(const PopupMenuDivider());
                    
                    if (_currentMapUrl != null) {
                      items.add(const PopupMenuItem(
                        value: 'remove_map',
                        child: ListTile(
                          leading: Icon(Icons.map_outlined, color: Colors.orange),
                          title: Text('Rimuovi mappa attiva', style: TextStyle(color: Colors.orange)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ));
                      items.add(const PopupMenuDivider());
                    }
                  }
                  
                  items.add(const PopupMenuItem(
                    value: 'exit',
                    child: ListTile(
                      leading: Icon(Icons.exit_to_app, color: Colors.redAccent),
                      title: Text('Esci dalla sessione', style: TextStyle(color: Colors.redAccent)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ));
                  
                  return items;
                },
              ),
            ],
          ),
        ),
        Expanded(child: _buildMapArea()),
        if (_chatMessages.isNotEmpty) _buildMobileChatPreview(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(color: Color(0xFF1A1A2E), border: Border(bottom: BorderSide(color: Colors.white10))),
                child: Row(
                  children: [
                    Text(widget.adventure.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_isMaster)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: _isHosting ? Colors.redAccent : const Color(0xFF00B0FF), foregroundColor: _isHosting ? Colors.white : Colors.black),
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                      onPressed: _leaveSession,
                      tooltip: 'Esci dalla sessione',
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildMapArea()),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isSidebarOpen ? _sidebarWidth : 0,
          decoration: const BoxDecoration(color: Color(0xFF12121E), border: Border(left: BorderSide(color: Colors.white10))),
          child: _isSidebarOpen
              ? Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF00B0FF),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      tabs: const [Tab(icon: Icon(Icons.chat), text: 'Chat'), Tab(icon: Icon(Icons.folder), text: 'File'), Tab(icon: Icon(Icons.music_note), text: 'Audio')],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [_buildChatAndDiceTab(), _buildFilesTab(), _buildAudioTab()],
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildMapArea() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0F0F1A),
      child: _currentMapUrl != null
          ? InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(_currentMapUrl!, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) {
                return const Center(child: Text('Impossibile caricare la mappa', style: TextStyle(color: Colors.white54)));
              }),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_outlined, size: 64, color: Colors.white38),
                  const SizedBox(height: 12),
                  const Text('Nessuna mappa caricata', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(_isMaster ? 'Carica una mappa dal menu File' : 'In attesa della mappa del Master', style: const TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            ),
    );
  }

  Widget _buildMobileChatPreview() {
    final lastMessages = _chatMessages.length > 2 ? _chatMessages.sublist(_chatMessages.length - 2) : _chatMessages;
    return GestureDetector(
      onTap: _openMobileChat,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(color: Color(0xFF1A1A2E), border: Border(top: BorderSide(color: Colors.white10))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: lastMessages.map((msg) {
            String preview = '';
            if (msg['type'] == 'system') {
              preview = msg['content'];
            } else if (msg['type'] == 'dice') {
              final dice = msg['diceRoll'] as DiceRoll;
              preview = '🎲 ${dice.author}: ${dice.total}';
            } else {
              preview = '${msg['author']}: ${msg['content']}';
            }
            return Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text(preview, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis));
          }).toList(),
        ),
      ),
    );
  }

  void _showMobileFilesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📁 File e Mappe', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (_isMaster)
                  IconButton(icon: const Icon(Icons.upload_file, color: Color(0xFF00B0FF)), onPressed: () { Navigator.pop(context); _uploadFile(); }),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _files.isEmpty
                  ? const Center(child: Text('Nessun file caricato', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: _files.length,
                      itemBuilder: (ctx, i) {
                        final f = _files[i];
                        final bool isImage = f['type'] == 'image';
                        final bool isCurrentMap = f['url'] == _currentMapUrl;
                        return ListTile(
                          leading: Icon(isImage ? Icons.image : Icons.description, color: const Color(0xFF00B0FF)),
                          title: Text(f['name'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                          subtitle: Text(f['size'], style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isMaster)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () { Navigator.pop(context); _deleteFile(f['name'], f['url']); },
                                ),
                              if (isImage && !isCurrentMap)
                                IconButton(
                                  icon: const Icon(Icons.map, color: Color(0xFF00B0FF), size: 20),
                                  tooltip: 'Imposta come mappa',
                                  onPressed: () { 
                                    _setAsMap(f['url']); 
                                    Navigator.pop(context); 
                                  },
                                ),
                              if (isImage)
                                IconButton(
                                  icon: const Icon(Icons.visibility, color: Colors.white70),
                                  onPressed: () { Navigator.pop(context); _showImagePreview(f['url']); },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileAudioSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
            const Text('🎵 Audio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(child: _buildAudioTab()),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(url, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) {
                return const Center(child: Text('Impossibile caricare l\'immagine', style: TextStyle(color: Colors.white)));
              }),
            ),
            Positioned(top: 10, right: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildChatAndDiceTab() {
    return Column(
      children: [
        if (_isMaster)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.visibility_off, size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                const Text('Nascondi ai giocatori', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                Switch(value: _hideRollFromPlayers, activeColor: const Color(0xFF00B0FF), onChanged: (_) => _toggleHiddenRoll()),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
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
                  onSubmitted: (val) => _addChatMessage(val),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.send, color: Color(0xFF00B0FF)), onPressed: _canInteract ? () => _addChatMessage(_chatCtrl.text) : null),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['d4','d6','d8','d10','d12','d20','d100']
                .map((d) => ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E3F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: const Size(40, 32)),
                      onPressed: _canInteract ? () => _addChatMessage('/rd 1$d') : null,
                      child: Text(d, style: const TextStyle(fontSize: 11)),
                    ))
                .toList(),
          ),
        ),
        const Divider(color: Colors.white24, height: 16),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollCtrl,
            padding: const EdgeInsets.all(12),
            itemCount: _chatMessages.length,
            reverse: true,
            itemBuilder: (ctx, index) {
              final msg = _chatMessages[_chatMessages.length - 1 - index];
              if (msg['type'] == 'system') {
                return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(msg['content'], style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic), textAlign: TextAlign.center));
              }
              if (msg['type'] == 'dice') {
                return _DiceRollCard(diceRoll: msg['diceRoll'] as DiceRoll, viewerIsMaster: _isMaster);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 14, backgroundColor: const Color(0xFF00B0FF).withOpacity(0.3), child: Text((msg['author'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Color(0xFF00B0FF), fontSize: 11))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(msg['author'] ?? 'Sconosciuto', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 6),
                              Text(DateFormat('HH:mm').format(msg['time'] as DateTime), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                          Text(msg['content'], style: const TextStyle(color: Colors.white, fontSize: 13)),
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
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00B0FF), side: const BorderSide(color: Color(0xFF00B0FF))),
              onPressed: _canInteract ? _uploadFile : null,
              icon: const Icon(Icons.upload_file),
              label: const Text('Carica'),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _files.isEmpty
                ? const Center(child: Text('Nessun file caricato.\nIl Master può aggiungere mappe o documenti.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (ctx, i) {
                      final f = _files[i];
                      final bool isImage = f['type'] == 'image';
                      final bool isCurrentMap = f['url'] == _currentMapUrl;
                      return ListTile(
                        leading: Icon(isImage ? Icons.image : Icons.description, color: const Color(0xFF00B0FF)),
                        title: Text(f['name'], style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text(f['size'], style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isMaster)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                tooltip: 'Elimina file',
                                onPressed: () => _deleteFile(f['name'], f['url']),
                              ),
                            if (isImage)
                              IconButton(
                                icon: Icon(isCurrentMap ? Icons.map : Icons.map_outlined, color: isCurrentMap ? const Color(0xFF00C853) : Colors.white54),
                                tooltip: isCurrentMap ? 'Mappa attiva' : 'Imposta come mappa',
                                onPressed: isCurrentMap ? null : () => _setAsMap(f['url']),
                              ),
                            if (isImage)
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.white70),
                                onPressed: () => _showImagePreview(f['url']),
                              ),
                          ],
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
    return ValueListenableBuilder<String?>(
      valueListenable: _currentTrackNotifier,
      builder: (context, currentTrackName, child) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🎵 Musica', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  if (_isMaster)
                    TextButton.icon(
                      onPressed: () => _uploadAudio(true),
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF00B0FF)),
                      label: const Text('Carica', style: TextStyle(color: Color(0xFF00B0FF), fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 2,
                child: ListView(
                  children: [
                    ..._tracks.map((t) => _buildAudioTile(t, true, currentTrackName, false, true)),
                    
                    if (_customTracks.isNotEmpty) ...[
                      const Divider(color: Colors.white24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text('📁 Personali', style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
                      ),
                      ..._customTracks.map((t) => _buildAudioTile(t, true, currentTrackName, true, true)),
                    ],
                  ],
                ),
              ),
              
              const Divider(color: Colors.white24, height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🔊 Effetti', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  if (_isMaster)
                    TextButton.icon(
                      onPressed: () => _uploadAudio(false),
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF00B0FF)),
                      label: const Text('Carica', style: TextStyle(color: Color(0xFF00B0FF), fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 1,
                child: ListView(
                  children: [
                    ..._sfx.map((s) => _buildSfxTile(s, false)),

                    if (_customSfx.isNotEmpty) ...[
                      const Divider(color: Colors.white24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text('📁 Personali', style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
                      ),
                      ..._customSfx.map((s) => _buildSfxTile(s, true)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAudioTile(Map<String, dynamic> t, bool isMasterControl, String? currentTrackName, bool isCustom, bool isMusic) {
    final isActive = currentTrackName == t['name'];
    return ListTile(
      dense: true,
      leading: Icon(
        isActive ? Icons.play_circle_fill : Icons.music_note,
        color: isActive ? const Color(0xFF00B0FF) : Colors.white54,
      ),
      title: Text(
        t['name'],
        style: TextStyle(color: isActive ? Colors.white : Colors.white70, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isMaster && isCustom)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: 'Elimina audio',
              onPressed: () => _deleteAudio(t['name'], t['url'], isMusic),
            ),
          
          isMasterControl && _isMaster
              ? Switch(
                  value: isActive,
                  activeColor: const Color(0xFF00B0FF),
                  onChanged: (v) {
                    if (v) {
                      _playTrack(t['url'], t['name']);
                    } else {
                      _stopTrack();
                    }
                  },
                )
              : (isActive ? const Icon(Icons.volume_up, color: Color(0xFF00B0FF), size: 20) : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildSfxTile(Map<String, dynamic> s, bool isCustom) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.speaker_phone, color: Colors.white54, size: 20),
      title: Text(
        s['name'],
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      trailing: _isMaster && isCustom
          ? IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: 'Elimina effetto',
              onPressed: () => _deleteAudio(s['name'], s['url'], false),
            )
          : null,
      onTap: _canInteract ? () => _playSfx(s['url'], s['name']) : null,
    );
  }
}

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
        border: Border.all(color: isHidden ? Colors.white24 : (diceRoll.isMasterRoll ? const Color(0xFF7E57C2) : const Color(0xFF00B0FF)), width: isHidden ? 1 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isHidden ? Icons.visibility_off : Icons.casino, size: 14, color: isHidden ? Colors.white38 : (diceRoll.isMasterRoll ? const Color(0xFF7E57C2) : const Color(0xFF00B0FF))),
              const SizedBox(width: 6),
              Text(diceRoll.author, style: TextStyle(color: isHidden ? Colors.white38 : Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(DateFormat('HH:mm').format(diceRoll.timestamp), style: TextStyle(color: isHidden ? Colors.white24 : Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Text(displayContent, style: TextStyle(color: isHidden ? Colors.white54 : Colors.white, fontSize: 13, fontWeight: isHidden ? FontWeight.normal : FontWeight.w500)),
          if (!isHidden && diceRoll.individualRolls.length > 1) ...[
            const SizedBox(height: 4),
            Text('Dettagli: ${diceRoll.individualRolls.join(', ')}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}