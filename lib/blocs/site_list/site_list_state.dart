import 'package:equatable/equatable.dart';
import '../../data/models/site_model.dart';

enum SiteListStatus { initial, loading, loaded, error }

class SiteListState extends Equatable {
  const SiteListState({
    this.status = SiteListStatus.initial,
    this.sites = const [],
    this.sitesById = const {},
    this.filteredSites = const [],
    this.errorMessage,
    this.searchQuery = '',
    this.selectedCategory,
  });
  final SiteListStatus status;
  final List<SiteModel> sites;
  final Map<String, SiteModel> sitesById;
  final List<SiteModel> filteredSites;
  final String? errorMessage;
  final String searchQuery;
  final String? selectedCategory;

  SiteListState copyWith({
    SiteListStatus? status,
    List<SiteModel>? sites,
    Map<String, SiteModel>? sitesById,
    List<SiteModel>? filteredSites,
    String? errorMessage,
    String? searchQuery,
    String? selectedCategory,
  }) {
    return SiteListState(
      status: status ?? this.status,
      sites: sites ?? this.sites,
      sitesById: sitesById ?? this.sitesById,
      filteredSites: filteredSites ?? this.filteredSites,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  @override
  List<Object?> get props => [
    status,
    sites,
    sitesById,
    filteredSites,
    errorMessage,
    searchQuery,
    selectedCategory,
  ];
}
