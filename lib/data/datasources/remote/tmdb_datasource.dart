import 'package:http/http.dart' as http;
import 'dart:convert';

class TmdbDatasource {
  static const String _apiKey = '5de348f41d84124d849ea5133de6f267'; // TODO: Move to secure config / env
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  Future<List<Map<String, dynamic>>> getPopularMovies() async {
    final response = await http.get(Uri.parse('$_baseUrl/movie/popular?api_key=$_apiKey'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    }
    throw Exception('Failed to load popular movies');
  }

  Future<List<Map<String, dynamic>>> getNowPlayingMovies() async {
    final response = await http.get(Uri.parse('$_baseUrl/movie/now_playing?api_key=$_apiKey'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    }
    throw Exception('Failed to load now playing movies');
  }

  Future<Map<String, dynamic>?> getMovieDetails(int movieId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/movie/$movieId?api_key=$_apiKey'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('TmdbDatasource error: $e');
    }
    return null;
  }
}
