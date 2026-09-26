import 'package:flutter_test/flutter_test.dart';
import 'package:neon_flow/core/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each difficulty is open at its first level, then sequential', () async {
    SharedPreferences.setMockInitialValues({});
    final p = ProgressStore();
    await p.load();
    p.difficultyStarts = {1, 51, 101};

    // Fresh install: first level of every difficulty is open, nothing else.
    expect(p.isUnlocked(1), isTrue);
    expect(p.isUnlocked(51), isTrue);
    expect(p.isUnlocked(101), isTrue);
    expect(p.isUnlocked(2), isFalse);
    expect(p.isUnlocked(52), isFalse);
    expect(p.isUnlocked(102), isFalse);

    // Completing a hard level opens only the next hard level.
    await p.recordWin(101, 3, 20);
    expect(p.isUnlocked(102), isTrue);
    expect(p.isUnlocked(103), isFalse);
    expect(p.isUnlocked(2), isFalse);

    expect(p.currentIn(101, 150), 102);
    expect(p.continueLevel(150), 102);
  });
}
