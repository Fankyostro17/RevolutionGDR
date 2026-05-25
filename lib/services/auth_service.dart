import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // 🔹 CONFIGURAZIONE BACKEND PYTHON
  // Android Emulator: usa 10.0.2.2 invece di localhost
  // iOS Simulator: usa localhost
  // Dispositivo fisico: usa l'IP della tua rete (es. 192.168.1.100)
  // static const String _baseUrl = 'http://10.0.2.2:8000/api';
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  AppUser? _currentUser;
  String? _authToken;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _currentUser != null && _authToken != null;
  bool get isLoading => _isLoading;

  // 🔹 Inizializzazione: carica token e utente da SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userJson = prefs.getString('auth_user');
      
      if (token != null && userJson != null) {
        _authToken = token;
        _currentUser = AppUser.fromJson(jsonDecode(userJson));
      }
    } catch (e) {
      print('❌ Errore init auth: $e');
    }
  }

  // 🔹 LOGIN: chiama il backend Python
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    if (_isLoading) return false;
    _isLoading = true;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        _authToken = data['access_token'];
        _currentUser = AppUser.fromJson(data['user']);
        
        // Salva in SharedPreferences per persistenza
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _authToken!);
        await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));
        
        return true;
      } else {
        // Logga l'errore dal backend per debug
        final errorData = jsonDecode(response.body);
        print('❌ Login fallito: ${errorData['error']}');
        return false;
      }
    } catch (e) {
      print('❌ Errore di rete/login: $e');
      return false;
    } finally {
      _isLoading = false;
    }
  }

  // 🔹 REGISTER: chiama il backend Python
  Future<bool> register({
    required String email,
    required String password,
    required String nickname,
    required DateTime dateOfBirth,
  }) async {
    if (_isLoading) return false;
    _isLoading = true;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
          'nickname': nickname.trim(),
          'date_of_birth': dateOfBirth.toIso8601String().split('T').first, // Formato YYYY-MM-DD
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        print('❌ Registrazione fallita: ${errorData['error']}');
        return false;
      }
    } catch (e) {
      print('❌ Errore di rete/registrazione: $e');
      return false;
    } finally {
      _isLoading = false;
    }
  }

  // 🔹 LOGOUT: pulisce stato locale e SharedPreferences
  Future<void> logout() async {
    try {
      // Opzionale: notifica il backend (se vuoi invalidare token server-side)
      // await http.post(
      //   Uri.parse('$_baseUrl/auth/logout'),
      //   headers: authHeaders,
      // );
      
      _currentUser = null;
      _authToken = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_user');
    } catch (e) {
      print('❌ Errore logout: $e');
    }
  }

  // 🔹 Refresh dei dati utente (chiama GET /api/auth/me)
  Future<bool> refreshUser() async {
    if (_authToken == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = AppUser.fromJson(data['user']);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));
        
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Errore refresh user: $e');
      return false;
    }
  }

  Map<String, String> get authHeaders {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  void forceRefresh() {
    // Lo stato viene ricaricato da SharedPreferences al prossimo init()
  }

  void dispose() {
    // Cleanup se necessario in futuro
  }
}