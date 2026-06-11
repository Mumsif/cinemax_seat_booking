import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  static const String _apiKey = '5de348f41d84124d849ea5133de6f267';
  static const String _imageUrl = 'https://image.tmdb.org/t/p/w500';

  static Future<List<dynamic>> getPopularMovies() async {
    final response = await http.get(
      Uri.parse('https://api.themoviedb.org/3/movie/popular?api_key=$_apiKey'),
    );
    
    final data = jsonDecode(response.body);
    return data['results'];
  }

  static Future<List<dynamic>> getNowPlaying() async {
    final response = await http.get(
      Uri.parse('https://api.themoviedb.org/3/movie/now_playing?api_key=$_apiKey'),
    );
    
    final data = jsonDecode(response.body);
    return data['results'];
  }

  static String getImageUrl(String posterPath) {
    return '$_imageUrl$posterPath';
  }

  // Add this method
  static Future<Map<String, dynamic>?> getMovieDetails(int movieId) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.themoviedb.org/3/movie/$movieId?api_key=$_apiKey'),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching movie details: $e');
    }
    return null;
  }
}