import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/site_model.dart';
import '../../data/services/shared_prefs_service.dart';

class ExploreCubit extends Cubit<ExploreState> {
  ExploreCubit() : super(const ExploreState());

  List<String> get itinerary => SharedPrefsService.instance.itinerary;

  void toggleMapView() {
    emit(state.copyWith(isMapView: !state.isMapView));
  }

  void setMapView(bool isMapView) {
    emit(state.copyWith(isMapView: isMapView));
  }

  Future<void> addToItinerary(String siteId) async {
    await SharedPrefsService.instance.addToItinerary(siteId);
    emit(state.copyWith(itinerary: SharedPrefsService.instance.itinerary));
  }

  Future<void> removeFromItinerary(String siteId) async {
    await SharedPrefsService.instance.removeFromItinerary(siteId);
    emit(state.copyWith(itinerary: SharedPrefsService.instance.itinerary));
  }

  bool isInItinerary(String siteId) {
    return SharedPrefsService.instance.isInItinerary(siteId);
  }

  void selectSite(SiteModel site) {
    emit(state.copyWith(selectedSite: site));
  }

  void clearSelection() {
    emit(state.copyWith(selectedSite: null));
  }

  void setFeaturedSite(SiteModel site) {
    emit(state.copyWith(featuredSite: site));
  }
}

class ExploreState {
  const ExploreState({
    this.isMapView = false,
    this.itinerary = const [],
    this.selectedSite,
    this.featuredSite,
  });
  final bool isMapView;
  final List<String> itinerary;
  final SiteModel? selectedSite;
  final SiteModel? featuredSite;

  ExploreState copyWith({
    bool? isMapView,
    List<String>? itinerary,
    SiteModel? selectedSite,
    SiteModel? featuredSite,
  }) {
    return ExploreState(
      isMapView: isMapView ?? this.isMapView,
      itinerary: itinerary ?? this.itinerary,
      selectedSite: selectedSite ?? this.selectedSite,
      featuredSite: featuredSite ?? this.featuredSite,
    );
  }
}
