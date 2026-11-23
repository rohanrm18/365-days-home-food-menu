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
  static bool isStrictVeg(DateTime d) => [DateTime.monday, DateTime.thursday, DateTime.saturday].contains(d.weekday);
  static DayMenu forDate(DateTime date) {
    final n = DateTime(date.year,date.month,date.day).difference(DateTime(2026,1,1)).inDays.abs();
    final veg = isStrictVeg(date);
    final b = breakfasts[n % breakfasts.length];
    final l = lunches[(n * 3 + 1) % lunches.length];
    final d = dinners[(n * 5 + 2) % dinners.length];
    return DayMenu(b, veg ? l : (n.isEven ? l : nonVegLunch), veg ? d : (n % 3 == 0 ? nonVegDinner : d), veg);
  }
}
class AppStore {
  static late SharedPreferences prefs;
  static Future<void> init() async { prefs = await SharedPreferences.getInstance(); }
  static bool get marathi => prefs.getBool('marathi') ?? false;
  static bool get reminders => prefs.getBool('reminders') ?? true;
  static Future<void> setMarathi(bool v) async { await prefs.setBool('marathi',v); }
  static Future<void> setReminders(bool v) async { await prefs.setBool('reminders',v); }
  static Set<String> get checkedGroceries => (prefs.getStringList('checked_groceries') ?? []).toSet();
  static Future<void> setChecked(Set<String> v) async { await prefs.setStringList('checked_groceries',v.toList()); }
  static List<String> get favourites => prefs.getStringList('favourites') ?? [];
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
      final when = tz.TZDateTime(tz.local,date.year,date.month,date.day,19);
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
      Card(child:ListTile(leading:const Icon(Icons.event),title:Text(date.day.toString()+'/'+date.month.toString()+'/'+date.year.toString()),subtitle:Text(menu.strictVeg?(mr?'कडक शाकाहारी दिवस':'Strict vegetarian day'):(mr?'शाकाहारी आणि मांसाहारी पर्याय':'Vegetarian and non-vegetarian options')),trailing:const Icon(Icons.calendar_month),onTap:() async { final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(2025),lastDate:DateTime(2035)); if(d!=null) onDate(d); })),
      const SizedBox(height:8),
      MealCard(title:mr?'नाश्ता':'Breakfast',meal:menu.breakfast,marathi:mr,onChanged:onChanged),
      MealCard(title:mr?'दुपारचे जेवण':'Lunch',meal:menu.lunch,marathi:mr,onChanged:onChanged),
      MealCard(title:mr?'रात्रीचे जेवण':'Dinner',meal:menu.dinner,marathi:mr,onChanged:onChanged),
      Card(color:Theme.of(context).colorScheme.secondaryContainer,child:ListTile(leading:const Icon(Icons.notifications_active),title:Text(mr?'उद्याच्या तयारीची आठवण':'Tomorrow preparation reminder'),subtitle:Text(mr?'संध्याकाळी ७:०० वाजता':'Daily at 7:00 PM India time')))
    ]);
  }
}
class MealCard extends StatelessWidget {
  final String title; final Meal meal; final bool marathi; final VoidCallback onChanged;
  const MealCard({super.key,required this.title,required this.meal,required this.marathi,required this.onChanged});
  @override Widget build(BuildContext context) {
    final fav=AppStore.favourites.contains(meal.en);
    return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(title,style:Theme.of(context).textTheme.labelLarge?.copyWith(color:Theme.of(context).colorScheme.primary))),IconButton(onPressed:() async {await AppStore.toggleFavourite(meal.en);onChanged();},icon:Icon(fav?Icons.favorite:Icons.favorite_border,color:fav?Colors.red:null))]),
      Text(meal.name(marathi),style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
      const SizedBox(height:6),Text((marathi?'साहित्य: ':'Ingredients: ')+meal.ingredients.join(', ')),
      Text((marathi?'आधीची तयारी: ':'Advance prep: ')+meal.prep)
    ]))));
  }
}
class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});
  @override Widget build(BuildContext context) {
    final mr=AppStore.marathi; final all=[...breakfasts,...lunches,...dinners].toSet().toList();
    return ListView(padding:const EdgeInsets.all(12),children:[Text(mr?'पाककृती आणि साहित्य':'Recipes and ingredients',style:Theme.of(context).textTheme.titleLarge),
      for(final meal in all) Card(child:ExpansionTile(title:Text(meal.name(mr)),subtitle:Text(meal.ingredients.join(', ')),children:[
        ListTile(title:Text(mr?'आधीची तयारी':'Preparation'),subtitle:Text(meal.prep)),
        ListTile(title:Text(mr?'कृती':'Cooking guidance'),subtitle:Text(mr?'साहित्य तयार करून घरगुती पद्धतीने शिजवा. चवीनुसार मसाले आणि मीठ समायोजित करा.':'Prepare the listed ingredients, cook using your usual home method, and adjust spices and salt to taste.'))
      ]))
    ]);
  }
}
class GroceryPage extends StatefulWidget { final DateTime date; const GroceryPage({super.key,required this.date}); @override State<GroceryPage> createState()=>_GroceryPageState(); }
class _GroceryPageState extends State<GroceryPage> {
  @override Widget build(BuildContext context) {
    final mr=AppStore.marathi; final menu=MenuPlanner.forDate(widget.date); final items=menu.meals.expand((x)=>x.ingredients).toSet().toList()..sort(); final checked=AppStore.checkedGroceries;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text(mr?'खरेदी यादी':'Shopping list',style:Theme.of(context).textTheme.titleLarge),
      Text(widget.date.day.toString()+'/'+widget.date.month.toString()+'/'+widget.date.year.toString()+' • '+items.length.toString()+' '+(mr?'वस्तू':'items')),
      const SizedBox(height:8),
      for(final item in items) CheckboxListTile(value:checked.contains(item),title:Text(item),subtitle:Text(checked.contains(item)?(mr?'घरी उपलब्ध':'Already available'):(mr?'खरेदी करायचे':'Need to buy')),onChanged:(v) async {final next=AppStore.checkedGroceries;if(v==true){next.add(item);}else{next.remove(item);}await AppStore.setChecked(next);setState((){});},controlAffinity:ListTileControlAffinity.leading),
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
