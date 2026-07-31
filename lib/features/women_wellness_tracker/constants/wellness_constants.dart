import 'package:flutter/material.dart';

/// All enums, constant lists, and mappings for the Women Wellness Tracker module.

// ─── ENUMS ──────────────────────────────────────────────

/// Flow intensity levels for period logging
enum FlowIntensity { light, medium, heavy, veryHeavy, spotting }

/// Mood types for daily tracking
enum MoodType {
  happy,
  calm,
  excited,
  neutral,
  sad,
  depressed,
  anxious,
  angry,
  frustrated,
  stressed,
  tired,
  energetic,
}

/// Symptom types for logging
enum SymptomType {
  cramps,
  headache,
  migraine,
  acne,
  fatigue,
  bloating,
  breastTenderness,
  foodCravings,
  moodSwings,
  stress,
  anxiety,
  insomnia,
  backPain,
  jointPain,
  nausea,
  vomiting,
  diarrhea,
  constipation,
  dizziness,
  fever,
  cold,
  other,
}

/// Menstrual cycle phases
enum CyclePhase { menstrual, follicular, ovulation, luteal }

// ─── LABELS ─────────────────────────────────────────────

/// Human-readable labels for flow intensity
const Map<FlowIntensity, String> flowLabels = {
  FlowIntensity.light: 'Light',
  FlowIntensity.medium: 'Medium',
  FlowIntensity.heavy: 'Heavy',
  FlowIntensity.veryHeavy: 'Very Heavy',
  FlowIntensity.spotting: 'Spotting',
};

/// Human-readable labels for moods
const Map<MoodType, String> moodLabels = {
  MoodType.happy: 'Happy',
  MoodType.calm: 'Calm',
  MoodType.excited: 'Excited',
  MoodType.neutral: 'Neutral',
  MoodType.sad: 'Sad',
  MoodType.depressed: 'Depressed',
  MoodType.anxious: 'Anxious',
  MoodType.angry: 'Angry',
  MoodType.frustrated: 'Frustrated',
  MoodType.stressed: 'Stressed',
  MoodType.tired: 'Tired',
  MoodType.energetic: 'Energetic',
};

/// Emoji icons for moods
const Map<MoodType, String> moodEmojis = {
  MoodType.happy: '😊',
  MoodType.calm: '😌',
  MoodType.excited: '🤩',
  MoodType.neutral: '😐',
  MoodType.sad: '😢',
  MoodType.depressed: '😞',
  MoodType.anxious: '😰',
  MoodType.angry: '😡',
  MoodType.frustrated: '😤',
  MoodType.stressed: '😫',
  MoodType.tired: '😴',
  MoodType.energetic: '⚡',
};

/// Human-readable labels for symptoms
const Map<SymptomType, String> symptomLabels = {
  SymptomType.cramps: 'Cramps',
  SymptomType.headache: 'Headache',
  SymptomType.migraine: 'Migraine',
  SymptomType.acne: 'Acne',
  SymptomType.fatigue: 'Fatigue',
  SymptomType.bloating: 'Bloating',
  SymptomType.breastTenderness: 'Breast Tenderness',
  SymptomType.foodCravings: 'Food Cravings',
  SymptomType.moodSwings: 'Mood Swings',
  SymptomType.stress: 'Stress',
  SymptomType.anxiety: 'Anxiety',
  SymptomType.insomnia: 'Insomnia',
  SymptomType.backPain: 'Back Pain',
  SymptomType.jointPain: 'Joint Pain',
  SymptomType.nausea: 'Nausea',
  SymptomType.vomiting: 'Vomiting',
  SymptomType.diarrhea: 'Diarrhea',
  SymptomType.constipation: 'Constipation',
  SymptomType.dizziness: 'Dizziness',
  SymptomType.fever: 'Fever',
  SymptomType.cold: 'Cold',
  SymptomType.other: 'Other',
};

/// Icons for symptoms
const Map<SymptomType, IconData> symptomIcons = {
  SymptomType.cramps: Icons.flash_on,
  SymptomType.headache: Icons.psychology_alt,
  SymptomType.migraine: Icons.bolt,
  SymptomType.acne: Icons.face,
  SymptomType.fatigue: Icons.battery_2_bar,
  SymptomType.bloating: Icons.water_drop,
  SymptomType.breastTenderness: Icons.favorite_border,
  SymptomType.foodCravings: Icons.restaurant,
  SymptomType.moodSwings: Icons.swap_vert,
  SymptomType.stress: Icons.warning_amber,
  SymptomType.anxiety: Icons.psychology,
  SymptomType.insomnia: Icons.nightlight,
  SymptomType.backPain: Icons.accessibility_new,
  SymptomType.jointPain: Icons.settings_accessibility,
  SymptomType.nausea: Icons.sick,
  SymptomType.vomiting: Icons.sick_outlined,
  SymptomType.diarrhea: Icons.water,
  SymptomType.constipation: Icons.block,
  SymptomType.dizziness: Icons.rotate_right,
  SymptomType.fever: Icons.thermostat,
  SymptomType.cold: Icons.ac_unit,
  SymptomType.other: Icons.more_horiz,
};

/// Labels for cycle phases
const Map<CyclePhase, String> phaseLabels = {
  CyclePhase.menstrual: 'Menstrual',
  CyclePhase.follicular: 'Follicular',
  CyclePhase.ovulation: 'Ovulation',
  CyclePhase.luteal: 'Luteal',
};

/// Descriptions for cycle phases
const Map<CyclePhase, String> phaseDescriptions = {
  CyclePhase.menstrual: 'Your period is here. Rest, hydrate, and be gentle with yourself.',
  CyclePhase.follicular: 'Energy is rising! Great time for new projects and social activities.',
  CyclePhase.ovulation: 'Peak energy and fertility. You may feel more confident and outgoing.',
  CyclePhase.luteal: 'Winding down. Focus on self-care, rest, and comfort foods.',
};

/// Icons for cycle phases
const Map<CyclePhase, IconData> phaseIcons = {
  CyclePhase.menstrual: Icons.water_drop,
  CyclePhase.follicular: Icons.local_florist,
  CyclePhase.ovulation: Icons.star,
  CyclePhase.luteal: Icons.nightlight_round,
};

// ─── FLOW ICONS ─────────────────────────────────────────

/// Icons for flow intensity
const Map<FlowIntensity, IconData> flowIcons = {
  FlowIntensity.light: Icons.water_drop_outlined,
  FlowIntensity.medium: Icons.water_drop,
  FlowIntensity.heavy: Icons.opacity,
  FlowIntensity.veryHeavy: Icons.waves,
  FlowIntensity.spotting: Icons.grain,
};

// ─── STORAGE KEYS ───────────────────────────────────────

/// SharedPreferences key prefixes (all scoped by userId)
class WellnessKeys {
  static const String periodLogs = 'wwt_period_logs_';
  static const String dailyLogs = 'wwt_daily_logs_';
  static const String cycleHistory = 'wwt_cycle_history_';
  static const String settings = 'wwt_settings_';
  static const String onboarded = 'wwt_onboarded_';
}
