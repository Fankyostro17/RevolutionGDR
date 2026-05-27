import 'package:socket_io_client/socket_io_client.dart' as IO;

class GameSocketService {
  static final GameSocketService _instance = GameSocketService._internal();
  factory GameSocketService() => _instance;
  GameSocketService._internal();

  IO.Socket? _socket;
  
  Function(bool)? onHostStatusChanged;
  Function(Map<String, dynamic>)? onNewMessage;
  Function(String)? onSystemMessage;

  void connect(String advId, String usrId, String usrName) {
    _socket = IO.io(
      'http://localhost:8000',
      IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    
    _socket!.onConnect((_) {
      _socket!.emit('join_session', {
        'adventure_id': advId,
        'user_id': usrId,
        'user_name': usrName,
      });
    });
    
    _socket!.on('host_status', (data) {
      if (onHostStatusChanged != null) {
        onHostStatusChanged!(data['is_hosting'] as bool);
      }
    });
    
    _socket!.on('new_message', (data) {
      if (onNewMessage != null) {
        onNewMessage!(Map<String, dynamic>.from(data));
      }
    });
    
    _socket!.connect();
  }
  
  // ✅ FIRMA: sendHostToggle(String, bool)
  void sendHostToggle(String advId, bool isHosting) {
    if (_socket?.connected ?? false) {
      _socket!.emit('host_toggle', {
        'adventure_id': advId,
        'is_hosting': isHosting,
      });
    }
  }
  
  // ✅ FIRMA: sendMessage(String, Map)
  void sendMessage(String advId, Map<String, dynamic> msg) {
    if (_socket?.connected ?? false) {
      _socket!.emit('send_message', {
        'adventure_id': advId,
        ...msg,
      });
    }
  }
  
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
  }
}