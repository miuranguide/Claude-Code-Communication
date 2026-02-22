import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared/shared.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_data_providers.dart';
import '../widgets/admin_scaffold.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersStreamProvider);

    return AdminScaffold(
      title: 'ユーザー管理',
      selectedIndex: 1,
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showBulkImportDialog(context),
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('CSV一括登録'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25F4EE),
            foregroundColor: Colors.black,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _showAddUserDialog(context),
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('ユーザー発行'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFE2C55),
            foregroundColor: Colors.white,
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'ユーザー検索...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF161823),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161823),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 150, child: Text('ログインID',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 150, child: Text('表示名',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 100, child: Text('グループ',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 80, child: Text('ロール',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 80, child: Text('状態',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 120, child: Text('交付日',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Spacer(),
                          Text('操作',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: usersAsync.when(
                        data: (users) {
                          final filtered = _searchQuery.isEmpty
                              ? users
                              : users.where((u) =>
                                  u.loginId.contains(_searchQuery) ||
                                  u.displayName.contains(_searchQuery) ||
                                  (u.group ?? '').contains(_searchQuery)).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text('ユーザーはいません',
                                  style: TextStyle(color: Colors.white38)),
                            );
                          }

                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final user = filtered[index];
                              return _userRow(user);
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: Text('エラー: $e',
                              style: const TextStyle(color: Colors.red)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userRow(AppUser user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(user.loginId,
              style: const TextStyle(fontSize: 13))),
          SizedBox(width: 150, child: Text(user.displayName,
              style: const TextStyle(fontSize: 13))),
          SizedBox(width: 100, child: Text(user.group ?? '-',
              style: const TextStyle(fontSize: 13, color: Colors.white54))),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: user.role == 'admin'
                    ? const Color(0xFFFE2C55).withAlpha(50)
                    : Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                user.role == 'admin' ? '管理者' : 'メンバー',
                style: TextStyle(
                  fontSize: 11,
                  color: user.role == 'admin'
                      ? const Color(0xFFFE2C55)
                      : Colors.white54,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: user.isActive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(user.isActive ? '有効' : '無効',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              user.activationDate != null
                  ? '${user.activationDate!.year}/${user.activationDate!.month}/${user.activationDate!.day}'
                  : '即時',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'resetPassword',
                child: Row(
                  children: [
                    Icon(Icons.lock_reset, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('パスワードリセット'),
                  ],
                ),
              ),
              if (user.isActive)
                const PopupMenuItem(value: 'deactivate', child: Text('無効化'))
              else
                const PopupMenuItem(value: 'activate', child: Text('有効化')),
            ],
            onSelected: (action) async {
              if (action == 'resetPassword') {
                _confirmResetPassword(user);
              } else if (action == 'deactivate') {
                await FirestoreService.instance.deactivateUser(user.uid);
                final admin = ref.read(adminAuthProvider).user;
                if (admin != null) {
                  FirestoreService.instance.writeLog(
                    action: 'user_deactivate',
                    actorUid: admin.uid,
                    detail: 'Deactivated user: ${user.loginId}',
                  );
                }
              } else if (action == 'activate') {
                await FirestoreService.instance.activateUser(user.uid);
                final admin = ref.read(adminAuthProvider).user;
                if (admin != null) {
                  FirestoreService.instance.writeLog(
                    action: 'user_activate',
                    actorUid: admin.uid,
                    detail: 'Activated user: ${user.loginId}',
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmResetPassword(AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('パスワードリセット'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「${user.displayName}」(${user.loginId}) のパスワードを初期パスワードにリセットしますか？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha(60)),
              ),
              child: Text(
                'リセット後のパスワード: ${user.loginId}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _resetPassword(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('リセット'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(AppUser user) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('resetPassword');
      await callable.call({
        'uid': user.uid,
        'loginId': user.loginId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${user.displayName}」のパスワードをリセットしました（新パスワード: ${user.loginId}）'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('リセット失敗: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddUserDialog(BuildContext context) {
    final loginIdCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();
    final groupCtrl = TextEditingController();
    bool immediate = true;
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('ユーザー発行'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: loginIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ログインID *',
                    hintText: 'rakugaki_user01',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayNameCtrl,
                  decoration: const InputDecoration(
                    labelText: '表示名 *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: groupCtrl,
                  decoration: const InputDecoration(
                    labelText: 'グループ（任意）',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('交付方式',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('即時交付', style: TextStyle(fontSize: 13)),
                        value: true,
                        groupValue: immediate,
                        onChanged: (v) =>
                            setDialogState(() => immediate = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('15日後交付', style: TextStyle(fontSize: 13)),
                        value: false,
                        groupValue: immediate,
                        onChanged: (v) =>
                            setDialogState(() => immediate = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final loginId = loginIdCtrl.text.trim();
                      final displayName = displayNameCtrl.text.trim();
                      if (loginId.isEmpty || displayName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ログインIDと表示名は必須です')),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);

                      try {
                        // Create Firebase Auth user via secondary app
                        // to avoid signing out the admin
                        final email = '$loginId@rakugaki.app';
                        final secondaryApp = await Firebase.initializeApp(
                          name: 'userCreation_${DateTime.now().millisecondsSinceEpoch}',
                          options: Firebase.app().options,
                        );
                        String uid;
                        try {
                          final secondaryAuth =
                              fb.FirebaseAuth.instanceFor(app: secondaryApp);
                          final credential = await secondaryAuth
                              .createUserWithEmailAndPassword(
                            email: email,
                            password: loginId,
                          );
                          uid = credential.user!.uid;
                          await secondaryAuth.signOut();
                        } finally {
                          await secondaryApp.delete();
                        }

                        // Determine activation date
                        DateTime? activationDate;
                        if (!immediate) {
                          activationDate =
                              DateTime.now().add(const Duration(days: 15));
                        }

                        // Create Firestore user document
                        final user = AppUser(
                          uid: uid,
                          loginId: loginId,
                          displayName: displayName,
                          group: groupCtrl.text.trim().isNotEmpty
                              ? groupCtrl.text.trim()
                              : null,
                          isActive: true,
                          activationDate: activationDate,
                          createdAt: DateTime.now(),
                        );

                        await FirestoreService.instance.setUser(user);

                        // Log the action
                        final admin = ref.read(adminAuthProvider).user;
                        if (admin != null) {
                          FirestoreService.instance.writeLog(
                            action: 'user_create',
                            actorUid: admin.uid,
                            detail:
                                'Created user: $loginId (${immediate ? "即時" : "15日後"}交付)',
                          );
                        }

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'ユーザー「$displayName」を発行しました（初期パスワード: $loginId）')),
                          );
                        }
                      } on fb.FirebaseAuthException catch (e) {
                        setDialogState(() => isCreating = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エラー: ${e.message}')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isCreating = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エラー: $e')),
                          );
                        }
                      }

                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55),
                foregroundColor: Colors.white,
              ),
              child: isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('発行'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkImportDialog(BuildContext context) {
    final csvCtrl = TextEditingController();
    bool isImporting = false;
    int successCount = 0;
    int errorCount = 0;
    int totalCount = 0;
    int processedCount = 0;
    String statusMessage = '';
    List<String> errorMessages = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: Color(0xFF25F4EE)),
              SizedBox(width: 8),
              Text('CSV一括登録'),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25F4EE).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF25F4EE).withAlpha(60)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CSV形式（1行につき1ユーザー）',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: 4),
                      Text('ログインID,表示名,グループ',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white70)),
                      SizedBox(height: 4),
                      Text('例:',
                          style: TextStyle(fontSize: 11, color: Colors.white38)),
                      Text('creator001,田中太郎,チームA\ncreator002,佐藤花子,チームA\ncreator003,鈴木一郎,チームB',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white54)),
                      SizedBox(height: 6),
                      Text('※ グループは省略可。初期パスワードはログインIDと同じです。',
                          style: TextStyle(fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: csvCtrl,
                    maxLines: null,
                    expands: true,
                    enabled: !isImporting,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'CSVデータを貼り付けてください...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF0D0D0D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (isImporting || statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  if (isImporting)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: totalCount > 0 ? processedCount / totalCount : null,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF25F4EE)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '処理中... $processedCount / $totalCount （成功: $successCount, エラー: $errorCount）',
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  if (!isImporting && statusMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: errorCount > 0
                            ? Colors.orange.withAlpha(20)
                            : Colors.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(statusMessage,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: errorCount > 0 ? Colors.orange : Colors.green)),
                          if (errorMessages.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 80,
                              child: ListView(
                                children: errorMessages
                                    .map((e) => Text(e,
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.red)))
                                    .toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isImporting ? null : () => Navigator.pop(ctx),
              child: Text(statusMessage.isNotEmpty ? '閉じる' : 'キャンセル'),
            ),
            if (statusMessage.isEmpty)
              ElevatedButton(
                onPressed: isImporting
                    ? null
                    : () async {
                        final csv = csvCtrl.text.trim();
                        if (csv.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('CSVデータを入力してください')),
                          );
                          return;
                        }

                        // Parse CSV lines
                        final lines = csv
                            .split('\n')
                            .map((l) => l.trim())
                            .where((l) => l.isNotEmpty)
                            .toList();

                        // Skip header row if it looks like a header
                        final firstLine = lines.first.toLowerCase();
                        if (firstLine.contains('loginid') ||
                            firstLine.contains('ログインid') ||
                            firstLine.contains('login_id')) {
                          lines.removeAt(0);
                        }

                        if (lines.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('有効なデータ行がありません')),
                          );
                          return;
                        }

                        setDialogState(() {
                          isImporting = true;
                          totalCount = lines.length;
                          processedCount = 0;
                          successCount = 0;
                          errorCount = 0;
                          errorMessages = [];
                        });

                        final admin = ref.read(adminAuthProvider).user;

                        for (final line in lines) {
                          final parts = line.split(',').map((p) => p.trim()).toList();
                          if (parts.isEmpty || parts[0].isEmpty) {
                            setDialogState(() {
                              processedCount++;
                              errorCount++;
                              errorMessages.add('行 ${processedCount}: 空のログインID');
                            });
                            continue;
                          }

                          final loginId = parts[0];
                          final displayName = parts.length > 1 && parts[1].isNotEmpty
                              ? parts[1]
                              : loginId;
                          final group = parts.length > 2 && parts[2].isNotEmpty
                              ? parts[2]
                              : null;

                          try {
                            final email = '$loginId@rakugaki.app';
                            final secondaryApp = await Firebase.initializeApp(
                              name: 'bulk_${DateTime.now().millisecondsSinceEpoch}_$processedCount',
                              options: Firebase.app().options,
                            );
                            String uid;
                            try {
                              final secondaryAuth =
                                  fb.FirebaseAuth.instanceFor(app: secondaryApp);
                              final credential = await secondaryAuth
                                  .createUserWithEmailAndPassword(
                                email: email,
                                password: loginId,
                              );
                              uid = credential.user!.uid;
                              await secondaryAuth.signOut();
                            } finally {
                              await secondaryApp.delete();
                            }
                            final user = AppUser(
                              uid: uid,
                              loginId: loginId,
                              displayName: displayName,
                              group: group,
                              isActive: true,
                              createdAt: DateTime.now(),
                            );

                            await FirestoreService.instance.setUser(user);

                            setDialogState(() {
                              processedCount++;
                              successCount++;
                            });
                          } on fb.FirebaseAuthException catch (e) {
                            String errMsg;
                            switch (e.code) {
                              case 'email-already-in-use':
                                errMsg = '既に登録済み';
                                break;
                              case 'invalid-email':
                                errMsg = '無効なメールアドレス';
                                break;
                              case 'weak-password':
                                errMsg = 'パスワードが弱すぎます';
                                break;
                              default:
                                errMsg = e.message ?? e.code;
                            }
                            setDialogState(() {
                              processedCount++;
                              errorCount++;
                              errorMessages.add('$loginId: $errMsg');
                            });
                          } catch (e) {
                            setDialogState(() {
                              processedCount++;
                              errorCount++;
                              errorMessages.add('$loginId: $e');
                            });
                          }
                        }

                        // Log bulk import
                        if (admin != null) {
                          FirestoreService.instance.writeLog(
                            action: 'bulk_user_create',
                            actorUid: admin.uid,
                            detail:
                                'CSV一括登録: ${successCount}件成功, ${errorCount}件エラー (合計${totalCount}件)',
                          );
                        }

                        setDialogState(() {
                          isImporting = false;
                          statusMessage =
                              '完了: ${successCount}件成功, ${errorCount}件エラー (合計${totalCount}件)';
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25F4EE),
                  foregroundColor: Colors.black,
                ),
                child: isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('一括登録開始'),
              ),
          ],
        ),
      ),
    );
  }
}
