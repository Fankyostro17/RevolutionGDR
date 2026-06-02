import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  
  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona la tua data di nascita'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devi accettare i termini per continuare'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    final success = await _authService.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nickname: _nicknameController.text.trim(),
      dateOfBirth: _dateOfBirth!,
    );
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrazione completata! Ora accedi.'),
            backgroundColor: Color(0xFF00C853),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrazione fallita. Email o nickname già in uso.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Crea il tuo Personaggio',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Unisciti al mondo di Il Tavolo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                
                const SizedBox(height: 32),
                
                TextFormField(
                  controller: _nicknameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nickname *',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.person, color: Color(0xFF00B0FF)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00B0FF), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Nickname troppo corto (min. 3 caratteri)';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value!)) {
                      return 'Usa solo lettere, numeri e underscore';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF00B0FF)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00B0FF), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci la tua email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Inserisci un\'email valida';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _dateOfBirth == null
                        ? 'Data di nascita *'
                        : 'Data: ${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                    style: TextStyle(
                      color: _dateOfBirth == null ? Colors.white70 : Colors.white,
                    ),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: Color(0xFF00B0FF)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2005, 1, 1),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
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
                    if (picked != null) {
                      setState(() => _dateOfBirth = picked);
                    }
                  },
                ),
                
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00B0FF)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00B0FF), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci una password';
                    }
                    if (value.length < 8) {
                      return 'Minimo 8 caratteri';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Conferma Password *',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00B0FF)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00B0FF), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Le password non coincidono';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      activeColor: const Color(0xFF00B0FF),
                      checkColor: Colors.black,
                      onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                        child: const Text.rich(
                          TextSpan(
                            text: 'Accetto i ',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                            children: [
                              TextSpan(
                                text: 'Termini di Servizio',
                                style: TextStyle(
                                  color: Color(0xFF00B0FF),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: ' e l\''),
                              TextSpan(
                                text: 'Informativa Privacy',
                                style: TextStyle(
                                  color: Color(0xFF00B0FF),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
                    elevation: 4,
                    shadowColor: const Color(0xFF00B0FF).withOpacity(0.4),
                  ),
                  onPressed: _isLoading ? null : _handleRegister,
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
                          'Crea Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Hai già un account? ',
                      style: TextStyle(color: Colors.white54),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        'Accedi',
                        style: TextStyle(
                          color: Color(0xFF00B0FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}