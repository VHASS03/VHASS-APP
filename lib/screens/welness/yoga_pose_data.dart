class YogaPose {

  final String name;
  final String animation;
  final String description;
  final List<String> steps;

  YogaPose({
    required this.name,
    required this.animation,
    required this.description,
    required this.steps
  });

}

final yogaPoses = {

  "Child Pose": YogaPose(
    name: "Child Pose",
    animation: "assets/yoga/child_pose.json",
    description: "A relaxing pose that reduces cramps and stress.",
    steps: [
      "Kneel on the floor",
      "Sit back on your heels",
      "Stretch arms forward",
      "Relax your head on the mat"
    ]
  ),

  "Legs Up The Wall": YogaPose(
    name: "Legs Up The Wall",
    animation: "assets/yoga/legs_wall.json",
    description: "Improves blood flow and reduces fatigue.",
    steps: [
      "Lie on your back",
      "Lift legs against a wall",
      "Keep arms relaxed",
      "Breathe deeply"
    ]
  ),

  "Supine Twist": YogaPose(
    name: "Supine Twist",
    animation: "assets/yoga/supine_twist.json",
    description: "Relieves lower back tension.",
    steps: [
      "Lie on your back",
      "Bring knee to chest",
      "Twist body sideways",
      "Hold and breathe"
    ]
  ),

};