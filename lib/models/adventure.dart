enum AdventureRole { master, player }
enum AdventureStatus { active, paused, completed, locked, ended }

class Adventure {
  final String id;
  final String title;
  final String subtitle;
  final String? description;
  final AdventureRole role;
  final AdventureStatus status;
  final DateTime? createdAt;
  final DateTime? nextSession;
  final DateTime? lastSession;
  
  final int? levelMin;
  final int? levelMax;
  final int? maxPlayers;
  final int? currentPlayers;
  final String? joinCode;
  final bool isOneShot;
  final String? createdBy;
  final List<String>? participants;
  final bool isPinned;
  final String? coverImageUrl;

  Adventure({
    required this.id, required this.title, required this.subtitle, this.description,
    required this.role, this.status = AdventureStatus.active, this.createdAt, this.nextSession, this.lastSession,
    this.levelMin, this.levelMax, this.maxPlayers, this.currentPlayers, this.joinCode, this.isOneShot = false,
    this.createdBy, this.participants, this.isPinned = false, this.coverImageUrl,
  });

  factory Adventure.fromJson(Map<String, dynamic> json) {
    return Adventure(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String?,
      role: AdventureRole.values.firstWhere((e) => e.toString() == 'AdventureRole.${json['role']}', orElse: () => AdventureRole.player),
      status: AdventureStatus.values.firstWhere((e) => e.toString() == 'AdventureStatus.${json['status']}', orElse: () => AdventureStatus.active),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      nextSession: json['next_session'] != null ? DateTime.parse(json['next_session']) : null,
      lastSession: json['last_session'] != null ? DateTime.parse(json['last_session']) : null,
      levelMin: json['level_min'] as int?,
      levelMax: json['level_max'] as int?,
      maxPlayers: json['max_players'] as int?,
      currentPlayers: json['current_players'] as int?,
      joinCode: json['join_code'] as String?,
      isOneShot: json['is_one_shot'] == true,
      createdBy: json['created_by'] as String?,
      participants: json['participants'] != null ? List<String>.from(json['participants']) : null,
      isPinned: json['is_pinned'] as bool? ?? false,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'subtitle': subtitle, 'description': description,
    'role': role.toString().split('.').last, 'status': status.toString().split('.').last,
    'created_at': createdAt?.toIso8601String(), 'next_session': nextSession?.toIso8601String(),
    'level_min': levelMin, 'level_max': levelMax, 'max_players': maxPlayers,
    'current_players': currentPlayers, 'join_code': joinCode, 'is_one_shot': isOneShot,
  };

  Adventure copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    AdventureRole? role,
    AdventureStatus? status,
    DateTime? createdAt,
    DateTime? nextSession,
    DateTime? lastSession,
    int? levelMin,
    int? levelMax,
    int? maxPlayers,
    int? currentPlayers,
    String? joinCode,
    bool? isOneShot,
    List<String>? participants,
    bool? isPinned,
    String? coverImageUrl,
    String? createdBy,
  }) {
    return Adventure(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      nextSession: nextSession ?? this.nextSession,
      lastSession: lastSession ?? this.lastSession,
      levelMin: levelMin ?? this.levelMin,
      levelMax: levelMax ?? this.levelMax,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      joinCode: joinCode ?? this.joinCode,
      participants: participants ?? this.participants,
      isPinned: isPinned ?? this.isPinned,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  bool get isAccessible => status != AdventureStatus.locked && status != AdventureStatus.ended;
  
  String formatSessionDate(DateTime date) {
    const months = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}