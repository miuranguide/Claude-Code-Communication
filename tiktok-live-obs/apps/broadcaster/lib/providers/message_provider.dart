import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared/shared.dart';

import 'auth_provider.dart';

class MessageState {
  final AppMessage? latestMessage;
  final List<AppMessage> messages;
  final Set<String> readIds;

  const MessageState({
    this.latestMessage,
    this.messages = const [],
    this.readIds = const {},
  });

  int get unreadCount =>
      messages.where((m) => !readIds.contains(m.id)).length;

  MessageState copyWith({
    AppMessage? latestMessage,
    List<AppMessage>? messages,
    Set<String>? readIds,
  }) =>
      MessageState(
        latestMessage: latestMessage ?? this.latestMessage,
        messages: messages ?? this.messages,
        readIds: readIds ?? this.readIds,
      );
}

class MessageNotifier extends StateNotifier<MessageState> {
  MessageNotifier(this._ref) : super(const MessageState()) {
    _loadCached();
    _listenToAuth();
  }

  final Ref _ref;
  Box<dynamic>? _box;
  StreamSubscription<List<AppMessage>>? _firestoreSub;

  Future<Box<dynamic>> _getBox() async {
    _box ??= await Hive.openBox('messages');
    return _box!;
  }

  void _listenToAuth() {
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isLoggedIn && !(prev?.isLoggedIn ?? false)) {
        _startFirestoreListener(next.user!);
      } else if (!next.isLoggedIn && (prev?.isLoggedIn ?? false)) {
        _stopFirestoreListener();
      }
    });

    // Also start if already logged in
    final auth = _ref.read(authProvider);
    if (auth.isLoggedIn) {
      _startFirestoreListener(auth.user!);
    }
  }

  void _startFirestoreListener(AppUser user) {
    _stopFirestoreListener();
    _firestoreSub = FirestoreService.instance
        .watchMessagesForUser(
          uid: user.uid,
          group: user.group,
          role: user.role,
        )
        .listen(
      (messages) {
        if (messages.isEmpty) return;

        // Find latest (urgent takes priority)
        final urgent = messages.where((m) => m.isUrgent).toList();
        final latest = urgent.isNotEmpty ? urgent.first : messages.first;

        state = state.copyWith(
          latestMessage: latest,
          messages: messages,
        );
        _saveCached();
      },
      onError: (e) {
        debugPrint('Firestore message listen error: $e');
      },
    );
  }

  void _stopFirestoreListener() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
  }

  Future<void> _loadCached() async {
    try {
      final box = await _getBox();
      final raw = box.get('latest') as String?;
      final readRaw = box.get('readIds', defaultValue: '[]') as String;
      final readIds =
          (jsonDecode(readRaw) as List).cast<String>().toSet();

      if (raw != null) {
        final msg = AppMessage.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        state = state.copyWith(
          latestMessage: msg,
          messages: [msg],
          readIds: readIds,
        );
      }
    } catch (e) {
      debugPrint('Message load error: $e');
    }
  }

  Future<void> _saveCached() async {
    final box = await _getBox();
    if (state.latestMessage != null) {
      await box.put(
          'latest', jsonEncode(state.latestMessage!.toJson()));
    }
    await box.put(
        'readIds', jsonEncode(state.readIds.toList()));
  }

  void onNewMessage(AppMessage msg) {
    final urgentCurrent = state.latestMessage?.isUrgent ?? false;
    final shouldReplace = msg.isUrgent || !urgentCurrent;

    state = state.copyWith(
      latestMessage: shouldReplace ? msg : state.latestMessage,
      messages: [msg, ...state.messages].take(50).toList(),
    );
    _saveCached();
  }

  void markRead(String messageId) {
    state = state.copyWith(
      readIds: {...state.readIds, messageId},
    );
    _saveCached();
  }

  void markAllRead() {
    state = state.copyWith(
      readIds: state.messages.map((m) => m.id).toSet(),
    );
    _saveCached();
  }

  @override
  void dispose() {
    _stopFirestoreListener();
    super.dispose();
  }
}

final messageProvider =
    StateNotifierProvider<MessageNotifier, MessageState>((ref) {
  return MessageNotifier(ref);
});
