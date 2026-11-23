import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.init();

  // Show the app immediately. Notification setup must never prevent startup.
  runApp(const HomeFoodApp());

  // Notifications are a secondary feature; an OS/plugin scheduling error
  // should not crash or block the main menu.
  try {
    await ReminderService.init();
  } catch (error, stackTrace) {
    debugPrint('Meal reminder initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class Meal {
  final String en, mr;
  final List<String> ingredients;
  final String prep;
  const Meal(this.en, this.mr, this.ingredients, this.prep);
  String name(bool mrOn) => mrOn ? mr : en;
}
class DayMenu {
  final Meal breakfast, lunch, dinner;
  final bool strictVeg;
  const DayMenu(this.breakfast, this.lunch, this.dinner, this.strictVeg);
  List<Meal> get meals => [breakfast, lunch, dinner];
}

const breakfasts = <Meal>[
  Meal('Poha','पोहे',['Poha','Onion','Potato','Peanuts','Coriander','Lemon'],'Rinse poha; chop onion and potato.'),
  Meal('Upma','उपमा',['Rava','Onion','Carrot','Peas','Curry leaves'],'Chop vegetables; keep rava ready.'),
  Meal('Thalipeeth','थालीपीठ',['Bhajani flour','Onion','Coriander','Green chilli','Curd'],'Chop onion and coriander.'),
  Meal('Idli and chutney','इडली आणि चटणी',['Idli batter','Coconut','Roasted gram','Curry leaves'],'Check batter; prepare chutney ingredients.'),
  Meal('Sabudana khichdi','साबुदाणा खिचडी',['Sabudana','Potato','Peanuts','Cumin','Lemon'],'Soak sabudana for 4–6 hours.'),
  Meal('Besan chilla','बेसन चिल्ला',['Besan','Onion','Tomato','Coriander','Curd'],'Chop vegetables and mix dry spices.'),
  Meal('Dosa','डोसा',['Dosa batter','Potato','Onion','Coconut'],'Check batter and prepare potato masala.'),
  Meal('Vegetable paratha and curd','भाजी पराठा आणि दही',['Wheat flour','Potato','Carrot','Peas','Curd'],'Boil potato; grate vegetables and knead dough.'),
  Meal('Moong dal dosa','मूग डाळ डोसा',['Moong dal','Ginger','Green chilli','Coriander','Curd'],'Soak moong dal for 3–4 hours; drain before grinding.'),
  Meal('Methi thepla','मेथी थेपला',['Wheat flour','Fenugreek leaves','Curd','Sesame seeds','Spices'],'Wash and finely chop methi; keep curd and flour ready.'),
  Meal('Misal pav (mild)','मिसळ पाव',['Matki','Onion','Tomato','Goda masala','Pav'],'Soak matki overnight; prepare usal base and keep pav fresh.'),
  Meal('Vegetable sandwich','भाजी सँडविच',['Bread','Potato','Cucumber','Tomato','Butter'],'Boil potato and slice vegetables; refrigerate covered.'),
  Meal('Appe and coconut chutney','आप्पे आणि खोबऱ्याची चटणी',['Idli batter','Onion','Carrot','Coconut','Curry leaves'],'Check fermented batter; chop vegetables and prepare chutney.'),
  Meal('Ragi porridge and fruit','नाचणी सत्त्व आणि फळे',['Ragi flour','Milk','Banana','Jaggery','Cardamom'],'Measure ragi flour; wash and cut fruit just before serving.')
];
const lunches = <Meal>[
  Meal('Varan-bhaat, bhaji and koshimbir','वरण-भात, भाजी आणि कोशिंबीर',['Toor dal','Rice','Seasonal vegetables','Cucumber','Curd'],'Rinse dal and rice; chop vegetables.'),
  Meal('Pithla-bhakri','पिठलं-भाकरी',['Besan','Jowar flour','Garlic','Onion','Green chilli'],'Measure flour; peel garlic and chop onion.'),
  Meal('Matki usal and rice','मटकी उसळ आणि भात',['Matki','Rice','Onion','Tomato','Goda masala'],'Soak matki overnight for sprouting/softening.'),
  Meal('Paneer masala and chapati','पनीर मसाला आणि चपाती',['Paneer','Tomato','Onion','Wheat flour','Curd'],'Chop onion and tomato; knead dough if preferred.'),
  Meal('Vangi bharit and bhakri','वांग्याचे भरीत आणि भाकरी',['Brinjal','Onion','Jowar flour','Coriander','Green chilli'],'Wash brinjal and prepare bhakri flour.'),
  Meal('Rajma masala and rice','राजमा मसाला आणि भात',['Rajma','Rice','Onion','Tomato','Ginger-garlic'],'Soak rajma overnight; refrigerate after soaking if the room is warm.'),
  Meal('Chole and chapati','छोले आणि चपाती',['Chickpeas','Onion','Tomato','Wheat flour','Chole masala'],'Soak chickpeas overnight; prepare masala ingredients.'),
  Meal('Palak paneer and jeera rice','पालक पनीर आणि जिरा भात',['Spinach','Paneer','Rice','Garlic','Cumin'],'Wash spinach thoroughly; cube paneer and rinse rice.'),
  Meal('Kadhi pakora and rice','कढी पकोडा आणि भात',['Curd','Besan','Onion','Rice','Curry leaves'],'Whisk curd and besan; slice onion and prepare rice.'),
  Meal('Bharli vangi and bhakri','भरली वांगी आणि भाकरी',['Small brinjal','Peanuts','Sesame seeds','Coconut','Jowar flour'],'Wash and slit brinjals; prepare roasted peanut-sesame filling.'),
  Meal('Vegetable thali','मिक्स भाजी थाळी',['Seasonal vegetables','Toor dal','Rice','Wheat flour','Curd'],'Wash and chop vegetables; rinse dal and rice.'),
  Meal('Lemon rice and curd','लिंबू भात आणि दही',['Rice','Lemon','Peanuts','Curry leaves','Curd'],'Cook rice and cool slightly; roast peanuts and prepare tempering.'),
  Meal('Chicken curry, rice and salad','चिकन रस्सा, भात आणि कोशिंबीर',['Chicken','Rice','Onion','Tomato','Ginger-garlic','Spices'],'Clean chicken and marinate; refrigerate promptly.'),
  Meal('Egg curry and chapati','अंडा करी आणि चपाती',['Eggs','Onion','Tomato','Wheat flour','Spices'],'Boil eggs; chop onion and tomato.')
];
const dinners = <Meal>[
  Meal('Moong dal khichdi and kadhi','मूगडाळ खिचडी आणि कढी',['Rice','Moong dal','Curd','Besan','Ghee'],'Rinse rice and dal; keep curd ready.'),
  Meal('Chapati, seasonal bhaji and dal','पोळी, हंगामी भाजी आणि डाळ',['Wheat flour','Seasonal vegetables','Toor dal','Garlic'],'Knead dough and chop vegetables.'),
  Meal('Masale bhaat and raita','मसाले भात आणि रायता',['Rice','Mixed vegetables','Goda masala','Curd','Cucumber'],'Chop vegetables and cucumber.'),
  Meal('Vegetable pulao and raita','भाजी पुलाव आणि रायता',['Rice','Carrot','Beans','Peas','Curd'],'Wash and chop vegetables.'),
  Meal('Dal khichdi and papad','डाळ खिचडी आणि पापड',['Rice','Moong dal','Turmeric','Ghee','Papad'],'Rinse rice and dal.'),
  Meal('Vegetable stew and appam','भाजी स्ट्यू आणि अप्पम',['Coconut milk','Potato','Carrot','Beans','Appam batter'],'Check appam batter; chop vegetables and keep coconut milk chilled.'),
  Meal('Methi matar malai and chapati','मेथी मटार मलाई आणि पोळी',['Fenugreek leaves','Peas','Cream','Wheat flour','Onion'],'Wash and chop methi; thaw peas safely in the refrigerator.'),
  Meal('Lauki chana dal and roti','दुधी चणा डाळ आणि पोळी',['Bottle gourd','Chana dal','Tomato','Wheat flour','Cumin'],'Rinse and soak chana dal; peel and chop bottle gourd.'),
  Meal('Vegetable dalia','भाजी दलिया',['Broken wheat','Carrot','Beans','Peas','Moong dal'],'Rinse dalia and dal; chop vegetables.'),
  Meal('Stuffed capsicum and chapati','भरली ढोबळी मिरची आणि पोळी',['Capsicum','Potato','Peanuts','Wheat flour','Coriander'],'Wash capsicums; boil potatoes and prepare peanut filling.'),
  Meal('Tomato pithla and bhakri','टोमॅटो पिठलं आणि भाकरी',['Besan','Tomato','Garlic','Jowar flour','Coriander'],'Chop tomatoes and garlic; measure besan and jowar flour.'),
  Meal('Vegetable biryani and raita','व्हेज बिर्याणी आणि रायता',['Basmati rice','Mixed vegetables','Yogurt','Mint','Whole spices'],'Wash and soak rice; chop vegetables and prepare yogurt marinade.'),
  Meal('Fish curry and rice','मासे रस्सा आणि भात',['Fish','Rice','Coconut','Onion','Tamarind','Spices'],'Clean fish and refrigerate; prepare curry masala.'),
  Meal('Chicken pulao and salad','चिकन पुलाव आणि कोशिंबीर',['Chicken','Rice','Onion','Yogurt','Whole spices'],'Marinate chicken and refrigerate promptly.')
];
const nonVegLunch = Meal('Chicken curry, rice and salad','चिकन रस्सा, भात आणि कोशिंबीर',['Chicken','Rice','Onion','Tomato','Ginger-garlic','Spices'],'Clean chicken and marinate; refrigerate promptly.');
const nonVegDinner = Meal('Egg curry and chapati','अंडा करी आणि चपाती',['Eggs','Onion','Tomato','Wheat flour','Spices'],'Boil eggs; chop onion and tomato.');

class MenuPlanner {
  static final Map<String, String> _overrides = {};
  static void loadOverrides(String? raw) {
    _overrides.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) { _overrides[entry.key] = entry.value.toString(); }
    } catch (_) { _overrides.clear(); }
  }
  static String _key(DateTime date, String slot) => '${date.year}-${date.month}-${date.day}:$slot';
  static Future<void> replaceMeal(DateTime date, String slot) async {
    final menu = forDate(date);
    final current = slot == 'breakfast' ? menu.breakfast : slot == 'lunch' ? menu.lunch : menu.dinner;
    final pool = slot == 'breakfast' ? breakfasts : slot == 'lunch'
      ? (menu.strictVeg ? lunches.take(12).toList() : [...lunches, nonVegLunch])
      : (menu.strictVeg ? dinners.take(12).toList() : [...dinners, nonVegDinner]);
    // Keep one entry per dish, then move forward from the currently selected meal.
    // This avoids duplicate options and cycles through the available pool.
    final uniquePool = <String, Meal>{for (final meal in pool) meal.en: meal}.values.toList();
    if (uniquePool.length < 2) return;
    final currentIndex = uniquePool.indexWhere((meal) => meal.en == current.en);
    final nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % uniquePool.length;
    final next = uniquePool[nextIndex];
    _overrides[_key(date, slot)] = next.en;
    await AppStore.saveMealOverrides(jsonEncode(_overrides));
  }
  static bool isStrictVeg(DateTime d) => [DateTime.monday, DateTime.thursday, DateTime.saturday].contains(d.weekday);
  static DayMenu forDate(DateTime date) {
    final n = DateTime(date.year,date.month,date.day).difference(DateTime(2026,1,1)).inDays.abs();
    final veg = isStrictVeg(date);
    final b = breakfasts[n % breakfasts.length];
    final l = lunches[(n * 3 + 1) % (veg ? 12 : lunches.length)];
    final d = dinners[(n * 5 + 2) % (veg ? 12 : dinners.length)];
    final baseLunch = veg ? l : (n.isEven ? l : nonVegLunch);
    final baseDinner = veg ? d : (n % 3 == 0 ? nonVegDinner : d);
    Meal pick(Meal base, String slot, List<Meal> pool) {
      final name = _overrides[_key(date, slot)];
      for (final meal in pool) { if (meal.en == name) return meal; }
      return base;
    }
    return DayMenu(pick(b, 'breakfast', breakfasts), pick(baseLunch, 'lunch', veg ? lunches.take(12).toList() : [...lunches, nonVegLunch]), pick(baseDinner, 'dinner', veg ? dinners.take(12).toList() : [...dinners, nonVegDinner]), veg);
  }
}
class AppStore {
  static late SharedPreferences prefs;
  static Future<void> init() async { prefs = await SharedPreferences.getInstance(); MenuPlanner.loadOverrides(prefs.getString('meal_overrides')); }
  static bool get marathi => prefs.getBool('marathi') ?? false;
  static bool get reminders => prefs.getBool('reminders') ?? true;
  static int get householdSize => prefs.getInt('household_size') ?? 4;
  static Future<void> setHouseholdSize(int v) async { await prefs.setInt('household_size', v.clamp(1, 12).toInt()); }
  static Future<void> setMarathi(bool v) async { await prefs.setBool('marathi',v); }
  static Future<void> setReminders(bool v) async { await prefs.setBool('reminders',v); }
  static Set<String> get checkedGroceries => (prefs.getStringList('checked_groceries') ?? []).toSet();
  static Future<void> setChecked(Set<String> v) async { await prefs.setStringList('checked_groceries',v.toList()); }
  static List<String> get favourites => prefs.getStringList('favourites') ?? [];
  static Future<void> saveMealOverrides(String value) async { await prefs.setString('meal_overrides', value); }
  static Future<void> toggleFavourite(String key) async {
    final list = favourites;
    if (list.contains(key)) { list.remove(key); } else { list.add(key); }
    await prefs.setStringList('favourites',list);
  }
}
class ReminderService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    const init = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'),iOS: DarwinInitializationSettings());
    await plugin.initialize(init);
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert:true,badge:true,sound:true);
    if (AppStore.reminders) { await refresh(); }
  }
  static Future<void> refresh() async {
    await plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    for (var i=1;i<=30;i++) {
      final date = DateTime(now.year,now.month,now.day).add(Duration(days:i));
      final menu = MenuPlanner.forDate(date);
      final lines = menu.meals.map((m) => m.en + ': ' + m.ingredients.join(', ') + '. Prep: ' + m.prep).join('\n');
      final reminderDate = date.subtract(const Duration(days:1));
      final when = tz.TZDateTime(tz.local,reminderDate.year,reminderDate.month,reminderDate.day,19);
      if (!when.isAfter(now)) { continue; }
      await plugin.zonedSchedule(7100+i,'Tomorrow meal preparation • ' + date.day.toString() + '/' + date.month.toString(),
        (menu.strictVeg ? 'Strict vegetarian day\n' : 'Veg / non-veg options\n') + lines,when,
        const NotificationDetails(android:AndroidNotificationDetails('meal_prep','Meal preparation reminders',channelDescription:'Next-day meal ingredients and preparation tasks',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()),
        androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime);
    }
  }
}

class HomeFoodApp extends StatefulWidget { const HomeFoodApp({super.key}); @override State<HomeFoodApp> createState()=>_HomeFoodAppState(); }
class _HomeFoodAppState extends State<HomeFoodApp> {
  int tab=0; DateTime selected=DateTime.now();
  @override Widget build(BuildContext context) {
    final mr=AppStore.marathi;
    final pages=[HomePage(date:selected,onDate:(d)=>setState(()=>selected=d),onChanged:()=>setState((){})),const RecipesPage(),GroceryPage(date:selected),SettingsPage(onChanged:()=>setState((){}))];
    return MaterialApp(debugShowCheckedModeBanner:false,title:'365 Days Home Food',theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF8A4B25)),useMaterial3:true,scaffoldBackgroundColor:const Color(0xFFFFFBF5)),
      home:Scaffold(appBar:AppBar(title:Text(mr?'३६५ दिवस घरगुती मेनू':'365 Days Home Food'),actions:[IconButton(onPressed:()=>setState(()=>selected=DateTime.now()),icon:const Icon(Icons.today))]),
      body:IndexedStack(index:tab,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:[
        NavigationDestination(icon:const Icon(Icons.calendar_month),label:mr?'मेनू':'Menu'),NavigationDestination(icon:const Icon(Icons.menu_book),label:mr?'पाककृती':'Recipes'),NavigationDestination(icon:const Icon(Icons.shopping_basket),label:mr?'खरेदी':'Grocery'),NavigationDestination(icon:const Icon(Icons.settings),label:mr?'सेटिंग':'Settings') ])));
  }
}
class HomePage extends StatelessWidget {
  final DateTime date; final ValueChanged<DateTime> onDate; final VoidCallback onChanged;
  const HomePage({super.key,required this.date,required this.onDate,required this.onChanged});
  @override Widget build(BuildContext context) {
    final mr=AppStore.marathi; final menu=MenuPlanner.forDate(date);
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text(mr?'तुमच्या कुटुंबाचा रोजचा आहार':'Your family daily meal plan',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
      const SizedBox(height:10),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(mr?'आठवड्याचा मेनू':'Weekly menu',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
        Row(children:List.generate(7,(i){
          final start=DateTime(date.year,date.month,date.day).subtract(Duration(days:date.weekday-1));
          final day=start.add(Duration(days:i));
          final active=day.year==date.year&&day.month==date.month&&day.day==date.day;
          return Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:2),child:InkWell(
            borderRadius:BorderRadius.circular(12),onTap:()=>onDate(day),
            child:Container(padding:const EdgeInsets.symmetric(vertical:9),decoration:BoxDecoration(color:active?Theme.of(context).colorScheme.primaryContainer:null,borderRadius:BorderRadius.circular(12)),
              child:Column(children:[Text(mr?['सोम','मंगळ','बुध','गुरु','शुक्र','शनि','रवि'][i]:['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i],style:Theme.of(context).textTheme.labelSmall),const SizedBox(height:5),Text(day.day.toString(),style:TextStyle(fontWeight:active?FontWeight.bold:FontWeight.normal))])))));
        }))
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:Text(mr?'मासिक कॅलेंडर':'Monthly calendar',style:Theme.of(context).textTheme.titleMedium)),
        CalendarDatePicker(key:ValueKey('${date.year}-${date.month}-${date.day}'),initialDate:date,firstDate:DateTime(2025),lastDate:DateTime(2035),onDateChanged:onDate)
      ]))),
      Card(child:ListTile(leading:const Icon(Icons.event),title:Text(date.day.toString()+'/'+date.month.toString()+'/'+date.year.toString()),subtitle:Text(menu.strictVeg?(mr?'कडक शाकाहारी दिवस':'Strict vegetarian day'):(mr?'शाकाहारी आणि मांसाहारी पर्याय':'Vegetarian and non-vegetarian options')),trailing:const Icon(Icons.calendar_month))),
      const SizedBox(height:8),
      MealCard(title:mr?'नाश्ता':'Breakfast',meal:menu.breakfast,marathi:mr,onChanged:onChanged,onReplace:() async { await MenuPlanner.replaceMeal(date,'breakfast'); onChanged(); }),
      MealCard(title:mr?'दुपारचे जेवण':'Lunch',meal:menu.lunch,marathi:mr,onChanged:onChanged,onReplace:() async { await MenuPlanner.replaceMeal(date,'lunch'); onChanged(); }),
      MealCard(title:mr?'रात्रीचे जेवण':'Dinner',meal:menu.dinner,marathi:mr,onChanged:onChanged,onReplace:() async { await MenuPlanner.replaceMeal(date,'dinner'); onChanged(); }),
      Card(color:Theme.of(context).colorScheme.secondaryContainer,child:ListTile(leading:const Icon(Icons.notifications_active),title:Text(mr?'उद्याच्या तयारीची आठवण':'Tomorrow preparation reminder'),subtitle:Text(mr?'संध्याकाळी ७:०० वाजता':'Daily at 7:00 PM India time'))),
      const FestivalMenuCard()
    ]);
  }
}
String mealPhotoUrl(Meal meal) {
  final name = meal.en.toLowerCase();
  String photo;
  if (name.contains('poha') || name.contains('upma') || name.contains('idli') || name.contains('dosa') || name.contains('appe') || name.contains('thepla') || name.contains('paratha') || name.contains('chilla') || name.contains('thalipeeth') || name.contains('sabudana')) {
    photo = 'photo-1547592180-85f173990554';
  } else if (name.contains('biryani') || name.contains('pulao') || name.contains('rice') || name.contains('khichdi') || name.contains('bhaat')) {
    photo = 'photo-1596797038530-2c107229654b';
  } else if (name.contains('paneer') || name.contains('palak') || name.contains('curry') || name.contains('chole') || name.contains('rajma') || name.contains('usal') || name.contains('pithla') || name.contains('kadhi')) {
    photo = 'photo-1565557623262-b51c2513a641';
  } else if (name.contains('modak') || name.contains('poli') || name.contains('ladoo') || name.contains('karanji') || name.contains('shrikhand') || name.contains('cake') || name.contains('sheer') || name.contains('porridge')) {
    photo = 'photo-1601050690597-df0568f70950';
  } else if (name.contains('fish') || name.contains('chicken') || name.contains('egg')) {
    photo = 'photo-1603894584373-5ac82b2ae398';
  } else {
    photo = 'photo-1585937421612-70a008356fbe';
  }
  return 'https://images.unsplash.com/' + photo + '?auto=format&fit=crop&w=1000&q=80';
}

class MealPhoto extends StatelessWidget {
  final Meal meal;
  const MealPhoto({super.key, required this.meal});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          mealPhotoUrl(meal),
          fit: BoxFit.cover,
          cacheWidth: 1000,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.restaurant, size: 42),
          ),
        ),
      ),
    );
  }
}

class MealCard extends StatelessWidget {
  final String title; final Meal meal; final bool marathi; final VoidCallback onChanged; final VoidCallback onReplace;
  const MealCard({super.key,required this.title,required this.meal,required this.marathi,required this.onChanged,required this.onReplace});
  @override Widget build(BuildContext context) {
    final fav=AppStore.favourites.contains(meal.en);
    return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(title,style:Theme.of(context).textTheme.labelLarge?.copyWith(color:Theme.of(context).colorScheme.primary))),IconButton(tooltip:marathi?'जेवण बदला':'Replace meal',onPressed:onReplace,icon:const Icon(Icons.shuffle)),IconButton(onPressed:() async {await AppStore.toggleFavourite(meal.en);onChanged();},icon:Icon(fav?Icons.favorite:Icons.favorite_border,color:fav?Colors.red:null))]),
      Text(meal.name(marathi),style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
      const SizedBox(height:10),
      MealPhoto(meal:meal),
      const SizedBox(height:6),Text((marathi?'साहित्य: ':'Ingredients: ')+meal.ingredients.join(', ')),
      Text((marathi?'आधीची तयारी: ':'Advance prep: ')+meal.prep)
    ])));
  }
}
const Map<String, List<String>> _stepsEn = {
  'Poha':['Rinse poha briefly in a colander; drain and rest for 5 minutes.','Heat oil; crackle mustard seeds and cumin, then add curry leaves and peanuts.','Add chopped onion and potato; cook until the potato is tender.','Mix in turmeric, salt and poha; cover on low heat for 3–4 minutes.','Finish with coriander and lemon; serve hot.'],
  'Upma':['Dry-roast rava on low heat until aromatic; set aside.','Heat oil; add mustard, cumin, curry leaves and chopped vegetables.','Add water and salt; simmer until vegetables soften.','Slowly stir in rava to avoid lumps.','Cover and cook on low heat for 3–4 minutes; finish with coriander.'],
  'Thalipeeth':['Combine bhajani flour, onion, coriander, chilli and salt with water to make a soft dough.','Rest for 5 minutes; wet your hands and pat dough into a thin round on a damp cloth.','Make a small centre hole so it cooks evenly.','Cook on a hot tawa with a little oil, turning until both sides are golden and cooked through.','Serve with curd or chutney.'],
  'Idli and chutney':['Grease idli moulds lightly and bring the steamer water to a boil.','Pour fermented idli batter into moulds, leaving a little room to rise.','Steam for 10–12 minutes; rest briefly before unmoulding.','Grind coconut, roasted gram, chilli and salt with a little water for chutney.','Temper chutney with mustard seeds and curry leaves if desired.'],
  'Sabudana khichdi':['Rinse sabudana and soak with just enough water for 4–6 hours; pearls should press easily.','Drain completely; mix with crushed roasted peanuts and salt.','Heat ghee or oil; add cumin, potato and chilli; cook potato until tender.','Add sabudana mixture and toss gently on low heat until pearls turn translucent.','Finish with lemon and coriander; avoid over-stirring.'],
  'Besan chilla':['Whisk besan, water, salt and turmeric into a pourable, lump-free batter.','Mix in finely chopped onion, tomato, coriander and chilli.','Heat and lightly grease a tawa; pour and spread a thin circle.','Cook until the top looks set, drizzle a little oil and flip.','Cook the second side until golden; serve with curd or chutney.'],
  'Dosa':['Prepare a smooth, pourable fermented dosa batter; adjust with a little water if needed.','Heat a tawa and lightly grease it; pour batter in the centre.','Spread outward in a thin spiral and drizzle a little oil around the edge.','Cook until crisp and golden; fold and remove.','For masala dosa, add cooked potato-onion masala before folding.'],
  'Varan-bhaat, bhaji and koshimbir':['Wash rice and toor dal separately; pressure-cook dal until soft and mash smooth.','Simmer dal with turmeric, salt and water; finish with a cumin-garlic ghee tempering.','Cook rice separately until fluffy.','Prepare the seasonal vegetable bhaji with a little oil, spices and water until tender.','Mix chopped cucumber with curd, salt and coriander for koshimbir; serve together.'],
  'Pithla-bhakri':['Whisk besan with water until smooth and lump-free.','Heat oil; add mustard, cumin, garlic, onion and chilli; sauté until softened.','Add turmeric and the besan mixture gradually, stirring continuously.','Cook on low heat until thick, glossy and the raw besan smell disappears; adjust salt.','Knead jowar flour with warm water, pat into bhakris and cook on a hot tawa until done.'],
  'Matki usal and rice':['Soak matki overnight; drain and sprout if time permits.','Pressure-cook until tender but still holding shape.','Sauté onion, tomato, ginger-garlic and goda masala in oil.','Add cooked matki, salt and water; simmer 8–10 minutes to blend flavours.','Cook rice separately and serve with coriander and lemon.'],
  'Paneer masala and chapati':['Sauté onion in oil until soft; add ginger-garlic and cook briefly.','Add tomato and spices; cook until tomatoes soften, then blend if a smooth gravy is preferred.','Return gravy to pan, add water and simmer; season with salt.','Add paneer cubes and simmer gently for 3–4 minutes; finish with curd or cream if desired.','Knead wheat flour, rest the dough, roll chapatis and cook on a hot tawa.'],
  'Vangi bharit and bhakri':['Wash and prick brinjal; roast over a flame or bake until the skin chars and inside is soft.','Cool, peel and mash the flesh.','Sauté onion, chilli and garlic; add mashed brinjal, salt and cook for a few minutes.','Finish with coriander and serve warm.','Make jowar bhakri with flour and warm water; pat and cook thoroughly on a hot tawa.'],
  'Chicken curry, rice and salad':['Keep chicken refrigerated while marinating with ginger-garlic, turmeric, chilli and salt.','Sauté onion until golden; add tomato and curry spices and cook until oil begins to separate.','Add chicken and turn to coat; cook until the outside changes colour.','Add hot water, cover and simmer until chicken is fully cooked (74°C/165°F at the thickest part).','Cook rice separately; serve curry with fresh salad.'],
  'Egg curry and chapati':['Boil eggs until hard-cooked, cool, peel and make shallow slits.','Sauté onion until golden; add ginger-garlic, tomato and spices.','Cook masala until soft and fragrant; add water and salt to make gravy.','Add eggs and simmer 5 minutes; turn gently so they absorb the gravy.','Roll and cook chapatis on a hot tawa; serve immediately.'],
  'Moong dal khichdi and kadhi':['Wash rice and moong dal; pressure-cook with turmeric, salt and water until soft.','Stir in ghee and adjust consistency with hot water.','Whisk curd, besan, water and turmeric until smooth for kadhi.','Simmer kadhi gently, stirring often, until it thickens and the raw besan taste disappears.','Add a cumin, mustard and curry-leaf tempering; serve with khichdi.'],
  'Chapati, seasonal bhaji and dal':['Wash and pressure-cook toor dal until soft; mash and simmer with turmeric and salt.','Prepare a garlic-cumin tempering and add it to the dal.','Cook chopped seasonal vegetables with oil, spices and a splash of water until tender.','Knead wheat flour with water, rest 15 minutes and divide into balls.','Roll chapatis and cook both sides on a hot tawa until puffed and lightly browned.'],
  'Masale bhaat and raita':['Wash rice and soak for 15 minutes; drain.','Sauté whole spices, onion and mixed vegetables in a little oil.','Add goda masala, rice, salt and measured water; mix gently.','Cover and cook on low heat until rice is tender; rest 5 minutes before fluffing.','Mix curd with cucumber and salt for raita; serve alongside.'],
  'Vegetable pulao and raita':['Wash and soak rice for 15 minutes; drain.','Sauté whole spices, onion, carrot, beans and peas until fragrant.','Add rice, salt and water; bring to a boil.','Cover and cook on low heat until rice is tender; rest before fluffing.','Prepare cucumber raita with curd, salt and coriander.'],
  'Dal khichdi and papad':['Wash rice and moong dal; drain.','Add to a pot or pressure cooker with turmeric, salt and water.','Cook until soft and creamy; add hot water if a looser texture is preferred.','Finish with ghee and a cumin-garlic tempering.','Roast papad on a flame or dry tawa and serve immediately.'],
  'Fish curry and rice':['Keep fish chilled; clean, rinse quickly and pat dry.','Grind or prepare coconut, onion, chilli and spices into a smooth curry paste.','Cook the paste in oil until fragrant; add tamarind water and enough water for gravy.','Simmer gently, add fish pieces and cook until opaque and flakes easily; avoid stirring hard.','Cook rice separately; serve curry hot.'],
  'Chicken pulao and salad':['Marinate chicken with yogurt, ginger-garlic, salt and spices; keep refrigerated.','Sauté whole spices and sliced onion until golden.','Add chicken and cook until the outside is no longer pink.','Add washed rice and measured hot water; cover and cook on low heat until chicken is fully cooked and rice is tender.','Rest covered for 5 minutes, fluff gently and serve with salad.'],
  'Vegetable paratha and curd':['Boil and mash potato; grate carrot and thaw peas.','Mix vegetables with salt and mild spices; knead wheat flour into a soft dough.','Roll dough balls with the filling sealed inside.','Cook each paratha on a hot tawa with a little oil until both sides are golden and the centre is cooked.','Serve with fresh curd.'],
  'Moong dal dosa':['Soak moong dal for 3–4 hours, drain and grind with ginger, chilli and water to a smooth batter.','Add salt and chopped coriander; adjust to a pourable consistency.','Heat a lightly greased tawa and spread a thin dosa.','Cook until the edges lift, flip and cook the other side.','Serve hot with curd or chutney.'],
  'Methi thepla':['Wash methi leaves, drain well and chop finely.','Mix wheat flour, methi, curd, sesame and spices; add water gradually to make a soft dough.','Rest covered for 10 minutes and divide into balls.','Roll thin theplas and cook on a hot tawa with a little oil on both sides.','Serve warm with curd.'],
  'Misal pav (mild)':['Soak matki overnight, drain and sprout if possible; pressure-cook until tender.','Sauté onion, tomato, ginger-garlic and mild goda masala in oil.','Add cooked matki, salt and water; simmer until the usal thickens.','Prepare a mild thin rassa with the cooked masala and adjust seasoning.','Serve with pav, coriander and lemon; keep spicy toppings optional.'],
  'Vegetable sandwich':['Boil and slice potato; wash and slice cucumber and tomato.','Spread butter or chutney on bread slices.','Layer vegetables evenly and season lightly with salt and pepper.','Close the sandwich and toast on a pan or sandwich press until crisp.','Cut and serve immediately.'],
  'Appe and coconut chutney':['Stir chopped onion and grated carrot into idli batter; add salt if needed.','Heat an appe pan and grease each cavity lightly.','Fill cavities three-quarters full; cover and cook until the bottoms are golden.','Turn each appe and cook until the centre is cooked through.','Grind coconut with roasted gram, chilli, salt and water for chutney.'],
  'Ragi porridge and fruit':['Whisk ragi flour with a little cold milk or water until smooth.','Heat the remaining milk and slowly stir in the ragi mixture.','Cook on low heat, stirring continuously, until thick and fully cooked.','Add jaggery and cardamom; stir until dissolved.','Cool to a safe serving temperature and add washed, cut fruit.'],
  'Rajma masala and rice':['Soak rajma overnight in plenty of water; drain and pressure-cook until completely soft.','Sauté onion, ginger-garlic and tomato with cumin and spices until the masala thickens.','Add cooked rajma and some cooking liquid; mash a few beans to thicken the gravy.','Simmer for 15–20 minutes and adjust salt and consistency.','Cook rice separately and serve hot.'],
  'Chole and chapati':['Soak chickpeas overnight; pressure-cook until soft and keep some cooking liquid.','Sauté onion, ginger-garlic and tomato with chole masala until well cooked.','Add chickpeas, salt and cooking liquid; simmer and lightly mash a few chickpeas.','Cook until the gravy coats the chickpeas; finish with coriander and lemon.','Roll and cook chapatis on a hot tawa.'],
  'Palak paneer and jeera rice':['Wash spinach thoroughly; blanch briefly and cool, then blend to a smooth puree.','Sauté cumin, garlic and onion; add spinach puree, salt and mild spices.','Simmer gently; add paneer cubes and cook for 3–4 minutes.','Rinse rice and cook until fluffy; prepare a cumin tempering if desired.','Serve palak paneer with jeera rice.'],
  'Kadhi pakora and rice':['Whisk curd, besan, turmeric and water until completely smooth.','Simmer the kadhi gently, stirring often, until cooked and slightly thickened.','Make a thick besan batter with sliced onion, salt and spices; fry small pakoras until cooked.','Add pakoras to the kadhi and simmer briefly; finish with curry-leaf tempering.','Cook rice separately and serve hot.'],
  'Bharli vangi and bhakri':['Wash small brinjals and slit them lengthwise without separating the stems.','Mix roasted crushed peanuts, sesame, coconut, goda masala, salt and a little water for stuffing.','Fill brinjals; arrange in a pan with oil and cook covered on low heat, turning carefully.','Add a little water as needed and cook until brinjals are tender and filling is cooked.','Prepare jowar bhakri and serve with the gravy.'],
  'Vegetable thali':['Wash and chop the seasonal vegetables; rinse toor dal and rice.','Pressure-cook dal until soft; simmer with turmeric, salt and a tempering.','Cook rice separately until fluffy.','Prepare one or two vegetable sides with a little oil, spices and water until tender.','Serve with chapati or bhakri, curd and fresh salad as available.'],
  'Lemon rice and curd':['Cook rice until separate grains are tender; spread briefly to cool.','Heat oil and temper mustard, curry leaves, peanuts and turmeric.','Add rice and salt; toss gently so the grains stay intact.','Switch off heat and mix in fresh lemon juice; taste and adjust.','Serve with curd.'],
  'Vegetable stew and appam':['Prepare appam batter according to its fermentation needs.','Sauté onion, ginger, curry leaves and whole spices in a little oil.','Add potato, carrot and beans with water; cover and cook until tender.','Add coconut milk and salt; heat gently without boiling hard.','Cook appams in an appam pan and serve with the stew.'],
  'Methi matar malai and chapati':['Wash and chop methi; blanch briefly if you prefer a milder bitterness.','Sauté onion, ginger and mild spices; add peas and cook until tender.','Add methi and a little water; simmer until cooked.','Stir in cream and adjust salt; heat gently without boiling hard.','Roll and cook chapatis on a hot tawa.'],
  'Lauki chana dal and roti':['Rinse chana dal and soak for 30 minutes; drain.','Peel and cube bottle gourd; chop tomato and prepare cumin tempering.','Pressure-cook dal with bottle gourd, turmeric and water until tender.','Simmer with tomato, spices and salt until flavours combine; finish with coriander.','Serve with freshly cooked roti.'],
  'Vegetable dalia':['Rinse broken wheat and moong dal; chop vegetables into small pieces.','Heat a little oil or ghee; add cumin, vegetables and dalia and stir briefly.','Add dal, water, turmeric and salt.','Pressure-cook until the dalia is soft; release pressure safely and adjust consistency.','Finish with coriander and lemon if desired.'],
  'Stuffed capsicum and chapati':['Wash capsicums, remove tops and seeds while keeping them intact.','Boil and mash potato; mix with crushed peanuts, coriander, salt and mild spices.','Fill capsicums with the potato mixture.','Cook covered in a lightly oiled pan on low heat, turning gently until capsicums soften.','Serve with chapati.'],
  'Tomato pithla and bhakri':['Whisk besan with water until smooth; chop tomatoes and garlic.','Sauté garlic, tomato and spices in oil until tomatoes soften.','Add water and salt; bring to a gentle simmer.','Pour in besan mixture gradually while stirring; cook until thick and no raw besan taste remains.','Prepare jowar bhakri and serve hot.'],
  'Vegetable biryani and raita':['Wash and soak basmati rice for 20 minutes; drain.','Sauté whole spices, onion and vegetables; add yogurt, mint and biryani spices.','Layer rice over the vegetable masala and add measured hot water.','Cover tightly and cook on low heat until rice and vegetables are fully cooked; rest before opening.','Prepare cucumber raita and serve.'],
};
const Map<String, List<String>> _stepsMr = {
  'Poha':['पोहे चाळणीत घेऊन हलके धुवा, पाणी निथळू द्या आणि ५ मिनिटे ठेवा.','कढईत तेल गरम करून मोहरी, जिरे, कढीपत्ता आणि शेंगदाणे फोडणीला घाला.','कांदा व बटाटा घालून बटाटा मऊ होईपर्यंत शिजवा.','हळद, मीठ आणि पोहे मिसळून झाकण ठेवून मंद आचेवर ३–४ मिनिटे वाफवा.','कोथिंबीर व लिंबू घालून गरम वाढा.'],
  'Upma':['रवा मंद आचेवर सुगंध येईपर्यंत भाजून बाजूला ठेवा.','तेलात मोहरी, जिरे, कढीपत्ता आणि चिरलेल्या भाज्या परता.','पाणी व मीठ घालून भाज्या मऊ होईपर्यंत शिजवा.','रवा हळूहळू घालत सतत ढवळा, गुठळ्या होऊ देऊ नका.','झाकण ठेवून ३–४ मिनिटे मंद आचेवर शिजवा व कोथिंबीर घाला.'],
  'Thalipeeth':['भाजणी, कांदा, कोथिंबीर, मिरची व मीठ पाण्याने मऊसर मळा.','५ मिनिटे झाकून ठेवा; ओल्या हाताने ओल्या कापडावर थापून गोल करा.','मधोमध छोटे छिद्र करा म्हणजे नीट शिजेल.','गरम तव्यावर थोडे तेल घालून दोन्ही बाजू सोनेरी व पूर्ण शिजेपर्यंत भाजा.','दही किंवा चटणीसोबत वाढा.'],
  'Idli and chutney':['इडली पात्रांना हलके तेल लावा आणि कुकर/इडलीपात्रातील पाणी उकळवा.','साच्यांत इडलीचे पीठ थोडी जागा ठेवून भरा.','१०–१२ मिनिटे वाफवा; थोडे थंड झाल्यावर इडल्या काढा.','खोबरे, भाजलेली डाळ, मिरची, मीठ आणि थोडे पाणी वाटून चटणी करा.','इच्छेनुसार मोहरी-कढीपत्त्याची फोडणी द्या.'],
  'Sabudana khichdi':['साबुदाणा धुऊन ४–६ तास कमी पाण्यात भिजवा; दाणे बोटाने सहज दाबले गेले पाहिजेत.','पाणी पूर्ण निथळून कुटलेले भाजलेले शेंगदाणे व मीठ मिसळा.','तुपात जिरे, बटाटा व मिरची घालून बटाटा मऊ होईपर्यंत शिजवा.','साबुदाणा घालून मंद आचेवर हलके परता; दाणे पारदर्शक होऊ द्या.','लिंबू व कोथिंबीर घाला; जास्त ढवळू नका.'],
  'Besan chilla':['बेसन, पाणी, मीठ व हळद एकत्र करून गुठळ्या नसलेले पीठ करा.','कांदा, टोमॅटो, कोथिंबीर व मिरची मिसळा.','तवा गरम करून थोडे तेल लावा आणि पीठ पातळ पसरवा.','वरचा भाग सेट झाल्यावर थोडे तेल सोडून चिल्ला उलटा.','दुसरी बाजू सोनेरी होईपर्यंत भाजून दही/चटणीसोबत वाढा.'],
  'Dosa':['डोशाचे आंबवलेले पीठ आवश्यक असल्यास थोड्या पाण्याने पातळ करा.','तवा गरम करून हलके तेल लावा आणि मध्यभागी पीठ घाला.','पातळ गोलाकार पसरवून कडेला थोडे तेल सोडा.','खालील बाजू कुरकुरीत व सोनेरी झाल्यावर दुमडा.','मसाला डोसा असल्यास बटाटा भाजी भरून दुमडा.'],
  'Varan-bhaat, bhaji and koshimbir':['तांदूळ व तूरडाळ वेगवेगळी धुऊन डाळ मऊ शिजवून घोटा.','डाळीत हळद, मीठ व पाणी घालून उकळा; जिरे-लसूण-तुपाची फोडणी द्या.','भात वेगळा मोकळा शिजवा.','हंगामी भाजी तेल, मसाले व थोडे पाणी घालून मऊ शिजवा.','काकडी, दही, मीठ व कोथिंबीर एकत्र करून कोशिंबीर करा.'],
  'Pithla-bhakri':['बेसन पाण्यात घालून गुठळ्या नसलेले मिश्रण तयार करा.','तेलात मोहरी, जिरे, लसूण, कांदा व मिरची परता.','हळद घालून बेसनाचे मिश्रण हळूहळू ओतत सतत ढवळा.','कच्च्या बेसनाचा वास जाईपर्यंत मंद आचेवर घट्ट शिजवा; मीठ तपासा.','ज्वारीच्या पिठात कोमट पाणी घालून भाकरी थापा व तव्यावर दोन्ही बाजूंनी शिजवा.'],
  'Matki usal and rice':['मटकी रात्रभर भिजवा; शक्य असल्यास मोड आणा.','मटकी मऊ पण आकार टिकेल इतकी शिजवा.','तेलात कांदा, टोमॅटो, आले-लसूण व गोडा मसाला परता.','मटकी, मीठ व पाणी घालून ८–१० मिनिटे रस्सा मुरू द्या.','भात वेगळा शिजवून कोथिंबीर व लिंबासोबत वाढा.'],
  'Paneer masala and chapati':['तेलात कांदा मऊ होईपर्यंत परता; आले-लसूण घालून थोडे परता.','टोमॅटो व मसाले घालून शिजवा; हवे असल्यास वाटून घ्या.','मसाला परत पॅनमध्ये घेऊन पाणी व मीठ घालून उकळा.','पनीरचे तुकडे घालून ३–४ मिनिटे मंद आचेवर शिजवा.','गव्हाचे पीठ मळून पोळ्या लाटा व गरम तव्यावर भाजा.'],
  'Vangi bharit and bhakri':['वांगे धुऊन टोचून घ्या; गॅसवर किंवा ओव्हनमध्ये आतून मऊ होईपर्यंत भाजा.','थंड झाल्यावर साल काढून गर मॅश करा.','कांदा, मिरची व लसूण परतून त्यात वांग्याचा गर व मीठ घालून शिजवा.','कोथिंबीर घालून गरम वाढा.','ज्वारीचे पीठ कोमट पाण्याने मळून भाकरी थापा व तव्यावर पूर्ण शिजवा.'],
  'Chicken curry, rice and salad':['चिकन आले-लसूण, हळद, तिखट व मीठ लावून फ्रिजमध्ये मुरत ठेवा.','कांदा सोनेरी परतून टोमॅटो व मसाले घालून तेल सुटेपर्यंत शिजवा.','चिकन घालून मसाल्यात परता.','गरम पाणी घालून झाकून चिकन पूर्ण शिजवा; आतील तापमान ७४°C असावे.','भात वेगळा शिजवून ताज्या कोशिंबिरीसोबत वाढा.'],
  'Egg curry and chapati':['अंडी पूर्ण उकडून थंड करा, साल काढून हलक्या चिरा द्या.','कांदा सोनेरी परतून आले-लसूण, टोमॅटो व मसाले घाला.','मसाला मऊ व सुगंधी होईपर्यंत शिजवून पाणी व मीठ घाला.','अंडी घालून ५ मिनिटे मंद आचेवर रस्सा मुरू द्या.','पोळ्या लाटून गरम तव्यावर भाजा.'],
  'Moong dal khichdi and kadhi':['तांदूळ व मूगडाळ धुऊन हळद, मीठ व पाण्यासह मऊ शिजवा.','खिचडीत तूप घालून गरजेनुसार गरम पाणी मिसळा.','कढीसाठी दही, बेसन, पाणी व हळद गुळगुळीत फेटा.','कढी मंद आचेवर सतत ढवळत घट्ट होईपर्यंत शिजवा.','जिरे, मोहरी व कढीपत्त्याची फोडणी देऊन खिचडीसोबत वाढा.'],
  'Chapati, seasonal bhaji and dal':['तूरडाळ मऊ शिजवून घोटा; हळद व मीठ घालून उकळा.','जिरे-लसूण फोडणी डाळीत घाला.','चिरलेल्या हंगामी भाज्या तेल, मसाले व थोडे पाणी घालून शिजवा.','गव्हाचे पीठ पाण्याने मळून १५ मिनिटे झाकून ठेवा.','पोळ्या लाटून गरम तव्यावर दोन्ही बाजूंनी भाजा.'],
  'Masale bhaat and raita':['तांदूळ धुऊन १५ मिनिटे भिजवा व पाणी निथळा.','तेलात अख्खे मसाले, कांदा व मिश्र भाज्या परता.','गोडा मसाला, तांदूळ, मीठ व मोजून पाणी घालून हलके मिसळा.','झाकून मंद आचेवर भात शिजवा; ५ मिनिटे ठेवून मोकळा करा.','दही, काकडी व मीठ एकत्र करून रायता करा.'],
  'Vegetable pulao and raita':['तांदूळ धुऊन १५ मिनिटे भिजवा व निथळा.','अख्खे मसाले, कांदा, गाजर, बीन्स व मटार परता.','तांदूळ, मीठ व पाणी घालून उकळी आणा.','झाकून मंद आचेवर भात शिजवा; थोडा वेळ ठेवून मोकळा करा.','दही, काकडी, मीठ व कोथिंबीर घालून रायता करा.'],
  'Dal khichdi and papad':['तांदूळ व मूगडाळ धुऊन पाणी निथळा.','हळद, मीठ व पाण्यासह कुकरमध्ये घाला.','मऊसर शिजवा; पातळ हवी असल्यास गरम पाणी घाला.','तूप व जिरे-लसूण फोडणी घालून मिसळा.','पापड भाजून लगेच वाढा.'],
  'Fish curry and rice':['मासे थंड ठेवा; स्वच्छ करून पटकन धुऊन कोरडे करा.','खोबरे, कांदा, मिरची व मसाले वाटून मसाला तयार करा.','तेलात मसाला परतून चिंचेचे पाणी व रस्स्यासाठी पाणी घाला.','मंद उकळीवर मासे घालून अपारदर्शक व सहज सुटेपर्यंत शिजवा; जास्त ढवळू नका.','भात वेगळा शिजवून गरम रस्स्यासोबत वाढा.'],
  'Chicken pulao and salad':['चिकन दही, आले-लसूण, मीठ व मसाल्यांत मुरवून फ्रिजमध्ये ठेवा.','अख्खे मसाले व कांदा सोनेरी होईपर्यंत परता.','चिकन घालून बाहेरचा भाग शिजेपर्यंत परता.','धुतलेला तांदूळ व मोजून गरम पाणी घालून झाकून शिजवा; चिकन पूर्ण शिजले पाहिजे.','५ मिनिटे झाकून ठेवून हलके मोकळे करा व कोशिंबिरीसोबत वाढा.'],
  'Vegetable paratha and curd':['बटाटा उकडून कुस्करा; गाजर किसून मटार तयार ठेवा.','भाज्यांत मीठ व सौम्य मसाले मिसळा; गव्हाचे पीठ मऊ मळा.','पीठाच्या गोळ्यात सारण भरून कडा बंद करा.','गरम तव्यावर थोडे तेल घालून दोन्ही बाजूंनी सोनेरी व पूर्ण शिजेपर्यंत भाजा.','ताज्या दह्यासोबत वाढा.'],
  'Moong dal dosa':['मूगडाळ ३–४ तास भिजवून निथळा; आले, मिरची व पाण्यासह वाटा.','मीठ व कोथिंबीर घालून डोश्यासारखे पीठ तयार करा.','गरम, हलक्या तेल लावलेल्या तव्यावर पातळ डोसा पसरवा.','कडा सुटू लागल्यावर उलटून दुसरी बाजू भाजा.','दही किंवा चटणीसोबत गरम वाढा.'],
  'Methi thepla':['मेथी स्वच्छ धुऊन पाणी निथळा व बारीक चिरा.','गव्हाचे पीठ, मेथी, दही, तीळ व मसाले मिसळून मऊ पीठ मळा.','१० मिनिटे झाकून ठेवून गोळे करा.','पातळ थेपले लाटून तव्यावर थोडे तेल घालून दोन्ही बाजूंनी भाजा.','दह्यासोबत वाढा.'],
  'Misal pav (mild)':['मटकी रात्रभर भिजवून निथळा; शक्य असल्यास मोड आणून मऊ शिजवा.','कांदा, टोमॅटो, आले-लसूण व सौम्य गोडा मसाला परता.','शिजवलेली मटकी, मीठ व पाणी घालून उसळ शिजवा.','मसाल्यात पाणी घालून सौम्य रस्सा तयार करा.','पाव, कोथिंबीर व लिंबासोबत वाढा; तिखट फरसाण ऐच्छिक ठेवा.'],
  'Vegetable sandwich':['बटाटा उकडून चकत्या करा; काकडी व टोमॅटो धुऊन चिरा.','ब्रेडला लोणी किंवा चटणी लावा.','भाज्यांचे थर लावून थोडे मीठ व मिरी घाला.','सँडविच पॅनमध्ये किंवा तव्यावर कुरकुरीत भाजा.','कापून लगेच वाढा.'],
  'Appe and coconut chutney':['इडलीच्या पिठात कांदा व किसलेले गाजर मिसळा.','आप्पे पात्र गरम करून प्रत्येक कपाला थोडे तेल लावा.','कप तीन-चतुर्थांश भरा; झाकून तळ सोनेरी होईपर्यंत शिजवा.','आप्पे उलटून आतील भाग पूर्ण शिजवा.','खोबरे, भाजलेली डाळ, मिरची, मीठ व पाणी वाटून चटणी करा.'],
  'Ragi porridge and fruit':['नाचणीचे पीठ थोड्या थंड दूधात किंवा पाण्यात गुठळ्या न राहता कालवा.','उरलेले दूध गरम करून नाचणीचे मिश्रण हळूहळू घाला.','मंद आचेवर सतत ढवळत घट्ट व पूर्ण शिजेपर्यंत शिजवा.','गूळ व वेलची घालून विरघळेपर्यंत ढवळा.','कोमट झाल्यावर धुतलेली व चिरलेली फळे घाला.'],
  'Rajma masala and rice':['राजमा भरपूर पाण्यात रात्रभर भिजवून पूर्ण मऊ होईपर्यंत कुकरमध्ये शिजवा.','कांदा, आले-लसूण व टोमॅटो जिरे-मसाल्यासह परता.','राजमा व थोडे शिजवलेले पाणी घाला; काही दाणे कुस्करून रस्सा घट्ट करा.','१५–२० मिनिटे मंद आचेवर शिजवून मीठ व घट्टपणा समायोजित करा.','भात वेगळा शिजवून गरम वाढा.'],
  'Chole and chapati':['हरभरा रात्रभर भिजवून मऊ होईपर्यंत कुकरमध्ये शिजवा.','कांदा, आले-लसूण व टोमॅटो छोले मसाल्यासह परता.','हरभरा, मीठ व थोडे शिजवलेले पाणी घालून मंद आचेवर शिजवा.','काही हरभरे कुस्करून रस्सा घट्ट करा; कोथिंबीर व लिंबू घाला.','पोळ्या लाटून तव्यावर भाजा.'],
  'Palak paneer and jeera rice':['पालक स्वच्छ धुऊन थोडा वेळ उकळत्या पाण्यात घालून थंड करा व वाटा.','जिरे, लसूण व कांदा परतून पालकाची पेस्ट, मीठ व मसाले घाला.','मंद आचेवर शिजवून पनीर घालून ३–४ मिनिटे शिजवा.','भात धुऊन मोकळा शिजवा; जिऱ्याची फोडणी ऐच्छिक.','जिरा भातासोबत पालक पनीर वाढा.'],
  'Kadhi pakora and rice':['दही, बेसन, हळद व पाणी गुळगुळीत होईपर्यंत फेटा.','कढी मंद आचेवर सतत ढवळत घट्ट होईपर्यंत शिजवा.','कांदा, बेसन, मीठ व मसाल्यांचे घट्ट पीठ करून छोटे भजी तळा.','भजी कढीत घालून थोडे शिजवा; कढीपत्त्याची फोडणी द्या.','भात वेगळा शिजवून गरम वाढा.'],
  'Bharli vangi and bhakri':['लहान वांगी धुऊन देठ न तोडता लांबीने चिरा.','भाजलेले शेंगदाणे, तीळ, खोबरे, गोडा मसाला, मीठ व थोडे पाणी मिसळून सारण करा.','वांग्यांत सारण भरून तेलाच्या पातेल्यात मंद आचेवर झाकून शिजवा.','गरजेनुसार थोडे पाणी घालून वांगी मऊ व सारण शिजेपर्यंत शिजवा.','ज्वारीची भाकरी करून वाढा.'],
  'Vegetable thali':['हंगामी भाज्या धुऊन चिरा; तूरडाळ व तांदूळ धुवा.','डाळ मऊ शिजवून हळद, मीठ व फोडणी घालून उकळा.','भात वेगळा मोकळा शिजवा.','एक-दोन भाज्या तेल, मसाले व थोड्या पाण्यात मऊ शिजवा.','उपलब्धतेनुसार पोळी/भाकरी, दही व कोशिंबिरीसोबत वाढा.'],
  'Lemon rice and curd':['भाताचे दाणे मोकळे राहतील असा शिजवून थोडा थंड करा.','तेलात मोहरी, कढीपत्ता, शेंगदाणे व हळद फोडणीला घाला.','भात व मीठ घालून दाणे न मोडता हलवा.','गॅस बंद करून लिंबाचा रस मिसळा व चव तपासा.','दह्यासोबत वाढा.'],
  'Vegetable stew and appam':['अप्पमचे पीठ आवश्यकतेनुसार आंबवून तयार ठेवा.','कांदा, आले, कढीपत्ता व अख्खे मसाले तेलात परता.','बटाटा, गाजर व बीन्स पाण्यासह घालून झाकून मऊ शिजवा.','नारळाचे दूध व मीठ घालून मंद गरम करा; जोरात उकळू नका.','अप्पम पात्रात अप्पम करून स्ट्यूसोबत वाढा.'],
  'Methi matar malai and chapati':['मेथी धुऊन चिरा; कडूपणा कमी हवा असल्यास थोडी ब्लांच करा.','कांदा, आले व सौम्य मसाले परतून मटार मऊ शिजवा.','मेथी व थोडे पाणी घालून शिजवा.','क्रीम व मीठ घालून मंद गरम करा.','पोळ्या तव्यावर भाजून वाढा.'],
  'Lauki chana dal and roti':['चना डाळ धुऊन ३० मिनिटे भिजवा व निथळा.','दुधी सोलून चौकोनी तुकडे करा; टोमॅटो चिरा.','डाळ, दुधी, हळद व पाण्यासह मऊ होईपर्यंत कुकरमध्ये शिजवा.','टोमॅटो, मसाले व मीठ घालून मंद शिजवा; कोथिंबीर घाला.','गरम पोळीसोबत वाढा.'],
  'Vegetable dalia':['दलिया व मूगडाळ धुऊन भाज्या बारीक चिरा.','तेल किंवा तुपात जिरे, भाज्या व दलिया थोडे परता.','डाळ, पाणी, हळद व मीठ घाला.','कुकरमध्ये मऊ होईपर्यंत शिजवा; घट्टपणा समायोजित करा.','इच्छेनुसार कोथिंबीर व लिंबू घाला.'],
  'Stuffed capsicum and chapati':['ढोबळी मिरची धुऊन देठाचा भाग व बिया काढा; आकार कायम ठेवा.','बटाटा उकडून कुस्करा; शेंगदाणे, कोथिंबीर, मीठ व मसाले मिसळा.','मिरच्यांत बटाट्याचे सारण भरा.','थोड्या तेलात झाकून मंद आचेवर मिरच्या मऊ होईपर्यंत शिजवा.','पोळीसोबत वाढा.'],
  'Tomato pithla and bhakri':['बेसन पाण्यात गुठळ्या न राहता कालवा; टोमॅटो व लसूण चिरा.','तेलात लसूण, टोमॅटो व मसाले परतून टोमॅटो मऊ करा.','पाणी व मीठ घालून मंद उकळी आणा.','बेसनाचे मिश्रण हळूहळू घालत सतत ढवळा; कच्चा वास जाईपर्यंत शिजवा.','ज्वारीची भाकरी करून गरम वाढा.'],
  'Vegetable biryani and raita':['बासमती तांदूळ धुऊन २० मिनिटे भिजवा व निथळा.','अख्खे मसाले, कांदा व भाज्या परतून दही, पुदिना व बिर्याणी मसाला घाला.','भाजीच्या मसाल्यावर तांदूळ थराने घालून मोजून गरम पाणी घाला.','झाकण घट्ट ठेवून मंद आचेवर तांदूळ व भाज्या पूर्ण शिजवा; उघडण्यापूर्वी थोडे ठेवा.','काकडी रायत्यासोबत वाढा.'],
};
List<String> recipeSteps(Meal meal, bool marathi) =>
    (marathi ? _stepsMr[meal.en] : _stepsEn[meal.en]) ??
    (marathi ? ['सर्व साहित्य स्वच्छ करून मोजून घ्या.','कांदा व मसाले परतून मुख्य साहित्य घाला.','आवश्यकतेनुसार पाणी घालून पूर्ण शिजवा.','मीठ व मसाले चवीनुसार समायोजित करा.','गरम वाढा.'] :
    ['Wash and measure all ingredients.','Sauté onion and spices, then add the main ingredients.','Add water as needed and cook until fully done.','Adjust salt and seasoning to taste.','Serve hot.']);

class FestivalMenu {
  final String en, mr, noteEn, noteMr;
  final List<Meal> meals;
  const FestivalMenu(this.en,this.mr,this.noteEn,this.noteMr,this.meals);
}
const festivalMenus = <FestivalMenu>[
  FestivalMenu('Ganesh Chaturthi','गणेश चतुर्थी','Traditional vegetarian festive meal','पारंपरिक शाकाहारी सणाचा बेत',[
    Meal('Ukadiche modak','उकडीचे मोदक',['Rice flour','Coconut','Jaggery','Cardamom','Ghee'],'Prepare coconut-jaggery filling; keep covered and make fresh dough before shaping.'),
    Meal('Puran poli and katachi amti','पुरणपोळी आणि कटाची आमटी',['Chana dal','Jaggery','Wheat flour','Cardamom','Nutmeg'],'Cook chana dal and prepare puran; knead dough and rest it.'),
    Meal('Batata bhaji and varan-bhaat','बटाटा भाजी आणि वरण-भात',['Potato','Rice','Toor dal','Cumin','Coriander'],'Wash rice and dal; boil potatoes and keep spices ready.')
  ]),
  FestivalMenu('Diwali','दिवाळी','Festive vegetarian lunch and sweets','सणाचा शाकाहारी बेत आणि गोड पदार्थ',[
    Meal('Karanji','करंजी',['Wheat flour','Coconut','Jaggery','Poppy seeds','Ghee'],'Prepare and cool the filling; knead dough and rest before shaping.'),
    Meal('Masale bhaat and batata bhaji','मसाले भात आणि बटाटा भाजी',['Rice','Mixed vegetables','Goda masala','Potato','Peanuts'],'Chop vegetables and potatoes; measure rice and spices.'),
    Meal('Shrikhand and puri','श्रीखंड आणि पुरी',['Curd','Sugar','Cardamom','Wheat flour','Ghee'],'Hang curd in the refrigerator to drain; chill before serving.')
  ]),
  FestivalMenu('Gudi Padwa','गुढीपाडवा','Maharashtrian new-year vegetarian meal','मराठी नववर्षाचा शाकाहारी बेत',[
    Meal('Shrikhand','श्रीखंड',['Curd','Sugar','Cardamom','Saffron'],'Hang curd in the refrigerator; mix with sugar and flavourings.'),
    Meal('Puran poli and amti','पुरणपोळी आणि आमटी',['Chana dal','Jaggery','Wheat flour','Cumin','Goda masala'],'Cook dal and prepare puran; knead and rest the dough.'),
    Meal('Batata bhaji, rice and koshimbir','बटाटा भाजी, भात आणि कोशिंबीर',['Potato','Rice','Cucumber','Curd','Coriander'],'Boil potatoes; wash rice and chop cucumber.')
  ]),
  FestivalMenu('Makar Sankranti','मकर संक्रांत','Til-gul themed vegetarian menu','तिळगुळाचा शाकाहारी सणाचा बेत',[
    Meal('Tilgul ladoo','तिळगुळाचे लाडू',['Sesame seeds','Jaggery','Peanuts','Cardamom'],'Roast sesame and peanuts; keep a greased plate ready before making the jaggery syrup.'),
    Meal('Bajra khichdi and kadhi','बाजरीची खिचडी आणि कढी',['Pearl millet','Moong dal','Curd','Besan','Cumin'],'Wash millet and dal; soak if needed and whisk kadhi mixture.'),
    Meal('Bhogichi bhaji and bhakri','भोगीची भाजी आणि भाकरी',['Seasonal vegetables','Peanuts','Sesame seeds','Jowar flour','Coconut'],'Wash and chop mixed vegetables; measure spices and flour.')
  ]),
  FestivalMenu('Holi','होळी','Colourful vegetarian festive meal','रंगांचा शाकाहारी सणाचा बेत',[
    Meal('Puran poli','पुरणपोळी',['Chana dal','Jaggery','Wheat flour','Cardamom'],'Cook dal until soft; prepare puran and rest the dough.'),
    Meal('Kadhi and steamed rice','कढी आणि वाफवलेला भात',['Curd','Besan','Rice','Cumin','Curry leaves'],'Whisk curd and besan smoothly; wash and soak rice briefly.'),
    Meal('Aloo sabzi and salad','बटाट्याची भाजी आणि कोशिंबीर',['Potato','Tomato','Cucumber','Coriander','Spices'],'Boil potatoes and chop salad vegetables.')
  ]),
  FestivalMenu('Eid','ईद','Festive menu with vegetarian options','शाकाहारी पर्यायांसह सणाचा बेत',[
    Meal('Sheer khurma (vegetarian)','शीर खुरमा (शाकाहारी)',['Milk','Vermicelli','Dates','Almonds','Cardamom'],'Chop nuts and dates; roast vermicelli lightly before cooking.'),
    Meal('Vegetable pulao','भाजी पुलाव',['Rice','Carrot','Beans','Peas','Whole spices'],'Wash and soak rice; chop vegetables and prepare whole spices.'),
    Meal('Paneer curry and chapati','पनीर करी आणि चपाती',['Paneer','Tomato','Onion','Wheat flour','Spices'],'Chop onion and tomato; knead chapati dough.')
  ]),
  FestivalMenu('Christmas','नाताळ','Family-friendly vegetarian festive menu','कुटुंबासाठी शाकाहारी सणाचा बेत',[
    Meal('Eggless fruit cake','अंडेविरहित फ्रूट केक',['Wheat flour','Mixed dry fruits','Sugar','Curd','Baking powder'],'Chop and soak dry fruits; preheat oven before baking.'),
    Meal('Vegetable pulao and raita','भाजी पुलाव आणि रायता',['Rice','Mixed vegetables','Curd','Cucumber','Whole spices'],'Wash rice, chop vegetables and prepare raita ingredients.'),
    Meal('Tomato soup and paneer sandwich','टोमॅटो सूप आणि पनीर सँडविच',['Tomato','Paneer','Bread','Butter','Pepper'],'Wash tomatoes; crumble paneer and prepare sandwich filling.')
  ])
];

class FestivalMenuCard extends StatelessWidget {
  const FestivalMenuCard({super.key});
  @override Widget build(BuildContext context) {
    final mr=AppStore.marathi;
    return Card(child:ExpansionTile(
      leading:const Icon(Icons.celebration),
      title:Text(mr?'सण आणि खास दिवसांचे मेनू':'Festival and special-day menus'),
      subtitle:Text(mr?'७ सणांसाठी खास शाकाहारी मेनू':'Seven curated vegetarian celebration menus'),
      children:[
        for(final festival in festivalMenus) ExpansionTile(
          title:Text(mr?festival.mr:festival.en),
          subtitle:Text(mr?festival.noteMr:festival.noteEn),
          children:[
            for(var i=0;i<festival.meals.length;i++) ListTile(
              title:Text((mr?['नाश्ता','दुपारचे जेवण','रात्रीचे जेवण'][i]:['Breakfast','Lunch','Dinner'][i])+' • '+festival.meals[i].name(mr)),
              subtitle:Text((mr?'साहित्य: ':'Ingredients: ')+festival.meals[i].ingredients.join(', ')+'\\n'+(mr?'आधीची तयारी: ':'Advance prep: ')+festival.meals[i].prep),
              isThreeLine:true
            )
          ]
        )
      ]
    ));
  }
}

class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});
  @override Widget build(BuildContext context) {
    final mr=AppStore.marathi; final all=[...breakfasts,...lunches,...dinners].toSet().toList();
    return ListView(padding:const EdgeInsets.all(12),children:[Text(mr?'पाककृती आणि साहित्य':'Recipes and ingredients',style:Theme.of(context).textTheme.titleLarge),
      for(final meal in all) Card(child:ExpansionTile(title:Text(meal.name(mr)),subtitle:Text(meal.ingredients.join(', ')),children:[
        Padding(padding:const EdgeInsets.fromLTRB(12,8,12,4),child:MealPhoto(meal:meal)),
        ListTile(title:Text(mr?'आधीची तयारी':'Preparation'),subtitle:Text(meal.prep)),
        Padding(padding:const EdgeInsets.fromLTRB(16,8,16,4),child:Text(mr?'कृती — क्रमवार':'Step-by-step cooking instructions',style:Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight:FontWeight.bold))),
        for(final entry in recipeSteps(meal,mr).asMap().entries) ListTile(dense:true,leading:CircleAvatar(radius:14,child:Text('${entry.key+1}')),title:Text(entry.value))
      ]))
    ]);
  }
}
String groceryEstimate(String item, int uses, int people) {
  const estimates = <String, String>{
    'Poha':'300 g', 'Rava':'250 g', 'Bhajani flour':'300 g', 'Idli batter':'500 g',
    'Sabudana':'300 g', 'Besan':'250 g', 'Dosa batter':'500 g',
    'Toor dal':'250 g', 'Rice':'500–700 g', 'Seasonal vegetables':'500 g',
    'Cucumber':'2 medium', 'Curd':'500 g', 'Jowar flour':'400 g',
    'Matki':'250 g', 'Paneer':'300 g', 'Wheat flour':'500 g',
    'Brinjal':'2 medium', 'Chicken':'500 g', 'Eggs':'4–6',
    'Moong dal':'250 g', 'Mixed vegetables':'400 g', 'Carrot':'2 medium',
    'Beans':'150 g', 'Peas':'150 g', 'Fish':'500 g', 'Coconut':'1 medium',
    'Onion':'3–4 medium', 'Potato':'2–3 medium', 'Tomato':'3 medium',
    'Peanuts':'100 g', 'Coriander':'1 bunch', 'Lemon':'2',
    'Curry leaves':'1 small sprig', 'Green chilli':'4–5',
    'Roasted gram':'100 g', 'Cumin':'2 tsp', 'Garlic':'1 bulb',
    'Goda masala':'2 tbsp', 'Ginger-garlic':'2 tbsp', 'Spices':'as needed',
    'Ghee':'2 tbsp', 'Papad':'4 pieces', 'Tamarind':'small lemon-sized piece',
    'Yogurt':'150 g', 'Whole spices':'2 tbsp'
  };
  final base = estimates[item] ?? 'small quantity; adjust to taste';
  final match = RegExp(r'^(\\d+(?:\\.\\d+)?)(?:–(\\d+(?:\\.\\d+)?))?\\s*(.*)$').firstMatch(base);
  if (match == null) return base + ' (adjust to taste)';
  final factor = uses * people / 4.0;
  final low = double.parse(match.group(1)!) * factor;
  final highText = match.group(2);
  final unit = match.group(3) ?? '';
  String fmt(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
  final amount = highText == null ? fmt(low) : fmt(low) + '–' + fmt(double.parse(highText) * factor);
  return amount + ' ' + unit + (uses > 1 ? ' (combined for ' + uses.toString() + ' meals)' : '');
}
class GroceryPage extends StatefulWidget { final DateTime date; const GroceryPage({super.key,required this.date}); @override State<GroceryPage> createState()=>_GroceryPageState(); }
class _GroceryPageState extends State<GroceryPage> {
  @override Widget build(BuildContext context) {
    final mr=AppStore.marathi;
    final people=AppStore.householdSize;
    final weekStart=DateTime(widget.date.year,widget.date.month,widget.date.day).subtract(Duration(days:widget.date.weekday-1));
    final weekEnd=weekStart.add(const Duration(days:6));
    final scope='\${weekStart.year}-\${weekStart.month}-\${weekStart.day}:';
    final uses=<String,int>{};
    for(var offset=0;offset<7;offset++){
      final day=weekStart.add(Duration(days:offset));
      final menu=MenuPlanner.forDate(day);
      for(final meal in menu.meals){
        for(final ingredient in meal.ingredients){
          uses.update(ingredient,(n)=>n+1,ifAbsent:()=>1);
        }
      }
    }
    final items=uses.keys.toList()..sort();
    final saved=AppStore.checkedGroceries;
    final checked=saved.where((x)=>x.startsWith(scope)).map((x)=>x.substring(scope.length)).toSet();
    final available=items.where((x)=>checked.contains(x)).toList();
    final needed=items.where((x)=>!checked.contains(x)).toList();
    String dateText(DateTime d)=>'\${d.day}/\${d.month}/\${d.year}';
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text(mr?'आठवड्याची खरेदी यादी':'Weekly shopping list',style:Theme.of(context).textTheme.titleLarge),
      Text('\${dateText(weekStart)} – \${dateText(weekEnd)} • \${items.length} \${mr?'वस्तू':'items'}'),
      Padding(padding:const EdgeInsets.only(top:6,bottom:6),child:Text(mr?'\${people} जणांसाठी ७ दिवसांचे अंदाजे प्रमाण. पाककृती आणि भुकेनुसार बदलू शकते.':'Estimated 7-day quantities for \${people} people. Amounts are scaled from a 4-person base; adjust for recipes and appetite.',style:Theme.of(context).textTheme.bodySmall)),
      const SizedBox(height:8),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.inventory_2_outlined),const SizedBox(width:8),Expanded(child:Text(mr?'घरी उपलब्ध':'Already at home',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold))),Text('\${available.length}')]),
        const SizedBox(height:6),
        if(available.isEmpty) Text(mr?'अजून कोणतीही वस्तू उपलब्ध म्हणून चिन्हांकित नाही.':'No items marked as available yet.'),
        for(final item in available) CheckboxListTile(dense:true,value:true,title:Text(item),subtitle:Text(groceryEstimate(item,uses[item]??1,people)),onChanged:(v) async {final next=AppStore.checkedGroceries;next.remove(scope+item);await AppStore.setChecked(next);setState((){});},controlAffinity:ListTileControlAffinity.leading,contentPadding:EdgeInsets.zero)
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.shopping_cart_outlined),const SizedBox(width:8),Expanded(child:Text(mr?'खरेदी करायचे':'Need to buy',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold))),Text('\${needed.length}')]),
        const SizedBox(height:6),
        if(needed.isEmpty) Text(mr?'सर्व वस्तू उपलब्ध आहेत.':'Everything is marked as available.'),
        for(final item in needed) CheckboxListTile(dense:true,value:false,title:Text(item),subtitle:Text(groceryEstimate(item,uses[item]??1,people)),onChanged:(v) async {final next=AppStore.checkedGroceries;next.add(scope+item);await AppStore.setChecked(next);setState((){});},controlAffinity:ListTileControlAffinity.leading,contentPadding:EdgeInsets.zero)
      ]))),
      OutlinedButton.icon(onPressed:() async {final next=AppStore.checkedGroceries..removeWhere((x)=>x.startsWith(scope));await AppStore.setChecked(next);setState((){});},icon:const Icon(Icons.refresh),label:Text(mr?'या आठवड्याची यादी रीसेट करा':'Reset this week’s checklist'))
    ]);
  }
}
class SettingsPage extends StatefulWidget { final VoidCallback onChanged; const SettingsPage({super.key,required this.onChanged}); @override State<SettingsPage> createState()=>_SettingsPageState(); }
class _SettingsPageState extends State<SettingsPage> {
  bool busy=false;
  @override Widget build(BuildContext context) {
    final mr=AppStore.marathi;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text(mr?'अॅप सेटिंग्ज':'App settings',style:Theme.of(context).textTheme.titleLarge),
      SwitchListTile(title:Text(mr?'मराठी भाषा':'Marathi language'),subtitle:Text('Marathi / English'),value:mr,onChanged:(v) async {await AppStore.setMarathi(v);widget.onChanged();setState((){});}),
      SwitchListTile(title:Text(mr?'दररोजची तयारी आठवण':'Daily preparation reminder'),subtitle:Text(mr?'संध्याकाळी ७:०० • भारत वेळ':'7:00 PM • India time (Asia/Kolkata)'),value:AppStore.reminders,onChanged:(v) async {await AppStore.setReminders(v);if(v){await ReminderService.refresh();}else{await ReminderService.plugin.cancelAll();}setState((){});}),
      ListTile(leading:const Icon(Icons.alarm),title:Text(mr?'आठवणी पुन्हा सेट करा':'Refresh reminder schedule'),subtitle:Text(mr?'पुढील ३० दिवस':'Rebuild next 30 days'),trailing:busy?const CircularProgressIndicator():const Icon(Icons.refresh),onTap:busy?null:() async {setState(()=>busy=true);await ReminderService.refresh();if(mounted)setState(()=>busy=false);}),
      const Divider(),
      ListTile(title:Text(mr?'कुटुंबातील सदस्य':'Household size'),subtitle:Text(mr?'${AppStore.householdSize} सदस्य':'${AppStore.householdSize} people'),trailing:DropdownButton<int>(value:AppStore.householdSize,items:List.generate(12,(i)=>DropdownMenuItem<int>(value:i+1,child:Text('${i+1}'))),onChanged:(v) async {if(v==null)return;await AppStore.setHouseholdSize(v);setState((){});widget.onChanged();})),
      ListTile(title:Text(mr?'शाकाहारी नियम':'Strict vegetarian days'),subtitle:Text(mr?'सोमवार, गुरुवार, शनिवार':'Monday, Thursday, Saturday — no meat, fish, or eggs')),
      ListTile(title:Text(mr?'मेनूची माहिती':'Menu data note'),subtitle:Text(mr?'आता अधिक पाककृतींचा संच तारखेनुसार बदलतो. तरीही ३६५ दिवसांचे सर्व १,०९५ जेवण स्लॉट स्वतंत्रपणे तयार केलेले नाहीत.':'The menu now has a larger rotating recipe bank. It is not yet 1,095 individually curated meal slots; more recipes and verified quantities are still being added.')),
      ListTile(title:Text(mr?'ऑफलाइन वापर':'Offline use'),subtitle:Text(mr?'मेनू आणि साहित्य अॅपमध्ये उपलब्ध.':'Menu and ingredients are bundled in the app.'))
    ]);
  }
}
