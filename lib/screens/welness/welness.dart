import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'yoga_pose_screen.dart';
import 'yoga_pose_data.dart';
import 'ai_chat_screen.dart';



class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  String _healthCondition = "None";

final conditions = [
  "None",
  "PCOS",
  "PCOD",
  "Irregular Periods",
  "Endometriosis"
];
@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _showSetupDialog();
  });
}
void _showSetupDialog() {

  DateTime selectedDate = _lastPeriodDate;

  final periodController =
      TextEditingController(text: _periodLength.toString());

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {

      return StatefulBuilder(
        builder: (context, setDialogState) {

          return AlertDialog(
            title: const Text("Health Setup"),

            content: SingleChildScrollView(
              child: Column(
                children: [

                  //--------------------------------
                  // HEALTH CONDITION
                  //--------------------------------

                  DropdownButtonFormField<String>(
                    value: _healthCondition,
                    items: conditions
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        _healthCondition = val!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Health Condition",
                    ),
                  ),

                  const SizedBox(height: 16),

                  //--------------------------------
                  // LAST PERIOD DATE
                  //--------------------------------

                  ListTile(
                    title: const Text("Last Period Start"),
                    subtitle:
                        Text(DateFormat("MMM dd yyyy").format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {

                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );

                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  //--------------------------------
                  // PERIOD LENGTH
                  //--------------------------------

                  TextField(
                    controller: periodController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Period Length (days)",
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            actions: [

              ElevatedButton(
                onPressed: () {

                  setState(() {
                    _lastPeriodDate = selectedDate;
                    _cycleLength = 28;
                    _periodLength = int.tryParse(periodController.text) ?? 5;
                  });

                  Navigator.pop(context);
                },
                child: const Text("Save"),
              )

            ],
          );
        },
      );
    },
  );
}

  DateTime _lastPeriodDate = DateTime.now().subtract(const Duration(days: 2));
  int _cycleLength = 28;
  int _periodLength = 5;

  List<String> _selectedSymptoms = [];
  List<Map<String, dynamic>> _notes = [];

  final symptoms = [
    "Cramps",
    "Headache",
    "Bloating",
    "Fatigue",
    "Mood Swings",
    "Acne",
    "Cravings"
  ];

  //------------------------------------------
  // CYCLE CALCULATIONS
  //------------------------------------------

  DateTime get _nextPeriodDate =>
      _lastPeriodDate.add(Duration(days: _cycleLength));

  String get _cyclePhase {

    final diff = DateTime.now().difference(_lastPeriodDate).inDays % _cycleLength;

    if (diff < _periodLength) return "Menstrual";
    if (diff < 13) return "Follicular";
    if (diff < 16) return "Ovulation";

    return "Luteal";
  }

  //------------------------------------------
  // RECOMMENDATIONS
  //------------------------------------------

  Map<String, List<String>> get _recommendations {

    switch (_cyclePhase) {

      case "Menstrual":
        return {
          "yoga": [
            "Child Pose",
            "Legs Up The Wall",
            "Supine Twist"
          ],
          "remedies": [
            "Drink ginger tea",
            "Use heating pad",
            "Eat magnesium rich foods"
          ]
        };

      case "Follicular":
        return {
          "yoga": [
            "Sun Salutation",
            "Warrior II"
          ],
          "remedies": [
            "Start strength training",
            "Eat protein rich meals"
          ]
        };

      case "Ovulation":
        return {
          "yoga": [
            "Bridge Pose",
            "Camel Pose"
          ],
          "remedies": [
            "High energy workouts",
            "Stay hydrated"
          ]
        };

      default:
        return {
          "yoga": [
            "Forward Fold",
            "Cat Cow"
          ],
          "remedies": [
            "Reduce caffeine",
            "Get good sleep"
          ]
        };
    }
  }

  //------------------------------------------
  // NOTE DIALOG
  //------------------------------------------

  void _addNote() {

    final controller = TextEditingController();

    showDialog(
        context: context,
        builder: (context) {

          return AlertDialog(
            title: const Text("Log Health Note"),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration:
              const InputDecoration(hintText: "Symptoms or mood..."),
            ),
            actions: [

              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),

              ElevatedButton(
                  onPressed: () {

                    if (controller.text.isNotEmpty) {

                      setState(() {
                        _notes.insert(0, {
                          "text": controller.text,
                          "date": DateTime.now()
                        });
                      });

                    }

                    Navigator.pop(context);
                  },
                  child: const Text("Save"))
            ],
          );
        });
  }

  //------------------------------------------
  // DASHBOARD CARD
  //------------------------------------------
Widget _cycleDashboard() {

  final today = DateTime.now();

  final diff =
      today.difference(_lastPeriodDate).inDays % _cycleLength;

  final bool isOnPeriod = diff < _periodLength;

  final int periodDay = diff + 1;

  final daysLeft =
      _nextPeriodDate.difference(today).inDays;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF9146FF), Color(0xFF6A1B9A)],
      ),
      borderRadius: BorderRadius.circular(12),
    ),

    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        //----------------------------------
        // MAIN ROW
        //----------------------------------

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text(
                  "Next Period",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  isOnPeriod
                      ? "Day $periodDay of your period"
                      : "$daysLeft Days",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [

                const Text(
                  "Expected On",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  DateFormat('MMM dd').format(_nextPeriodDate),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),

        //----------------------------------
        // PERIOD PROGRESS BAR
        //----------------------------------

        if (isOnPeriod) ...[
          const SizedBox(height: 12),

          LinearProgressIndicator(
            value: periodDay / _periodLength,
            backgroundColor: Colors.white24,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ],
      ],
    ),
  );
}
  //------------------------------------------
  // PHASE CARD
  //------------------------------------------

  Widget _phaseCard() {

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [

          const Icon(Icons.auto_graph, color: Colors.pink),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text(
                "Current Phase",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              Text(_cyclePhase)

            ],
          )
        ],
      ),
    );
  }

  //------------------------------------------
  // SYMPTOM TRACKER
  //------------------------------------------
Widget _symptomTracker() {

  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  final Map<String, IconData> symptomIcons = {
    "Cramps": Icons.bolt,
    "Headache": Icons.psychology,
    "Bloating": Icons.air,
    "Fatigue": Icons.bedtime,
    "Mood Swings": Icons.mood,
    "Acne": Icons.face,
    "Cravings": Icons.fastfood,
  };

  return SizedBox(
    height: 90,

    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: symptoms.length,

      itemBuilder: (context, index) {

        final symptom = symptoms[index];
        final selected = _selectedSymptoms.contains(symptom);

        return GestureDetector(
          onTap: () {

            setState(() {

              if (selected) {
                _selectedSymptoms.remove(symptom);
              } else {
                _selectedSymptoms.add(symptom);
              }

            });

          },

          child: Container(
            width: 90,
            margin: const EdgeInsets.only(right: 12),

            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFE91E63)
                  : theme.cardColor,

              borderRadius: BorderRadius.circular(20),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                )
              ],
            ),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Icon(
                  symptomIcons[symptom],
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black),
                  size: 28,
                ),

                const SizedBox(height: 6),

                Text(
                  symptom,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
  //------------------------------------------
  // RECOMMENDATION CARD
  //------------------------------------------

  Widget _recommendationCard() {

    final rec = _recommendations;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Yoga Suggestions",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          ...rec["yoga"]!.map((e) {

              return ListTile(
                leading: const Icon(Icons.self_improvement),

                title: Text(e),

                trailing: const Icon(Icons.play_circle),

                onTap: () {

                  final pose = yogaPoses[e];

                  if (pose != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => YogaPoseScreen(pose: pose),
                      ),
                    );
                  }
                },
              );

            }),

          const SizedBox(height: 12),

          const Text(
            "Natural Remedies",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          ...rec["remedies"]!.map((e) =>
              ListTile(
                leading: const Icon(Icons.spa),
                title: Text(e),
              )),
        ],
      ),
    );
  }

  //------------------------------------------
  // CALENDAR
  //------------------------------------------
Widget _calendar() {
  return TableCalendar(
    firstDay: DateTime.utc(2020),
    lastDay: DateTime.utc(2035),
    focusedDay: DateTime.now(),

    rowHeight: 46, // increases space for weekday row

    daysOfWeekHeight: 22, // ensures weekday text is fully visible

    headerStyle: const HeaderStyle(
      formatButtonVisible: false,
      titleCentered: true,
    ),

    calendarStyle: const CalendarStyle(
      cellMargin: EdgeInsets.all(4),
    ),

    calendarBuilders: CalendarBuilders(
      defaultBuilder: (context, date, _) {

        final diff =
            date.difference(_lastPeriodDate).inDays % _cycleLength;

        if (diff < _periodLength) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.pinkAccent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                "${date.day}",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        return null;
      },
    ),
  );
}
  //------------------------------------------
  // NOTES
  //------------------------------------------

  Widget _notesList() {

    return Column(
      children: _notes.map((note) {

        return ListTile(
          title: Text(note["text"]),
          subtitle: Text(
              DateFormat("MMM dd hh:mm").format(note["date"])),
        );

      }).toList(),
    );
  }

  //------------------------------------------
  // UI
  //------------------------------------------

 @override
Widget build(BuildContext context) {

  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Scaffold(
    appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: const Text("Women Wellness"),
      centerTitle: false,
    ),

    //-------------------------------------
    // FLOATING BUTTONS
    //-------------------------------------
    floatingActionButton: Align(
  alignment: Alignment.bottomRight,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      FloatingActionButton(
        heroTag: "add_note",
        onPressed: _addNote,
        backgroundColor: const Color(0xFFE91E63),
        child: const Icon(Icons.add),
      ),

      const SizedBox(height: 12),

      FloatingActionButton.extended(
        heroTag: "ai_companion",
        icon: const Icon(Icons.smart_toy),
        label: const Text("AI Companion"),
        backgroundColor: const Color(0xFF9146FF),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AIChatScreen(),
            ),
          );
        },
      ),
    ],
  ),
),
        


    //-------------------------------------
    // BODY
    //-------------------------------------

    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            //-------------------------------------
            // CYCLE DASHBOARD
            //-------------------------------------

            _cycleDashboard(),

            const SizedBox(height: 20),

            //-------------------------------------
            // PHASE CARD
            //-------------------------------------

            _phaseCard(),

            const SizedBox(height: 20),

            //-------------------------------------
            // CALENDAR
            //-------------------------------------

            _calendar(),

            const SizedBox(height: 24),

            //-------------------------------------
            // SYMPTOMS
            //-------------------------------------

            Text(
              "Track Symptoms",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _symptomTracker(),

            const SizedBox(height: 24),

            //-------------------------------------
            // YOGA + REMEDIES
            //-------------------------------------

            Text(
              "Wellness Suggestions",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _recommendationCard(),

            const SizedBox(height: 24),

            //-------------------------------------
            // NOTES
            //-------------------------------------

            Text(
              "Health Notes",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _notesList(),

            const SizedBox(height: 80),

          ],
        ),
      ),
    ),
  );
}
}