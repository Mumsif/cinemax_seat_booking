import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemax_seat_booking/domain/entities/movie_entity.dart';
import 'package:cinemax_seat_booking/domain/usecases/home/get_trending_movies.dart';
import 'package:cinemax_seat_booking/domain/usecases/home/get_now_playing_movies.dart';
import 'package:cinemax_seat_booking/core/providers.dart' as di;

class HomeState {
  final List<MovieEntity> trendingMovies;
  final List<MovieEntity> nowPlayingMovies;
  final bool isLoadingTrending;
  final bool isLoadingNowPlaying;
  final String? errorTrending;
  final String? errorNowPlaying;
  final int notificationCount;

  const HomeState({
    this.trendingMovies = const [],
    this.nowPlayingMovies = const [],
    this.isLoadingTrending = true,
    this.isLoadingNowPlaying = true,
    this.errorTrending,
    this.errorNowPlaying,
    this.notificationCount = 0,
  });

  HomeState copyWith({
    List<MovieEntity>? trendingMovies,
    List<MovieEntity>? nowPlayingMovies,
    bool? isLoadingTrending,
    bool? isLoadingNowPlaying,
    String? errorTrending,
    String? errorNowPlaying,
    int? notificationCount,
  }) {
    return HomeState(
      trendingMovies: trendingMovies ?? this.trendingMovies,
      nowPlayingMovies: nowPlayingMovies ?? this.nowPlayingMovies,
      isLoadingTrending: isLoadingTrending ?? this.isLoadingTrending,
      isLoadingNowPlaying: isLoadingNowPlaying ?? this.isLoadingNowPlaying,
      errorTrending: errorTrending,
      errorNowPlaying: errorNowPlaying,
      notificationCount: notificationCount ?? this.notificationCount,
    );
  }
}

class HomeViewModel extends StateNotifier<HomeState> {
  final GetTrendingMovies _getTrendingMovies;
  final GetNowPlayingMovies _getNowPlayingMovies;

  HomeViewModel(this._getTrendingMovies, this._getNowPlayingMovies) : super(const HomeState());

  Future<void> loadData() async {
    await Future.wait([
      loadTrendingMovies(),
      loadNowPlayingMovies(),
      loadNotificationCount(), // This could be another usecase
    ]);
  }

  Future<void> loadTrendingMovies() async {
    state = state.copyWith(isLoadingTrending: true, errorTrending: null);
    try {
      final movies = await _getTrendingMovies();
      state = state.copyWith(trendingMovies: movies, isLoadingTrending: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingTrending: false,
        errorTrending: 'Failed to load trending movies',
      );
    }
  }

  Future<void> loadNowPlayingMovies() async {
    state = state.copyWith(isLoadingNowPlaying: true, errorNowPlaying: null);
    try {
      final movies = await _getNowPlayingMovies();
      state = state.copyWith(nowPlayingMovies: movies, isLoadingNowPlaying: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingNowPlaying: false,
        errorNowPlaying: 'Failed to load now playing movies',
      );
    }
  }

  Future<void> loadNotificationCount() async {
    // In real impl, this would be a separate usecase for unread notifications.
    // Placeholder for now - in practice move the prefs + query logic here or to a dedicated usecase.
    // state = state.copyWith(notificationCount: await someUsecase());
  }

  void onMovieSelected(MovieEntity movie) {
    // Navigation logic can be here or delegated to a coordinator/router.
    // View can listen or we can expose navigation events.
    print('Movie selected: ${movie.title}');
  }

  void onTheaterSelected(String cinemaName) {
    print('Theater selected: $cinemaName');
  }
}

// Riverpod provider for the ViewModel
final homeViewModelProvider = StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  final getTrending = ref.watch(di.getTrendingMoviesProvider);
  final getNowPlaying = ref.watch(di.getNowPlayingMoviesProvider);
  return HomeViewModel(getTrending, getNowPlaying);
});
