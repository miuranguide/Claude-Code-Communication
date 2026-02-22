import 'dart:math';

String generateId([String prefix = '']) {
  final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  final id = List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  return prefix.isEmpty ? id : '${prefix}_$id';
}

String generateToken() {
  final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
}
