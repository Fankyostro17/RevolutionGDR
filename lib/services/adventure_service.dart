import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/adventure.dart';
import '../config.dart';

class AdventureService {
  static const String _baseUrl = AppConfig.baseUrl;

  static Future<Adventure?> createCampaign({
    required String title,
    String? subtitle,
    String? description,
    int? levelMin,
    int? levelMax,
    int? maxPlayers,
    DateTime? nextSession,
    bool isOneShot = false,
  }) async {
    final authService = AuthService();
    if (!authService.isAuthenticated) return null;
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/adventures'),
        headers: authService.authHeaders,
        body: jsonEncode({
          'title': title.trim(),
          'subtitle': subtitle?.trim() ?? '',
          'description': description?.trim() ?? '',
          'level_min': levelMin ?? 1,
          'level_max': levelMax ?? 20,
          'max_players': maxPlayers ?? 0,
          'next_session': nextSession?.toIso8601String(),
          'is_one_shot': isOneShot,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Adventure.fromJson(data['adventure']);
      }
      print('❌ Errore creazione: ${response.body}');
      return null;
    } catch (e) {
      print('❌ Errore di rete: $e');
      return null;
    }
  }

  // 🔹 Ottiene le avventure dell'utente loggato
  static Future<List<Adventure>> fetchAdventures({
    required AdventureRole role,
  }) async {
    final authService = AuthService();
    if (!authService.isAuthenticated) return [];
    
    try {
      final roleParam = role.toString().split('.').last;
      final response = await http.get(
        Uri.parse('$_baseUrl/adventures?role=$roleParam'),
        headers: authService.authHeaders,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List adventuresJson = data['adventures'] ?? [];
        return adventuresJson.map((json) => Adventure.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Errore fetch: $e');
      return [];
    }
  }

  static Future<bool> joinCampaign({
    required String campaignCode,
  }) async {
    final authService = AuthService();
    if (!authService.isAuthenticated) return false;
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/adventures/join-by-code'),
        headers: authService.authHeaders,
        body: jsonEncode({
          'campaign_code': campaignCode.trim().toUpperCase(),
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return true;
      }
      
      final errorData = jsonDecode(response.body);
      print('❌ Join fallito: ${errorData['error']}');
      return false;
      
    } catch (e) {
      print('❌ Errore di rete join: $e');
      return false;
    }
  }

  // 🔹 Ottieni dettaglio campagna per ID
  static Future<Adventure?> fetchAdventureById(String id) async {
    final authService = AuthService();
    if (!authService.isAuthenticated) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/adventures/$id'),
        headers: authService.authHeaders,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Adventure.fromJson(data['adventure']);
      }
      return null;
    } catch (e) {
      print('❌ Errore fetch dettaglio: $e');
      return null;
    }
  }

  // 🔹 Aggiorna campagna (Solo Master)
  static Future<Adventure?> updateAdventure(String id, Map<String, dynamic> data) async {
    final authService = AuthService();
    if (!authService.isAuthenticated) return null;
    
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/adventures/$id'),
        headers: authService.authHeaders,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return Adventure.fromJson(resData['adventure']);
      }
      return null;
    } catch (e) {
      print('❌ Errore update: $e');
      return null;
    }
  }

  // 🔹 Elimina campagna (Solo Master - rimuove tutti i partecipanti)
  static Future<bool> deleteCampaign(String id) async {
    final authService = AuthService();
    if (!authService.isAuthenticated) return false;
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/adventures/$id'), 
        headers: authService.authHeaders
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) { 
      print('❌ Errore delete: $e'); 
      return false; 
    }
  }

  // 🔹 Toggle stato Active/Ended (Solo Master)
  static Future<Adventure?> toggleStatus(String id) async {
    final authService = AuthService();
    if (!authService.isAuthenticated) return null;
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/adventures/$id/status'), 
        headers: authService.authHeaders
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return Adventure.fromJson(jsonDecode(res.body)['adventure']);
      }
      return null;
    } catch (e) { 
      print('❌ Errore toggle: $e'); 
      return null; 
    }
  }
}