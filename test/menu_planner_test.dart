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

  const nonVegNames = ['Chicken', 'Fish', 'Eggs'];
  bool hasNonVeg(Meal m) => m.ingredients.any(nonVegNames.contains);
  final year = [for (var i = 0; i < 365; i++) DateTime(2026, 1, 1).add(Duration(days: i))];

  test('all 12 vegetarian lunches and dinners are used on veg days', () {
    final lunchesUsed = <String>{}, dinnersUsed = <String>{};
    for (final date in year.where(MenuPlanner.isStrictVeg)) {
      final menu = MenuPlanner.forDate(date);
      lunchesUsed.add(menu.lunch.en);
      dinnersUsed.add(menu.dinner.en);
    }
    expect(lunchesUsed.length, 12);
    expect(dinnersUsed.length, 12);
  });

  test('every breakfast is served on every weekday over a year', () {
    for (var weekday = 1; weekday <= 7; weekday++) {
      final used = {for (final d in year.where((d) => d.weekday == weekday)) MenuPlanner.forDate(d).breakfast.en};
      expect(used.length, breakfasts.length, reason: 'weekday $weekday');
    }
  });

  test('no lunch repeats within any 7 consecutive days', () {
    for (var i = 0; i + 7 <= year.length; i++) {
      final week = year.sublist(i, i + 7).map((d) => MenuPlanner.forDate(d).lunch.en).toList();
      expect(week.toSet().length, week.length, reason: 'window starting ${year[i]}');
    }
  });

  test('non-vegetarian meals are occasional, never on veg days, never at both lunch and dinner', () {
    var nonVegMeals = 0;
    for (final date in year) {
      final menu = MenuPlanner.forDate(date);
      final lunchNv = hasNonVeg(menu.lunch), dinnerNv = hasNonVeg(menu.dinner);
      expect(hasNonVeg(menu.breakfast), isFalse, reason: 'Breakfast on $date');
      expect(lunchNv && dinnerNv, isFalse, reason: 'Both meals non-veg on $date');
      if (MenuPlanner.isStrictVeg(date)) expect(lunchNv || dinnerNv, isFalse, reason: 'Non-veg on veg day $date');
      nonVegMeals += (lunchNv ? 1 : 0) + (dinnerNv ? 1 : 0);
    }
    expect(nonVegMeals, lessThanOrEqualTo(120));
  });

  test('every ingredient in every meal has a grocery quantity estimate', () {
    final allMeals = [...breakfasts, ...lunches, ...dinners, ...snacks, for (final f in festivalMenus) ...f.meals];
    for (final meal in allMeals) {
      for (final item in meal.ingredients) {
        expect(groceryEstimate(item, 1), isNot(contains('small quantity')), reason: '$item in ${meal.en}');
      }
    }
  });

  test('every regular meal and snack has its own English and Marathi cooking steps', () {
    for (final meal in [...breakfasts, ...lunches, ...dinners, ...snacks]) {
      expect(recipeSteps(meal, false).first, isNot('Wash and measure all ingredients.'), reason: 'EN steps: ${meal.en}');
      expect(recipeSteps(meal, true).first, isNot(startsWith('सर्व साहित्य स्वच्छ')), reason: 'MR steps: ${meal.en}');
    }
  });
}
