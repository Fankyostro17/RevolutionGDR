class AppConfig {
  //static const String baseUrl = 'http://10.0.2.2:8000/api'; 
  //static const String socketUrl = 'http://10.0.2.2:8000';
  static const String baseUrl = 'http://192.168.10.185:8000/api'; 
  static const String socketUrl = 'http://192.168.10.185:8000';

  static String getAdventureUploadUrl(String adventureId) => '$baseUrl/adventures/$adventureId/upload';
}