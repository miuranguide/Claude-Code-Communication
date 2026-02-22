import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared/shared.dart';

class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _loadCached();
  }

  Box<dynamic>? _box;

  Future<Box<dynamic>> _getBox() async {
    _box ??= await Hive.openBox('auth');
    return _box!;
  }

  Future<void> _loadCached() async {
    try {
      final box = await _getBox();
      final raw = box.get('user') as String?;
      if (raw != null) {
        final user = AppUser.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        if (user.isActive && user.isActivated) {
          state = state.copyWith(user: user);
        }
      }
    } catch (e) {
      debugPrint('Auth load error: $e');
    }
  }

  Future<bool> login(String loginId, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final email = '$loginId@rakugaki.app';
      final credential = await fb.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = credential.user?.uid;
      if (uid == null) {
        state = state.copyWith(
          isLoading: false,
          error: '認証に失敗しました',
        );
        return false;
      }

      final user = await FirestoreService.instance.getUser(uid);
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'ユーザー情報が見つかりません',
        );
        return false;
      }

      if (!user.isActive) {
        await fb.FirebaseAuth.instance.signOut();
        state = state.copyWith(
          isLoading: false,
          error: 'アカウントが無効化されています',
        );
        return false;
      }

      if (!user.isActivated) {
        await fb.FirebaseAuth.instance.signOut();
        state = state.copyWith(
          isLoading: false,
          error: '交付日前のためログインできません',
        );
        return false;
      }

      await setUser(user);
      state = state.copyWith(isLoading: false);

      FirestoreService.instance.writeLog(
        action: 'login',
        actorUid: uid,
        detail: 'Remote app login',
      );

      return true;
    } on fb.FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'ログインIDが見つかりません';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'パスワードが正しくありません';
          break;
        case 'user-disabled':
          msg = 'アカウントが無効化されています';
          break;
        case 'too-many-requests':
          msg = 'ログイン試行回数が多すぎます。しばらく待ってください';
          break;
        default:
          msg = 'ログインエラー: ${e.message}';
      }
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'ログインに失敗しました: $e',
      );
      return false;
    }
  }

  Future<void> setUser(AppUser user) async {
    state = state.copyWith(user: user, clearError: true);
    final box = await _getBox();
    await box.put('user', jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    try {
      final uid = state.user?.uid;
      await fb.FirebaseAuth.instance.signOut();
      if (uid != null) {
        FirestoreService.instance.writeLog(
          action: 'logout',
          actorUid: uid,
          detail: 'Remote app logout',
        );
      }
    } catch (_) {}
    state = state.copyWith(clearUser: true, clearError: true);
    final box = await _getBox();
    await box.delete('user');
  }

  Future<String?> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      if (fbUser == null || fbUser.email == null) {
        return 'ログインしていません';
      }

      final credential = fb.EmailAuthProvider.credential(
        email: fbUser.email!,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(credential);
      await fbUser.updatePassword(newPassword);

      FirestoreService.instance.writeLog(
        action: 'password_change',
        actorUid: fbUser.uid,
        detail: 'Remote app password change',
      );

      return null; // success
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return '現在のパスワードが正しくありません';
        case 'weak-password':
          return '新しいパスワードが短すぎます（6文字以上）';
        default:
          return 'エラー: ${e.message}';
      }
    } catch (e) {
      return 'エラー: $e';
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
