import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.init();
  await ReminderService.init();
  runApp(const HomeFoodApp());
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
  Meal('Dosa','डोसा',['Dosa batter','Potato','Onion','Coconut'],'Check batter and prepare potato masala.')
];
const lunches = <Meal>[
  Meal('Varan-bhaat, bhaji and koshimbir','वरण-भात, भाजी आणि कोशिंबीर',['Toor dal','Rice','Seasonal vegetables','Cucumber','Curd'],'Rinse dal and rice; chop vegetables.'),
  Meal('Pithla-bhakri','पिठलं-भाकरी',['Besan','Jowar flour','Garlic','Onion','Green chilli'],'Measure flour; peel garlic and chop onion.'),
  Meal('Matki usal and rice','मटकी उसळ आणि भात',['Matki','Rice','Onion','Tomato','Goda masala'],'Soak matki overnight for sprouting/softening.'),
  Meal('Paneer masala and chapati','पनीर मसाला आणि चपाती',['Paneer','Tomato','Onion','Wheat flour','Curd'],'Chop onion and tomato; knead dough if preferred.'),
  Meal('Vangi bharit and bhakri','वांग्याचे भरीत आणि भाकरी',['Brinjal','Onion','Jowar flour','Coriander','Green chilli'],'Wash brinjal and prepare bhakri flour.'),
  Meal('Chicken curry, rice and salad','चिकन रस्सा, भात आणि कोशिंबीर',['Chicken','Rice','Onion','Tomato','Ginger-garlic','Spices'],'Clean chicken and marinate; refrigerate promptly.'),
  Meal('Egg curry and chapati','अंडा करी आणि चपाती',['Eggs','Onion','Tomato','Wheat flour','Spices'],'Boil eggs; chop onion and tomato.')
];
const dinners = <Meal>[
  Meal('Moong dal khichdi and kadhi','मूगडाळ खिचडी आणि कढी',['Rice','Moong dal','Curd','Besan','Ghee'],'Rinse rice and dal; keep curd ready.'),
  Meal('Chapati, seasonal bhaji and dal','पोळी, हंगामी भाजी आणि डाळ',['Wheat flour','Seasonal vegetables','Toor dal','Garlic'],'Knead dough and chop vegetables.'),
  Meal('Masale bhaat and raita','मसाले भात आणि रायता',['Rice','Mixed vegetables','Goda masala','Curd','Cucumber'],'Chop vegetables and cucumber.'),
  Meal('Vegetable pulao and raita','भाजी पुलाव आणि रायता',['Rice','Carrot','Beans','Peas','Curd'],'Wash and chop vegetables.'),
  Meal('Dal khichdi and papad','डाळ खिचडी आणि पापड',['Rice','Moong dal','Turmeric','Ghee','Papad'],'Rinse rice and dal.'),
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
      ? (menu.strictVeg ? lunches.take(5).toList() : [...lunches, nonVegLunch])
      : (menu.strictVeg ? dinners.take(5).toList() : [...dinners, nonVegDinner]);
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
    final l = lunches[(n * 3 + 1) % (veg ? 5 : lunches.length)];
    final d = dinners[(n * 5 + 2) % (veg ? 5 : dinners.length)];
    final baseLunch = veg ? l : (n.isEven ? l : nonVegLunch);
    final baseDinner = veg ? d : (n % 3 == 0 ? nonVegDinner : d);
    Meal pick(Meal base, String slot, List<Meal> pool) {
      final name = _overrides[_key(date, slot)];
      for (final meal in pool) { if (meal.en == name) return meal; }
      return base;
    }
    return DayMenu(pick(b, 'breakfast', breakfasts), pick(baseLunch, 'lunch', veg ? lunches.take(5).toList() : [...lunches, nonVegLunch]), pick(baseDinner, 'dinner', veg ? dinners.take(5).toList() : [...dinners, nonVegDinner]), veg);
  }
}
class AppStore {
  static late SharedPreferences prefs;
  static Future<void> init() async { prefs = await SharedPreferences.getInstance(); MenuPlanner.loadOverrides(prefs.getString('meal_overrides')); }
  static bool get marathi => prefs.getBool('marathi') ?? false;
  static bool get reminders => prefs.getBool('reminders') ?? true;
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
              child:Column(children:[Text(['M','T','W','T','F','S','S'][i],style:Theme.of(context).textTheme.labelSmall),const SizedBox(height:5),Text(day.day.toString(),style:TextStyle(fontWeight:active?FontWeight.bold:FontWeight.normal))])))));
        }))
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:Text(mr?'मासिक कॅलेंडर':'Monthly calendar',style:Theme.of(context).textTheme.titleMedium)),
        CalendarDatePicker(initialDate:date,firstDate:DateTime(2025),lastDate:DateTime(2035),onDateChanged:onDate)
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
class MealCard extends StatelessWidget {
  final String title; final Meal meal; final bool marathi; final VoidCallback onChanged; final VoidCallback onReplace;
  const MealCard({super.key,required this.title,required this.meal,required this.marathi,required this.onChanged,required this.onReplace});
  @override Widget build(BuildContext context) {
    final fav=AppStore.favourites.contains(meal.en);
    return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(title,style:Theme.of(context).textTheme.labelLarge?.copyWith(color:Theme.of(context).colorScheme.primary))),IconButton(tooltip:marathi?'जेवण बदला':'Replace meal',onPressed:onReplace,icon:const Icon(Icons.shuffle)),IconButton(onPressed:() async {await AppStore.toggleFavourite(meal.en);onChanged();},icon:Icon(fav?Icons.favorite:Icons.favorite_border,color:fav?Colors.red:null))]),
      Text(meal.name(marathi),style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
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
  'Chicken pulao and salad':['Marinate chicken with yogurt, ginger-garlic, salt and spices; keep refrigerated.','Sauté whole spices and sliced onion until golden.','Add chicken and cook until the outside is no longer pink.','Add washed rice and measured hot water; cover and cook on low heat until chicken is fully cooked and rice is tender.','Rest covered for 5 minutes, fluff gently and serve with salad.']
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
  'Chicken pulao and salad':['चिकन दही, आले-लसूण, मीठ व मसाल्यांत मुरवून फ्रिजमध्ये ठेवा.','अख्खे मसाले व कांदा सोनेरी होईपर्यंत परता.','चिकन घालून बाहेरचा भाग शिजेपर्यंत परता.','धुतलेला तांदूळ व मोजून गरम पाणी घालून झाकून शिजवा; चिकन पूर्ण शिजले पाहिजे.','५ मिनिटे झाकून ठेवून हलके मोकळे करा व कोशिंबिरीसोबत वाढा.']
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
        ListTile(title:Text(mr?'आधीची तयारी':'Preparation'),subtitle:Text(meal.prep)),
        Padding(padding:const EdgeInsets.fromLTRB(16,8,16,4),child:Text(mr?'कृती — क्रमवार':'Step-by-step cooking instructions',style:Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight:FontWeight.bold))),
        for(final entry in recipeSteps(meal,mr).asMap().entries) ListTile(dense:true,leading:CircleAvatar(radius:14,child:Text('${entry.key+1}')),title:Text(entry.value))
      ]))
    ]);
  }
}
String groceryEstimate(String item) {
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
  return estimates[item] ?? 'small quantity; adjust to taste';
}

class GroceryPage extends StatefulWidget { final DateTime date; const GroceryPage({super.key,required this.date}); @override State<GroceryPage> createState()=>_GroceryPageState(); }
class _GroceryPageState extends State<GroceryPage> {
  @override Widget build(BuildContext context) {
    final mr=AppStore.marathi; final menu=MenuPlanner.forDate(widget.date); final items=menu.meals.expand((x)=>x.ingredients).toSet().toList()..sort(); final checked=AppStore.checkedGroceries;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text(mr?'खरेदी यादी':'Shopping list',style:Theme.of(context).textTheme.titleLarge),
      Text(widget.date.day.toString()+'/'+widget.date.month.toString()+'/'+widget.date.year.toString()+' • '+items.length.toString()+' '+(mr?'वस्तू':'items')),
      Padding(padding:const EdgeInsets.only(top:6,bottom:6),child:Text(mr?'४ जणांसाठी अंदाजे प्रमाण • प्रत्यक्ष भूक आणि पाककृतीनुसार बदलू शकते.':'Estimated quantities for 4 people • adjust for appetite and your recipe.',style:Theme.of(context).textTheme.bodySmall)),
      const SizedBox(height:8),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.inventory_2_outlined),const SizedBox(width:8),Expanded(child:Text(mr?'घरी उपलब्ध':'Already at home',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold))),Text('${items.where((x)=>checked.contains(x)).length}')]),
        const SizedBox(height:6),
        if(items.where((x)=>checked.contains(x)).isEmpty) Text(mr?'अजून कोणतीही वस्तू उपलब्ध म्हणून चिन्हांकित नाही.':'No items marked as available yet.'),
        for(final item in items.where((x)=>checked.contains(x))) CheckboxListTile(dense:true,value:true,title:Text(item),subtitle:Text(groceryEstimate(item)),onChanged:(v) async {final next=AppStore.checkedGroceries;next.remove(item);await AppStore.setChecked(next);setState((){});},controlAffinity:ListTileControlAffinity.leading,contentPadding:EdgeInsets.zero)
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.shopping_cart_outlined),const SizedBox(width:8),Expanded(child:Text(mr?'खरेदी करायचे':'Need to buy',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold))),Text('${items.where((x)=>!checked.contains(x)).length}')]),
        const SizedBox(height:6),
        if(items.where((x)=>!checked.contains(x)).isEmpty) Text(mr?'सर्व वस्तू घरी उपलब्ध आहेत.':'Everything is marked as available.'),
        for(final item in items.where((x)=>!checked.contains(x))) CheckboxListTile(dense:true,value:false,title:Text(item),subtitle:Text(groceryEstimate(item)),onChanged:(v) async {final next=AppStore.checkedGroceries;next.add(item);await AppStore.setChecked(next);setState((){});},controlAffinity:ListTileControlAffinity.leading,contentPadding:EdgeInsets.zero)
      ]))),
      OutlinedButton.icon(onPressed:() async {await AppStore.setChecked({});setState((){});},icon:const Icon(Icons.refresh),label:Text(mr?'यादी रीसेट करा':'Reset checklist'))
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
      ListTile(title:Text(mr?'कुटुंबातील सदस्य':'Household size'),subtitle:const Text('4 people')),
      ListTile(title:Text(mr?'शाकाहारी नियम':'Strict vegetarian days'),subtitle:Text(mr?'सोमवार, गुरुवार, शनिवार':'Monday, Thursday, Saturday — no meat, fish, or eggs')),
      ListTile(title:Text(mr?'मेनूची माहिती':'Menu data note'),subtitle:Text(mr?'सध्या मर्यादित पाककृतींचा संच तारखेनुसार फिरवला जातो.':'Current menu rotates a starter recipe bank; it is not yet a fully curated unique 365-day menu.')),
      ListTile(title:Text(mr?'ऑफलाइन वापर':'Offline use'),subtitle:Text(mr?'मेनू आणि साहित्य अॅपमध्ये उपलब्ध.':'Menu and ingredients are bundled in the app.'))
    ]);
  }
}
