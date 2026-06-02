import 'package:flutter/material.dart';
import '../services/adventure_service.dart';

class JoinCampaignScreen extends StatefulWidget {
  const JoinCampaignScreen({super.key});

  @override
  State<JoinCampaignScreen> createState() => _JoinCampaignScreenState();
}

class _JoinCampaignScreenState extends State<JoinCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final code = _codeController.text.trim().toUpperCase();
    
    final success = await AdventureService.joinCampaign(
      campaignCode: code,
    );
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Codice non valido o campagna non trovata'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
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
        title: const Text('Unisciti a una Campagna'),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.qr_code, size: 80, color: Color(0xFF00B0FF)),
              const SizedBox(height: 24),
              const Text(
                'Inserisci il codice fornito dal Master',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _codeController,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 4),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Codice Campagna',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'ABC123XY',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00B0FF), width: 2),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 6) {
                    return 'Codice troppo corto';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B0FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _handleJoin,
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
                        'Unisciti alla Campagna',
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