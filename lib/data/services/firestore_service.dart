import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/site_model.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Sites Collection
  CollectionReference get _sitesCollection =>
      _firestore.collection(AppConstants.sitesCollection);

  // Users Collection
  CollectionReference get _usersCollection =>
      _firestore.collection(AppConstants.usersCollection);

  Future<List<SiteModel>> getAllSites() async {
    try {
      final snapshot = await _sitesCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return SiteModel.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch sites: $e');
    }
  }

  Future<SiteModel?> getSiteById(String id) async {
    try {
      final doc = await _sitesCollection.doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return SiteModel.fromMap(data);
    } catch (e) {
      throw Exception('Failed to fetch site: $e');
    }
  }

  Future<List<SiteModel>> getSitesByCategory(String category) async {
    try {
      final snapshot = await _sitesCollection
          .where('category', isEqualTo: category)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return SiteModel.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch sites by category: $e');
    }
  }

  Future<List<SiteModel>> searchSites(String query) async {
    try {
      // Firestore's range query is case-sensitive and English-only, so we
      // fetch the whole collection and filter in-memory across all language
      // name fields. For a final-year demo with <100 sites this is fine.
      final snapshot = await _sitesCollection.get();
      final needle = query.trim().toLowerCase();
      if (needle.isEmpty) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return SiteModel.fromMap(data);
        }).toList();
      }
      bool matches(Map<String, dynamic> data, String field) {
        final v = data[field];
        return v is String && v.toLowerCase().contains(needle);
      }

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          })
          .where((data) =>
              matches(data, 'name_en') ||
              matches(data, 'name_sw') ||
              matches(data, 'name_fr') ||
              matches(data, 'name_de') ||
              matches(data, 'name_ar') ||
              matches(data, 'name_it') ||
              matches(data, 'name_es') ||
              matches(data, 'address'))
          .map((data) => SiteModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to search sites: $e');
    }
  }

  Future<void> addSite(SiteModel site) async {
    try {
      await _sitesCollection.add(site.toMap()..remove('id'));
    } catch (e) {
      throw Exception('Failed to add site: $e');
    }
  }

  Future<void> updateSite(String id, SiteModel site) async {
    try {
      await _sitesCollection.doc(id).update(site.toMap()..remove('id'));
    } catch (e) {
      throw Exception('Failed to update site: $e');
    }
  }

  Future<void> deleteSite(String id) async {
    try {
      await _sitesCollection.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete site: $e');
    }
  }

  /// Translate site content for a specific language
  /// (Removed: admins now provide translations directly via the add/edit form.)

  Stream<List<SiteModel>> watchSites() {
    return _sitesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return SiteModel.fromMap(data);
      }).toList();
    });
  }

  // ==================== USER MANAGEMENT ====================

  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _usersCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserModel.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  Future<UserModel?> getUserById(String id) async {
    try {
      final doc = await _usersCollection.doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return UserModel.fromMap(data);
    } catch (e) {
      throw Exception('Failed to fetch user: $e');
    }
  }

  Future<void> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.id).set(user.toMap()..remove('id'));
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      await _usersCollection.doc(userId).update({'role': role.name});
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  Future<void> updateUserStatus(String userId, bool isDisabled) async {
    try {
      await _usersCollection.doc(userId).update({'disabled': isDisabled});
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _usersCollection.doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  Stream<List<UserModel>> watchUsers() {
    return _usersCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserModel.fromMap(data);
      }).toList();
    });
  }

  Future<int> getUserCount() async {
    try {
      final snapshot = await _usersCollection.get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getPremiumUserCount() async {
    try {
      final snapshot = await _usersCollection
          .where('role', isEqualTo: 'premium')
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }
}