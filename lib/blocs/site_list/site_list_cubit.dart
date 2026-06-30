import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/site_model.dart';
import '../../data/repositories/site_repository.dart';
import '../../data/services/firestore_service.dart';
import 'site_list_state.dart';

class SiteListCubit extends Cubit<SiteListState> {
  final SiteRepository _siteRepository;
  StreamSubscription<List<SiteModel>>? _sitesSubscription;
  bool _hasReceivedFirstSnapshot = false;

  SiteListCubit({SiteRepository? siteRepository})
      : _siteRepository = siteRepository ?? SiteRepository(),
        super(const SiteListState()) {
    // Reflect "loading" on the very first frame so the UI doesn't sit on
    // a stale empty list if the snapshot is slow to arrive.
    if (state.sites.isEmpty) {
      emit(state.copyWith(status: SiteListStatus.loading));
    }
    // Live updates: any change in Firestore (admin add/edit/delete) is pushed
    // to the cubit automatically. No need to call loadSites() on app start.
    _sitesSubscription = _siteRepository.watchSites().listen(
      (sites) {
        // Preserve current filter/search when a new snapshot arrives.
        // Only re-filter when the filter inputs or the site list actually
        // changed — otherwise every snapshot triggers an O(n) walk.
        final filtered = (_hasReceivedFirstSnapshot &&
                _sameList(sites, state.sites) &&
                state.searchQuery.isEmpty &&
                state.selectedCategory == null)
            ? state.filteredSites
            : _applyFilters(
                sites,
                state.searchQuery,
                state.selectedCategory,
              );
        _hasReceivedFirstSnapshot = true;
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
      _hasReceivedFirstSnapshot = true;
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

  /// Cheap list-equality check used to skip redundant re-filters when a
  /// snapshot arrives but the underlying data hasn't changed.
  static bool _sameList(List<SiteModel> a, List<SiteModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
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

  /// Flip the `featured` flag on the site with [siteId]. Only one site is
  /// featured at a time in practice (the explore screen's "Best Places"
  /// tile shows a single featured site), but the model allows several — we
  /// just toggle the given one and write through to Firestore.
  Future<void> setFeatured(String siteId, bool featured) async {
    final site = state.sites.firstWhere(
      (s) => s.id == siteId,
      orElse: () => state.sites.first,
    );
    if (site.id != siteId) return;
    try {
      await FirestoreService().updateSite(
        siteId,
        site.copyWith(featured: featured),
      );
      // The watch stream will pick the change up and re-emit; no local
      // optimistic update needed.
    } catch (_) {
      // Swallow — the watch stream will retry on next snapshot.
    }
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
