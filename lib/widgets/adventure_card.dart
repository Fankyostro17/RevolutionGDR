import 'package:flutter/material.dart';
import '../models/adventure.dart';
import '../screens/campaign_detail_screen.dart';
import 'package:intl/intl.dart';

class AdventureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? description;
  final AdventureRole role;

  final DateTime? nextSession;
  final DateTime? lastSession;
  
  final int? levelMin;
  final int? levelMax;
  final int? maxPlayers;
  final int? currentPlayers;
  final String? joinCode;
  final bool isOneShot;
  
  final String adventureId;
  final String? createdBy;
  final AdventureStatus status;
  
  final VoidCallback? onTap;
  final bool isLocked;

  const AdventureCard({
    super.key,
    
    required this.title,
    required this.subtitle,
    this.description,
    required this.role,
    
    this.nextSession,
    this.lastSession,
    
    this.levelMin,
    this.levelMax,
    this.maxPlayers,
    this.currentPlayers,
    this.joinCode,
    this.isOneShot = false,
    
    required this.adventureId,
    this.createdBy,
    this.status = AdventureStatus.active,
    
    this.onTap,
    this.isLocked = false,
  });

  String _formatDate(DateTime date) {
    const months = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isMaster = role == AdventureRole.master;
    
    return Card(
      color: const Color(0xFF1E1E3F),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLocked 
            ? Colors.white24 
            : const Color(0xFF00B0FF).withOpacity(0.4),
          width: isLocked ? 1 : 1.5,
        ),
      ),
      elevation: isLocked ? 0 : 4,
      shadowColor: const Color(0xFF00B0FF).withOpacity(0.2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLocked ? null : () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CampaignDetailScreen(
                  adventureId: adventureId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isLocked
                        ? [Colors.grey.shade700, Colors.grey.shade800]
                        : [
                            const Color(0xFF00B0FF).withOpacity(0.3),
                            const Color(0xFF5E35B1).withOpacity(0.2),
                          ],
                    ),
                    border: Border.all(
                      color: isLocked
                        ? Colors.white24
                        : const Color(0xFF00B0FF).withOpacity(0.6),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isLocked 
                      ? Icons.lock_outline 
                      : (isMaster ? Icons.shield : Icons.diamond),
                    color: isLocked ? Colors.white38 : const Color(0xFF00B0FF),
                    size: 28,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isLocked ? Colors.white38 : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          decoration: isLocked ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isLocked ? Colors.white24 : Colors.white54,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      if (description != null && !isLocked) ...[
                        const SizedBox(height: 8),
                        Text(
                          description!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      const SizedBox(height: 8),
                      
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (!isLocked && (levelMin != null || levelMax != null))
                            _InfoChip(
                              icon: Icons.star,
                              label: 'Liv. ${levelMin ?? 1}-${levelMax ?? 20}',
                              color: const Color(0xFFE0F7FA),
                              isTextDark: true,
                            ),
                          
                          if (!isLocked && maxPlayers != null)
                            _InfoChip(
                              icon: Icons.group,
                              label: '${currentPlayers ?? 0}/$maxPlayers',
                              color: const Color(0xFF29B6F6),
                            ),
                          
                          if (!isLocked && nextSession != null && isMaster)
                            _InfoChip(
                              icon: Icons.calendar_today,
                              label: DateFormat('dd/MM').format(nextSession!),
                              color: const Color(0xFF00B0FF),
                            ),
                          
                          if (!isLocked && lastSession != null && !isMaster)
                            _InfoChip(
                              icon: Icons.history,
                              label: 'Ultima: ${DateFormat('dd/MM').format(lastSession!)}',
                              color: const Color(0xFF5E35B1),
                            ),
                          
                          if (!isLocked && isOneShot)
                            _InfoChip(
                              icon: Icons.bolt,
                              label: 'One-Shot',
                              color: const Color(0xFF7E57C2),
                            ),

                          if (!isLocked && status != AdventureStatus.active)
                            _InfoChip(
                              icon: status == AdventureStatus.ended ? Icons.flag : Icons.pause,
                              label: status.toString().split('.').last.toUpperCase(),
                              color: status == AdventureStatus.ended ? Colors.redAccent : Colors.orange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                Icon(
                  isLocked ? Icons.lock_outline : Icons.chevron_right,
                  color: isLocked ? Colors.white24 : Colors.white54,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isTextDark;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.isTextDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isTextDark ? Colors.black87 : color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}