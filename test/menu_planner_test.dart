import 'package:flutter_test/flutter_test.dart';
import 'package:home_food_menu/main.dart';

void main() {
  test('Monday, Thursday and Saturday are strict vegetarian days', () {
    expect(MenuPlanner.isStrictVeg(DateTime(2026, 11, 23)), isTrue);
    expect(MenuPlanner.isStrictVeg(DateTime(2026, 11, 26)), isTrue);
    expect(MenuPlanner.isStrictVeg(DateTime(2026, 11, 28)), isTrue);
    expect(MenuPlanner.isStrictVeg(DateTime(2026, 11, 24)), isFalse);
  });
  test('strict vegetarian menus exclude meat, fish and eggs', () {
    for (final date in [DateTime(2026, 11, 23), DateTime(2026, 11, 26), DateTime(2026, 11, 28)]) {
      final menu = MenuPlanner.forDate(date);
      expect(menu.strictVeg, isTrue);
      for (final meal in menu.meals) {
        expect(meal.ingredients.any((x) => ['Chicken', 'Fish', 'Eggs'].contains(x)), isFalse);
      }
    }
  });
}
