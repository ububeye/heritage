import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/site_model.dart';
import '../../data/repositories/site_repository.dart';
import 'site_list_state.dart';

class SiteListCubit extends Cubit<SiteListState> {
  final SiteRepository _siteRepository;
  StreamSubscription<List<SiteModel>>? _sitesSubscription;

  SiteListCubit({SiteRepository? siteRepository})
      : _siteRepository = siteRepository ?? SiteRepository(),
        super(const SiteListState()) {
    // Live updates: any change in Firestore (admin add/edit/delete) is pushed
    // to the cubit automatically. No need to call loadSites() on app start.
    _sitesSubscription = _siteRepository.watchSites().listen(
      (sites) {
        // Preserve current filter/search when a new snapshot arrives.
        final filtered = _applyFilters(sites, state.searchQuery, state.selectedCategory);
        emit(state.copyWith(
          status: SiteListStatus.loaded,
          sites: sites,
          filteredSites: filtered,
        ));
      },
      onError: (e) {
        emit(state.copyWith(
          status: SiteListStatus.error,
          errorMessage: e.toString(),
        ));
      },
    );
  }

  /// One-shot fetch (used by pull-to-refresh and admin screens).
  Future<void> loadSites() async {
    emit(state.copyWith(status: SiteListStatus.loading));

    try {
      final sites = await _siteRepository.getAllSites();
      final filtered = _applyFilters(sites, state.searchQuery, state.selectedCategory);
      emit(state.copyWith(
        status: SiteListStatus.loaded,
        sites: sites,
        filteredSites: filtered,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SiteListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void filterByCategory(String? category) {
    if (category == null || category.isEmpty) {
      final filtered = state.searchQuery.isEmpty
          ? state.sites
          : _filterBySearch(state.sites, state.searchQuery);
      emit(state.copyWith(
        selectedCategory: null,
        filteredSites: filtered,
      ));
    } else {
      final byCategory = state.sites.where((site) => site.category == category).toList();
      final filtered = state.searchQuery.isEmpty
          ? byCategory
          : _filterBySearch(byCategory, state.searchQuery);
      emit(state.copyWith(
        selectedCategory: category,
        filteredSites: filtered,
      ));
    }
  }

  void search(String query) {
    final base = state.selectedCategory != null
        ? state.sites.where((site) => site.category == state.selectedCategory).toList()
        : state.sites;
    final filtered = query.isEmpty ? base : _filterBySearch(base, query);
    emit(state.copyWith(
      searchQuery: query,
      filteredSites: filtered,
    ));
  }

  void clearFilters() {
    emit(state.copyWith(
      searchQuery: '',
      selectedCategory: null,
      filteredSites: state.sites,
    ));
  }

  List<SiteModel> _applyFilters(
    List<SiteModel> sites,
    String query,
    String? category,
  ) {
    Iterable<SiteModel> result = sites;
    if (category != null && category.isNotEmpty) {
      result = result.where((site) => site.category == category);
    }
    if (query.isNotEmpty) {
      result = result.where((site) {
        final lower = query.toLowerCase();
        return site.nameEn.toLowerCase().contains(lower) ||
            site.nameSw.toLowerCase().contains(lower) ||
            site.nameFr.toLowerCase().contains(lower) ||
            site.nameDe.toLowerCase().contains(lower) ||
            site.nameAr.toLowerCase().contains(lower) ||
            site.nameIt.toLowerCase().contains(lower) ||
            site.nameEs.toLowerCase().contains(lower);
      });
    }
    return result.toList();
  }

  List<SiteModel> _filterBySearch(List<SiteModel> sites, String query) {
    return _applyFilters(sites, query, null);
  }

  @override
  Future<void> close() {
    _sitesSubscription?.cancel();
    return super.close();
  }
}
