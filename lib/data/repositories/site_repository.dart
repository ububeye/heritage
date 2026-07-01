import '../models/site_model.dart';
import '../services/firestore_service.dart';

class SiteRepository {

  SiteRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();
  final FirestoreService _firestoreService;

  Future<List<SiteModel>> getAllSites() => _firestoreService.getAllSites();

  Future<SiteModel?> getSiteById(String id) => _firestoreService.getSiteById(id);

  Future<List<SiteModel>> getSitesByCategory(String category) =>
      _firestoreService.getSitesByCategory(category);

  Future<List<SiteModel>> searchSites(String query) =>
      _firestoreService.searchSites(query);

  Future<void> addSite(SiteModel site) => _firestoreService.addSite(site);

  Future<void> updateSite(String id, SiteModel site) =>
      _firestoreService.updateSite(id, site);

  Future<void> deleteSite(String id) => _firestoreService.deleteSite(id);

  Stream<List<SiteModel>> watchSites() => _firestoreService.watchSites();
}