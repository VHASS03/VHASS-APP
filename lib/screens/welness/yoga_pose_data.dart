import 'package:flutter/material.dart';

class YogaPose {
  final String name;
  final String description;
  final List<String> steps;
  final IconData icon;
  final int holdSeconds; // How long to hold the pose
  final String category; // 'period-relief' or 'general'
  final String difficulty; // 'easy', 'medium', 'hard'

  YogaPose({
    required this.name,
    required this.description,
    required this.steps,
    required this.icon,
    this.holdSeconds = 30,
    this.category = 'general',
    this.difficulty = 'easy',
  });
}

// ─── PERIOD-RELIEF POSES ───────────────────────────

final _periodReliefPoses = {
  "Child Pose": YogaPose(
    name: "Child Pose",
    description: "A gentle resting pose that relieves cramps, lower back pain, and menstrual discomfort by stretching the hips and thighs.",
    icon: Icons.self_improvement,
    holdSeconds: 60,
    category: 'period-relief',
    difficulty: 'easy',
    steps: [
      "Kneel on the floor with toes together",
      "Sit back on your heels",
      "Separate your knees hip-width apart",
      "Exhale and lay your torso between your thighs",
      "Stretch your arms forward on the floor",
      "Rest your forehead on the mat",
      "Breathe deeply and hold for 1 minute",
    ],
  ),

  "Legs Up The Wall": YogaPose(
    name: "Legs Up The Wall",
    description: "Improves blood circulation, reduces leg fatigue, and relieves menstrual cramps by reversing blood flow gently.",
    icon: Icons.airline_seat_legroom_extra,
    holdSeconds: 120,
    category: 'period-relief',
    difficulty: 'easy',
    steps: [
      "Sit sideways next to a wall",
      "Swing your legs up against the wall as you lie back",
      "Scoot your hips as close to the wall as comfortable",
      "Rest your arms by your sides, palms facing up",
      "Close your eyes and breathe slowly",
      "Hold for 2–5 minutes",
    ],
  ),

  "Supine Twist": YogaPose(
    name: "Supine Twist",
    description: "Relieves lower back tension and bloating, gently massages internal organs to ease period discomfort.",
    icon: Icons.rotate_right,
    holdSeconds: 45,
    category: 'period-relief',
    difficulty: 'easy',
    steps: [
      "Lie flat on your back",
      "Hug your right knee into your chest",
      "Extend your left leg straight on the floor",
      "Guide your right knee across your body to the left",
      "Extend your right arm out to the side",
      "Turn your head to the right and breathe",
      "Hold for 45 seconds, then switch sides",
    ],
  ),

  "Cat-Cow Stretch": YogaPose(
    name: "Cat-Cow Stretch",
    description: "Gently warms the body and relieves menstrual cramps by flexing and extending the spine rhythmically.",
    icon: Icons.pets,
    holdSeconds: 60,
    category: 'period-relief',
    difficulty: 'easy',
    steps: [
      "Start on all fours (hands and knees)",
      "Inhale: drop your belly, lift your head and tailbone (Cow)",
      "Exhale: round your spine, tuck your chin to chest (Cat)",
      "Move slowly between the two positions",
      "Repeat 10–15 times at your own pace",
    ],
  ),

  "Reclined Butterfly": YogaPose(
    name: "Reclined Butterfly",
    description: "Opens the hips and groin, relieving tension and cramps. A deeply relaxing restorative pose.",
    icon: Icons.spa,
    holdSeconds: 120,
    category: 'period-relief',
    difficulty: 'easy',
    steps: [
      "Lie on your back",
      "Bring the soles of your feet together",
      "Let your knees fall open to the sides",
      "Place your hands on your belly or by your sides",
      "Use pillows under your knees for support if needed",
      "Close your eyes and breathe deeply for 2 minutes",
    ],
  ),
};

// ─── GENERAL / CYCLE-HEALTH POSES ──────────────────

final _generalPoses = {
  "Sun Salutation": YogaPose(
    name: "Sun Salutation",
    description: "A flowing sequence that boosts energy, strengthens the core, and improves overall cycle regularity.",
    icon: Icons.wb_sunny,
    holdSeconds: 0, // flowing sequence
    category: 'general',
    difficulty: 'medium',
    steps: [
      "Stand tall with hands at heart center",
      "Inhale: reach arms overhead",
      "Exhale: fold forward, touch the floor",
      "Inhale: half-lift with flat back",
      "Step back to plank, lower down",
      "Inhale: upward-facing dog",
      "Exhale: downward-facing dog (hold 3 breaths)",
      "Step forward and rise back to standing",
      "Repeat 3–5 rounds",
    ],
  ),

  "Warrior II": YogaPose(
    name: "Warrior II",
    description: "Builds strength in legs and core, improves stamina and balance. Great for hormonal regulation.",
    icon: Icons.fitness_center,
    holdSeconds: 30,
    category: 'general',
    difficulty: 'medium',
    steps: [
      "Stand with feet wide apart (about 4 feet)",
      "Turn your right foot out 90° and left foot slightly in",
      "Raise your arms parallel to the floor",
      "Bend your right knee over your right ankle",
      "Gaze over your right fingertips",
      "Hold for 30 seconds, then switch sides",
    ],
  ),

  "Bridge Pose": YogaPose(
    name: "Bridge Pose",
    description: "Strengthens glutes and lower back, stimulates abdominal organs, and helps regulate hormones.",
    icon: Icons.architecture,
    holdSeconds: 30,
    category: 'general',
    difficulty: 'easy',
    steps: [
      "Lie on your back with knees bent, feet flat",
      "Place arms by your sides, palms down",
      "Press your feet into the floor",
      "Lift your hips toward the ceiling",
      "Clasp your hands under your back if comfortable",
      "Hold for 30 seconds, breathing steadily",
      "Lower down slowly, one vertebra at a time",
    ],
  ),

  "Forward Fold": YogaPose(
    name: "Forward Fold",
    description: "Calms the mind, stretches hamstrings and lower back. Helps reduce anxiety and stress.",
    icon: Icons.arrow_downward,
    holdSeconds: 30,
    category: 'general',
    difficulty: 'easy',
    steps: [
      "Stand with feet hip-width apart",
      "Exhale and hinge forward at the hips",
      "Let your head hang heavy",
      "Bend your knees slightly if needed",
      "Grab opposite elbows and sway gently",
      "Hold for 30 seconds",
    ],
  ),

  "Camel Pose": YogaPose(
    name: "Camel Pose",
    description: "Opens chest and hip flexors, stretches the abdomen, and stimulates reproductive organs.",
    icon: Icons.accessibility_new,
    holdSeconds: 20,
    category: 'general',
    difficulty: 'medium',
    steps: [
      "Kneel with knees hip-width apart",
      "Place your hands on your lower back for support",
      "Inhale and lift your chest toward the ceiling",
      "Slowly lean back, reaching for your heels",
      "Keep your hips over your knees",
      "Hold for 20 seconds, then slowly come up",
    ],
  ),
};

// ─── COMBINED MAP ──────────────────────────────────

final Map<String, YogaPose> yogaPoses = {
  ..._periodReliefPoses,
  ..._generalPoses,
};

// Helper getters
List<YogaPose> get periodReliefPoses => _periodReliefPoses.values.toList();
List<YogaPose> get generalPoses => _generalPoses.values.toList();