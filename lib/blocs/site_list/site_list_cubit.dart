import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/site_model.dart';
import '../../data/repositories/site_repository.dart';
import 'site_list_state.dart';

class SiteListCubit extends Cubit<SiteListState> {
  final SiteRepository _siteRepository;

  SiteListCubit({SiteRepository? siteRepository})
      : _siteRepository = siteRepository ?? SiteRepository(),
        super(const SiteListState());

  Future<void> loadSites() async {
    emit(state.copyWith(status: SiteListStatus.loading));

    try {
      final sites = await _siteRepository.getAllSites();
      emit(state.copyWith(
        status: SiteListStatus.loaded,
        sites: sites,
        filteredSites: sites,
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
      emit(state.copyWith(
        selectedCategory: null,
        filteredSites: state.searchQuery.isEmpty
            ? state.sites
            : _filterBySearch(state.sites, state.searchQuery),
      ));
    } else {
      final filtered = state.sites.where((site) => site.category == category).toList();
      final searched = state.searchQuery.isEmpty
          ? filtered
          : _filterBySearch(filtered, state.searchQuery);

      emit(state.copyWith(
        selectedCategory: category,
        filteredSites: searched,
      ));
    }
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query));

    List<SiteModel> base = state.selectedCategory != null
        ? state.sites.where((site) => site.category == state.selectedCategory).toList()
        : state.sites;

    final searched = query.isEmpty ? base : _filterBySearch(base, query);

    emit(state.copyWith(filteredSites: searched));
  }

  List<SiteModel> _filterBySearch(List<SiteModel> sites, String query) {
    final lowerQuery = query.toLowerCase();
    return sites.where((site) {
      return site.nameEn.toLowerCase().contains(lowerQuery) ||
          site.nameSw.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  void clearFilters() {
    emit(state.copyWith(
      searchQuery: '',
      selectedCategory: null,
      filteredSites: state.sites,
    ));
  }
}