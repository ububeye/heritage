import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/shared_prefs_service.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit() : super(const FavoritesState()) {
    _loadFavorites();
  }

  void _loadFavorites() {
    final favorites = SharedPrefsService.instance.favorites;
    emit(state.copyWith(favoriteIds: favorites));
  }

  bool isFavorite(String siteId) {
    return state.favoriteIds.contains(siteId);
  }

  Future<void> toggleFavorite(String siteId) async {
    final favorites = List<String>.from(state.favoriteIds);

    if (favorites.contains(siteId)) {
      favorites.remove(siteId);
    } else {
      favorites.add(siteId);
    }

    await SharedPrefsService.instance.setFavorites(favorites);
    emit(state.copyWith(favoriteIds: favorites));
  }

  Future<void> addFavorite(String siteId) async {
    if (!state.favoriteIds.contains(siteId)) {
      final favorites = List<String>.from(state.favoriteIds)..add(siteId);
      await SharedPrefsService.instance.setFavorites(favorites);
      emit(state.copyWith(favoriteIds: favorites));
    }
  }

  Future<void> removeFavorite(String siteId) async {
    if (state.favoriteIds.contains(siteId)) {
      final favorites = List<String>.from(state.favoriteIds)..remove(siteId);
      await SharedPrefsService.instance.setFavorites(favorites);
      emit(state.copyWith(favoriteIds: favorites));
    }
  }
}

class FavoritesState {
  const FavoritesState({this.favoriteIds = const []});
  final List<String> favoriteIds;

  FavoritesState copyWith({List<String>? favoriteIds}) {
    return FavoritesState(favoriteIds: favoriteIds ?? this.favoriteIds);
  }
}
