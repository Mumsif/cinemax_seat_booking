import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseMovieDatasource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getActiveMovies() async {
    final snapshot = await _firestore
        .collection('movies')
        .where('status', isEqualTo: 'active')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['docId'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<String>> getTheatersForMovie(int movieId) async {
    final snapshot = await _firestore
        .collection('movies')
        .where('movieId', isEqualTo: movieId)
        .where('status', isEqualTo: 'active')
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['cinemaName'] as String?)
        .where((name) => name != null)
        .cast<String>()
        .toList();
  }
}
