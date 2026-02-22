/// Firebase Admin User Setup Script
///
/// Run this after configuring Firebase to create the initial admin account.
/// Usage: dart run scripts/create_admin.dart
///
/// Prerequisites:
///   1. Firebase project created at console.firebase.google.com
///   2. Authentication > Email/Password enabled
///   3. Create user in Firebase Console > Authentication:
///      Email: admin@rakugaki.app
///      Password: (your choice)
///   4. Copy the UID from the Authentication console
///   5. Add admin document to Firestore manually:
///
/// Firestore > users > {UID from step 4}:
/// {
///   "uid": "{same UID}",
///   "loginId": "admin",
///   "displayName": "管理者",
///   "role": "admin",
///   "isActive": true,
///   "createdAt": "2026-02-21T00:00:00.000Z"
/// }
///
/// Then for regular users, create them via the admin web panel:
///   1. Admin creates user in Users screen
///   2. System generates loginId@rakugaki.app email in Firebase Auth
///   3. Initial password is set to loginId (user should change)

void main() {
  print('''
╔══════════════════════════════════════════════════════════════╗
║           ラクガキ企画 Firebase セットアップ手順              ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  1. Firebase Console (console.firebase.google.com)           ║
║     → 新しいプロジェクト作成: "rakugaki-kikaku"               ║
║                                                              ║
║  2. Authentication → Sign-in method                          ║
║     → Email/Password を有効化                                ║
║                                                              ║
║  3. Authentication → Users → ユーザー追加                     ║
║     Email: admin@rakugaki.app                                ║
║     Password: (任意のパスワード)                              ║
║     → 作成後、UIDをコピー                                     ║
║                                                              ║
║  4. Firestore Database → コレクション作成                     ║
║     コレクション: users                                       ║
║     ドキュメントID: (↑のUID)                                  ║
║     フィールド:                                               ║
║       uid: string = (同じUID)                                ║
║       loginId: string = "admin"                              ║
║       displayName: string = "管理者"                          ║
║       role: string = "admin"                                 ║
║       isActive: boolean = true                               ║
║       createdAt: string = "2026-02-21T00:00:00.000Z"        ║
║                                                              ║
║  5. FlutterFire CLI設定                                      ║
║     npm install -g firebase-tools                            ║
║     firebase login                                           ║
║     dart pub global activate flutterfire_cli                 ║
║     cd apps/broadcaster && flutterfire configure             ║
║     cd apps/remote && flutterfire configure                  ║
║     cd apps/admin_web && flutterfire configure               ║
║                                                              ║
║  6. Firestore ルールのデプロイ                                ║
║     firebase deploy --only firestore:rules                   ║
║                                                              ║
║  7. Admin Web のデプロイ                                     ║
║     cd apps/admin_web && flutter build web                   ║
║     firebase deploy --only hosting                           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
  ''');
}
