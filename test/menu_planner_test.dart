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

  test('every date in the year has three complete meals', () {
    for (var offset = 0; offset < 365; offset++) {
      final date = DateTime(2026, 1, 1).add(Duration(days: offset));
      final menu = MenuPlanner.forDate(date);
      expect(menu.meals.length, 3, reason: 'Date: $date');
      for (final meal in menu.meals) {
        expect(meal.en.trim(), isNotEmpty, reason: 'Date: $date');
        expect(meal.ingredients, isNotEmpty, reason: 'Meal: ${meal.en}');
        expect(meal.prep.trim(), isNotEmpty, reason: 'Meal: ${meal.en}');
      }
      if (MenuPlanner.isStrictVeg(date)) {
        for (final meal in menu.meals) {
          expect(
            meal.ingredients.any((x) => ['Chicken', 'Fish', 'Eggs'].contains(x)),
            isFalse,
            reason: 'Non-vegetarian ingredient on $date in ${meal.en}',
          );
        }
      }
    }
  });

  test('grocery estimate combines numeric quantities used in multiple meals', () {
    expect(groceryEstimate('Poha', 2), '600 g (combined for 2 meals)');
    expect(groceryEstimate('Cucumber', 3), '6 medium (combined for 3 meals)');
  });

  test('unknown grocery quantities are clearly marked as estimates', () {
    expect(groceryEstimate('Saffron', 2), contains('adjust to taste'));
  });
}
