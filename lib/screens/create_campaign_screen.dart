import 'package:flutter/material.dart';
import '../services/adventure_service.dart';

class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // 🔹 Controllers per i TextField
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();        // ← NUOVO
  final _descriptionController = TextEditingController();
  final _minLevelController = TextEditingController(text: '1');      // ← NUOVO
  final _maxLevelController = TextEditingController(text: '20');     // ← NUOVO
  final _maxPlayersController = TextEditingController(text: '0');    // ← NUOVO
  
  // 🔹 Variabili per data e one-shot
  DateTime? _nextSessionDate;
  bool _isOneShot = false;                                    // ← NUOVO
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();                             // ← NUOVO
    _descriptionController.dispose();
    _minLevelController.dispose();                             // ← NUOVO
    _maxLevelController.dispose();                             // ← NUOVO
    _maxPlayersController.dispose();                           // ← NUOVO
    super.dispose();
  }

  // 🔹 Picker per la data
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF00B0FF),
            onPrimary: Colors.black,
            surface: const Color(0xFF1A1A2E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _nextSessionDate = picked);
  }

  // 🔹 Gestione creazione campagna
  Future<void> _handleCreateCampaign() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nextSessionDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Seleziona una data per la prossima sessione'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final adventure = await AdventureService.createCampaign(
      title: _titleController.text,
      subtitle: _subtitleController.text.isNotEmpty ? _subtitleController.text : null,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      levelMin: int.tryParse(_minLevelController.text) ?? 1,
      levelMax: int.tryParse(_maxLevelController.text) ?? 20,
      maxPlayers: int.tryParse(_maxPlayersController.text) ?? 0,
      nextSession: _nextSessionDate,
      isOneShot: _isOneShot,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (adventure != null) {
        Navigator.pop(context, true); // ← true = successo
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Errore nella creazione. Riprova.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('✨ Nuova Campagna'),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔹 Titolo (obbligatorio)
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Titolo Campagna *',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00B0FF)),
                  ),
                ),
                validator: (v) => (v == null || v.trim().length < 3) ? 'Minimo 3 caratteri' : null,
              ),
              const SizedBox(height: 20),

              // 🔹 Sottotitolo (opzionale)
              TextFormField(
                controller: _subtitleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Sottotitolo (opzionale)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00B0FF)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Livello Range (MIN - MAX)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minLevelController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Livello Min *',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF00B0FF)),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obbligatorio' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxLevelController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Livello Max *',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF00B0FF)),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obbligatorio' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 🔹 Max Giocatori
              TextFormField(
                controller: _maxPlayersController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Max Giocatori *',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00B0FF)),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 20),

              // 🔹 Prossima Sessione (Date Picker)
              ListTile(
                contentPadding: EdgeInsets.zero,
                tileColor: const Color(0xFF1E1E3F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                title: Text(
                  _nextSessionDate == null
                      ? 'Prossima Sessione *'
                      : 'Data: ${_nextSessionDate!.day}/${_nextSessionDate!.month}/${_nextSessionDate!.year}',
                  style: TextStyle(
                    color: _nextSessionDate == null ? Colors.white70 : Colors.white,
                  ),
                ),
                trailing: const Icon(Icons.calendar_today, color: Color(0xFF00B0FF)),
                onTap: _pickDate,
              ),
              const SizedBox(height: 20),

              // 🔹 One-Shot Toggle
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
                  onChanged: (v) => setState(() => _isOneShot = v),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Descrizione (opzionale)
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Descrizione (opzionale)',
                  labelStyle: TextStyle(color: Colors.white70),
                  alignLabelWithHint: true,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00B0FF)),
                  ),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              // 🔹 Pulsante Crea
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B0FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _handleCreateCampaign,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text(
                        'Crea Campagna',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}