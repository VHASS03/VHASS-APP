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

    final daysLeft =
        _nextPeriodDate.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF9146FF), Color(0xFF6A1B9A)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Next Period In",
            style: TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 8),

          Text(
            "$daysLeft Days",
            style: const TextStyle(
                fontSize: 34,
                color: Colors.white,
                fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Text(
            "Expected ${DateFormat('MMM dd').format(_nextPeriodDate)}",
            style: const TextStyle(color: Colors.white70),
          )
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

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: symptoms.map((s) {

        final selected = _selectedSymptoms.contains(s);

        return ChoiceChip(
          label: Text(s),
          selected: selected,
          onSelected: (val) {

            setState(() {

              if (val) {
                _selectedSymptoms.add(s);
              } else {
                _selectedSymptoms.remove(s);
              }

            });

          },
        );

      }).toList(),
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

    floatingActionButton: Column(
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