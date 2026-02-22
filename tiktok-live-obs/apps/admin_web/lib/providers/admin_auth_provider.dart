import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared/shared.dart';

class AdminAuthState {
  final AppUser? user;
  final bool isLoading;
  final String? error;

  const AdminAuthState({this.user, this.isLoading = false, this.error});

  bool get isLoggedIn => user != null && user!.role == 'admin';

  AdminAuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AdminAuthState(
        user: clearUser ? null : (user ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  AdminAuthNotifier() : super(const AdminAuthState()) {
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    if (fbUser == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final user = await FirestoreService.instance.getUser(fbUser.uid);
      if (user != null && user.role == 'admin') {
        state = state.copyWith(user: user, isLoading: false);
      } else {
        await fb.FirebaseAuth.instance.signOut();
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      debugPrint('Admin auth check error: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final credential = await fb.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = credential.user?.uid;
      if (uid == null) {
        state = state.copyWith(isLoading: false, error: '認証に失敗しました');
        return false;
      }

      final user = await FirestoreService.instance.getUser(uid);
      if (user == null || user.role != 'admin') {
        await fb.FirebaseAuth.instance.signOut();
        state = state.copyWith(
          isLoading: false,
          error: '管理者権限がありません',
        );
        return false;
      }

      state = state.copyWith(user: user, isLoading: false);

      FirestoreService.instance.writeLog(
        action: 'admin_login',
        actorUid: uid,
        detail: 'Admin web login',
      );

      return true;
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'ログインエラー: ${e.message}',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'ログインに失敗しました: $e',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final uid = state.user?.uid;
      await fb.FirebaseAuth.instance.signOut();
      if (uid != null) {
        FirestoreService.instance.writeLog(
          action: 'admin_logout',
          actorUid: uid,
        );
      }
    } catch (_) {}
    state = state.copyWith(clearUser: true);
  }
}

final adminAuthProvider =
    StateNotifierProvider<AdminAuthNotifier, AdminAuthState>((ref) {
  return AdminAuthNotifier();
});
