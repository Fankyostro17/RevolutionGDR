import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';

class GameSocketService {
  static final GameSocketService _instance = GameSocketService._internal();
  factory GameSocketService() => _instance;
  GameSocketService._internal();

  IO.Socket? _socket;
  
  Function(bool)? onHostStatusChanged;
  Function(Map<String, dynamic>)? onNewMessage;
  Function(String)? onSystemMessage;
  Function? onHostClosed;
  
  Function(String, String)? onPlayTrack;
  Function? onStopTrack;
  Function(String, String)? onPlaySfx;

  static const String socketUrl = AppConfig.socketUrl;

  Function(Map<String, dynamic>)? onFileUploaded;
  Function(String)? onFileDeleted;

  Function(Map<String, dynamic>)? onAudioUploaded;
  Function(String)? onAudioDeleted;

  Function(String?)? onMapChanged;

  void connect(String advId, String usrId, String usrName) {
    _socket = IO.io(
      socketUrl,
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
      if (onHostStatusChanged != null) onHostStatusChanged!(data['is_hosting'] as bool);
    });
    
    _socket!.on('new_message', (data) {
      if (onNewMessage != null) onNewMessage!(Map<String, dynamic>.from(data));
    });
    
    _socket!.on('host_closed', (_) {
      if (onHostClosed != null) onHostClosed!();
    });

    _socket!.on('play_track', (data) {
      if (onPlayTrack != null) {
        onPlayTrack!(data['track_name'] as String, data['track_url'] as String);
      }
    });

    _socket!.on('stop_track', (_) {
      if (onStopTrack != null) onStopTrack!();
    });
    
    _socket!.on('play_sfx', (data) {
      if (onPlaySfx != null) {
        onPlaySfx!(data['sfx_name'] as String, data['sfx_url'] as String);
      }
    });

    _socket!.on('file_uploaded', (data) {
      if (onFileUploaded != null) {
        onFileUploaded!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('file_deleted', (data) {
      if (onFileDeleted != null) {
        onFileDeleted!(data['filename'] as String);
      }
    });

    _socket!.on('audio_uploaded', (data) {
      if (onAudioUploaded != null) {
        onAudioUploaded!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('audio_deleted', (data) {
      if (onAudioDeleted != null) {
        onAudioDeleted!(data['filename'] as String);
      }
    });

    _socket!.on('map_changed', (data) {
      if (onMapChanged != null) {
        onMapChanged!(data['map_url'] as String?);
      }
    });

    _socket!.connect();
  }

  void sendHostToggle(String advId, bool isHosting) {
    if (_socket?.connected ?? false) {
      _socket!.emit('host_toggle', {'adventure_id': advId, 'is_hosting': isHosting});
    }
  }
  
  void sendMessage(String advId, Map<String, dynamic> msg) {
    if (_socket?.connected ?? false) {
      _socket!.emit('send_message', {'adventure_id': advId, ...msg});
    }
  }

  void sendPlayTrack(String advId, String trackName, String trackUrl) {
    if (_socket?.connected ?? false) {
      _socket!.emit('play_track', {
        'adventure_id': advId,
        'track_name': trackName,
        'track_url': trackUrl,
      });
    }
  }

  void sendStopTrack(String advId) {
    if (_socket?.connected ?? false) {
      _socket!.emit('stop_track', {'adventure_id': advId});
    }
  }

  void sendPlaySfx(String advId, String sfxName, String sfxUrl) {
    if (_socket?.connected ?? false) {
      _socket!.emit('play_sfx', {
        'adventure_id': advId,
        'sfx_name': sfxName,
        'sfx_url': sfxUrl,
      });
    }
  }

  void sendFileUploaded(String advId, Map<String, dynamic> fileData) {
    if (_socket?.connected ?? false) {
      _socket!.emit('file_uploaded', {'adventure_id': advId, ...fileData});
    }
  }

  void sendFileDeleted(String advId, String filename) {
    if (_socket?.connected ?? false) {
      _socket!.emit('file_deleted', {'adventure_id': advId, 'filename': filename});
    }
  }

  void sendAudioUploaded(String advId, Map<String, dynamic> audioData) {
    if (_socket?.connected ?? false) {
      _socket!.emit('audio_uploaded', {'adventure_id': advId, ...audioData});
    }
  }

  void sendAudioDeleted(String advId, String filename) {
    if (_socket?.connected ?? false) {
      _socket!.emit('audio_deleted', {'adventure_id': advId, 'filename': filename});
    }
  }

  void sendMapChanged(String advId, String? mapUrl) {
    if (_socket?.connected ?? false) {
      _socket!.emit('map_changed', {
        'adventure_id': advId,
        'map_url': mapUrl,
      });
    }
  }
  
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
  }
}