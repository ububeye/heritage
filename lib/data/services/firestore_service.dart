import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/site_model.dart';
import '../models/user_model.dart';
import '../models/activity_model.dart';
import '../../core/constants/app_constants.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  // Sites Collection
  CollectionReference get _sitesCollection =>
      _firestore.collection(AppConstants.sitesCollection);

  // Users Collection
  CollectionReference get _usersCollection =>
      _firestore.collection(AppConstants.usersCollection);

  // Roles Collection — canonical role store. Each user has at most one
  // document at roles/{uid} with `{ role: 'free' | 'premium' | 'admin',
  // updated_at }`. Only admins can write; users and admins can read.
  CollectionReference get _rolesCollection =>
      _firestore.collection(AppConstants.rolesCollection);

  // Activities Collection
  CollectionReference get _activitiesCollection =>
      _firestore.collection(AppConstants.activitiesCollection);

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
      final snapshot =
          await _sitesCollection.where('category', isEqualTo: category).get();
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
          .where(
            (data) =>
                matches(data, 'name_en') ||
                matches(data, 'name_sw') ||
                matches(data, 'name_fr') ||
                matches(data, 'name_de') ||
                matches(data, 'name_ar') ||
                matches(data, 'name_it') ||
                matches(data, 'name_es') ||
                matches(data, 'address'),
          )
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
      // Role lives in roles/{uid}, not on the user profile. Strip it here so
      // a future code change can't accidentally re-introduce role into
      // users/{uid} and bypass the roles collection.
      await _usersCollection
          .doc(user.id)
          .set((user.toMap()..remove('role'))..remove('id'));
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> setUserDisabled(String uid, bool disabled) async {
    try {
      await _usersCollection.doc(uid).update({'disabled': disabled});
    } catch (e) {
      throw Exception('Failed to update disabled status: $e');
    }
  }

  Future<void> setUserSubscriptionExpiry(String uid, DateTime? expiry) async {
    try {
      await _usersCollection.doc(uid).update({
        'subscription_expiry': expiry?.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update subscription expiry: $e');
    }
  }

  /// Read the user's role from roles/{uid}. Returns null if no document
  /// exists (e.g. a brand-new user who hasn't been promoted yet).
  Future<UserRole?> getUserRole(String uid) async {
    try {
      final doc = await _rolesCollection.doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>?;
      return _parseRoleString(data?['role'] as String?);
    } catch (_) {
      return null;
    }
  }

  /// Write roles/{uid} with the authoritative role. Only admins should
  /// reach this path (see firestore.rules); non-admin writes will be
  /// rejected by the security rules.
  Future<void> setUserRole(String uid, UserRole role) async {
    try {
      await _rolesCollection.doc(uid).set({
        'role': role.name,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to set user role: $e');
    }
  }

  /// Backwards-compatible shim — preserves the updateUserRole() call site
  /// at lib/blocs/user/user_cubit.dart:34 while the implementation routes
  /// through the new roles collection.
  Future<void> updateUserRole(String userId, UserRole role) =>
      setUserRole(userId, role);

  /// Bulk-fetch roles for the admin User Management table. Returns a
  /// uid -> UserRole map; users without a roles/{uid} doc are absent from
  /// the map (callers fall back to the value already on users/{uid}).
  Future<Map<String, UserRole>> bulkGetRoles(Iterable<String> uids) async {
    final ids = uids.toList();
    if (ids.isEmpty) return {};
    try {
      final snaps = await Future.wait(
        ids.map((id) => _rolesCollection.doc(id).get()),
      );
      final out = <String, UserRole>{};
      for (var i = 0; i < ids.length; i++) {
        if (!snaps[i].exists) continue;
        final data = snaps[i].data() as Map<String, dynamic>?;
        out[ids[i]] = _parseRoleString(data?['role'] as String?);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// Local mirror of UserModel._parseRole — kept private so we don't widen
  /// the model's API surface.
  static UserRole _parseRoleString(String? role) {
    switch (role) {
      case 'premium':
        return UserRole.premium;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.free;
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
    // Best-effort role cleanup; missing doc is not an error.
    try {
      await _rolesCollection.doc(userId).delete();
    } catch (_) {}
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
      // Roles live in the roles collection, not on the user profile.
      final snapshot =
          await _rolesCollection.where('role', isEqualTo: 'premium').get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  // --- Activities ---

  Future<void> logActivity(ActivityModel activity) async {
    try {
      await _activitiesCollection.add(activity.toMap());
    } catch (e) {
      // Activity logging is strictly fire-and-forget; don't bring down
      // the caller if it fails.
      debugPrint('Failed to log activity: $e');
    }
  }

  Future<List<ActivityModel>> getRecentActivities({int limit = 10}) async {
    try {
      final snapshot = await _activitiesCollection
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ActivityModel.fromMap(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Failed to fetch recent activities: $e');
      return [];
    }
  }

}
