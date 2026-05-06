import 'package:flutter/material.dart';
import 'package:cinemax_seat_booking/core/services/tmdb_service.dart';
import 'package:cinemax_seat_booking/presentation/views/showtime_selection_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final backdropHeight = screenWidth * 0.6;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Image.network(
                    TmdbService.getImageUrl(
                      widget.movie['backdrop_path'] ?? widget.movie['poster_path'],
                    ),
                    height: backdropHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: backdropHeight,
                      color: const Color(0xFF1E1E1E),
                      child: const Center(
                        child: Icon(Icons.movie, color: Colors.grey, size: 60),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 4,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movie['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.movie['vote_average']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.movie['overview'] ?? 'No description available',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    // 1 About to change as Available Theaters that showing this movie
                    const Text(
                      "Available Theaters",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:80,
                      width: double.infinity,
                      child: GestureDetector(
                        onTap:(){
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ShowtimeSelection(),
                            ),
                          );
                        },
                        child:
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            color: const Color(0xFF1E1E1E),
                          ),
                          child:
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(12),
                                ),
                                child: Image.asset(
                                  "assets/images/theaters/archana.jfif",
                                  height: 80,
                                  width: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 13),
                              const Text("Archana Cinema",style: TextStyle(color: Colors.white,fontSize: 16),),
                              const Spacer(),
                              const Icon(Icons.arrow_forward,color: Colors.white,size: 20,),
                              const SizedBox(width: 10)
                            ],
                          )
                        )
                      )
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height:80,
                      width: double.infinity,
                      child: GestureDetector(
                        onTap:(){
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ShowtimeSelection(),
                            ),
                          );
                        },
                        child:
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            color: const Color(0xFF1E1E1E),
                          ),
                          child:
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(12),
                                ),
                                child: Image.asset(
                                  "assets/images/theaters/gk.jfif",
                                  height: 80,
                                  width: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 13),
                              const Text("GK Cinemax",style: TextStyle(color: Colors.white,fontSize: 16),),
                              const Spacer(),
                              const Icon(Icons.arrow_forward,color: Colors.white,size: 20,),
                              const SizedBox(width: 10)
                            ],
                          )
                        )
                      )
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}