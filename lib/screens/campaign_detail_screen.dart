import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/adventure.dart';
import '../services/adventure_service.dart';
import '../services/auth_service.dart';

class CampaignDetailScreen extends StatefulWidget {
  final String adventureId;
  
  const CampaignDetailScreen({super.key, required this.adventureId});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  // 🔹 Stato e dati
  Adventure? _adv;
  bool _isLoading = true;
  bool _isEditing = false;

  // 🔹 Controllers per i TextField in modalità modifica
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _minLvlCtrl;
  late TextEditingController _maxLvlCtrl;
  late TextEditingController _maxPlayersCtrl;
  
  // 🔹 Variabili per data e one-shot
  DateTime? _nextSession;
  bool _isOneShot = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _minLvlCtrl.dispose();
    _maxLvlCtrl.dispose();
    _maxPlayersCtrl.dispose();
    super.dispose();
  }

  // 🔹 Carica i dati della campagna dal backend
  Future<void> _load() async {
    final a = await AdventureService.fetchAdventureById(widget.adventureId);
    if (mounted) {
      setState(() {
        _adv = a;
        _isLoading = false;
        if (a != null) {
          _titleCtrl = TextEditingController(text: a.title);
          _descCtrl = TextEditingController(text: a.description ?? '');
          _minLvlCtrl = TextEditingController(text: a.levelMin?.toString() ?? '1');
          _maxLvlCtrl = TextEditingController(text: a.levelMax?.toString() ?? '20');
          _maxPlayersCtrl = TextEditingController(text: a.maxPlayers?.toString() ?? '0');
          _nextSession = a.nextSession;
          _isOneShot = a.isOneShot;
        }
      });
    }
  }

  // 🔹 Salva le modifiche (solo Master)
  Future<void> _save() async {
    if (_adv == null) return;
    
    final updated = await AdventureService.updateAdventure(
      _adv!.id,
      {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'level_min': int.tryParse(_minLvlCtrl.text),
        'level_max': int.tryParse(_maxLvlCtrl.text),
        'max_players': int.tryParse(_maxPlayersCtrl.text),
        'next_session': _nextSession?.toIso8601String(),
        'is_one_shot': _isOneShot,
      },
    );
    
    if (mounted) {
      if (updated != null) {
        setState(() {
          _adv = updated;
          _isEditing = false;
        });
        _showMsg('✅ Campagna aggiornata', const Color(0xFF00C853));
      } else {
        _showMsg('❌ Errore nel salvataggio', Colors.red);
      }
    }
  }

  // 🔹 Toggle stato Active/Ended (solo Master)
  Future<void> _toggleStatus() async {
    final updated = await AdventureService.toggleStatus(_adv!.id);
    if (mounted && updated != null) {
      setState(() => _adv = updated);
      _showMsg('Stato modificato', Colors.blue);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('🗑️ Eliminare Campagna?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tutti i giocatori verranno rimossi permanentemente.\nQuesta azione è irreversibile.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final ok = await AdventureService.deleteCampaign(_adv!.id);
      if (mounted) {
        if (ok) {
          Navigator.pop(context, true); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ Campagna eliminata'), backgroundColor: Colors.red),
          );
        } else {
          _showMsg('Errore eliminazione', Colors.red);
        }
      }
    }
  }

  void _showMsg(String msg, Color col) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: col, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _adv == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00B0FF))),
      );
    }
    
    final isMaster = AuthService().currentUser?.id == _adv!.createdBy;
    final isActive = _adv!.status == AdventureStatus.active;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica' : _adv!.title),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          if (isMaster)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: _isEditing ? _save : () => setState(() => _isEditing = true),
            ),
          if (isMaster)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMaster)
              Center(
                child: FilterChip(
                  label: Text(
                    isActive ? '🟢 ACTIVE' : '🔴 ENDED',
                    style: TextStyle(color: isActive ? Colors.black : Colors.white),
                  ),
                  backgroundColor: isActive ? const Color(0xFF00C853) : Colors.redAccent,
                  onSelected: (_) => _toggleStatus(),
                ),
              ),
            const SizedBox(height: 16),

            Card(
              color: const Color(0xFF1E1E3F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _isEditing
                        ? TextField(
                            controller: _titleCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                              hintText: 'Titolo campagna',
                            ),
                          )
                        : Text(
                            _adv!.title,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                    const SizedBox(height: 8),
                    if (_adv!.description != null && _adv!.description!.isNotEmpty)
                      _isEditing
                          ? TextField(
                              controller: _descCtrl,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                              decoration: const InputDecoration(
                                border: UnderlineInputBorder(),
                                hintText: 'Descrizione...',
                              ),
                            )
                          : Text(
                              _adv!.description!,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _StatBox(
                  icon: Icons.star,
                  label: 'Livello',
                  child: _isEditing
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _minLvlCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  border: UnderlineInputBorder(),
                                ),
                              ),
                            ),
                            const Text('-', style: TextStyle(color: Colors.white, fontSize: 16)),
                            Expanded(
                              child: TextField(
                                controller: _maxLvlCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  border: UnderlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '${_adv!.levelMin ?? 1}-${_adv!.levelMax ?? 20}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
                
                _StatBox(
                  icon: Icons.group,
                  label: 'Giocatori',
                  child: Text(
                    '${_adv!.currentPlayers ?? 0}/${_adv!.maxPlayers ?? 0}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),

                _StatBox(
                  icon: Icons.calendar_today,
                  label: 'Prossima Sessione',
                  child: GestureDetector(
                    onTap: _isEditing
                        ? () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _nextSession ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: const Color(0xFF00B0FF),
                                    surface: const Color(0xFF1A1A2E),
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (d != null) setState(() => _nextSession = d);
                          }
                        : null,
                    child: Text(
                      _nextSession == null
                          ? 'Non impostata'
                          : DateFormat('dd/MM/yyyy').format(_nextSession!),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                
                _StatBox(
                  icon: Icons.qr_code,
                  label: 'Codice Unione',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _adv!.joinCode ?? '---',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: Color(0xFF00B0FF)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _adv!.joinCode ?? ''));
                          _showMsg('📋 Codice copiato!', Colors.blue);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (isMaster)
              ListTile(
                contentPadding: EdgeInsets.zero,
                tileColor: const Color(0xFF1E1E3F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                title: const Text(
                  'One-Shot (Sessione Unica)',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Switch(
                  value: _isOneShot,
                  activeColor: const Color(0xFF00B0FF),
                  onChanged: _isEditing ? (v) => setState(() => _isOneShot = v) : null,
                ),
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B0FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: const Color(0xFF00B0FF).withOpacity(0.4),
                ),
                onPressed: () {
                  _showMsg('🎲 Avvio sessione in sviluppo...', const Color(0xFF6A1B9A));
                },
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Text(
                  'Entra nella Campagna',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00B0FF), size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}