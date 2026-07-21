import 'package:flutter/material.dart';
import 'yoga_pose_data.dart';
import '../../core/colors.dart';

class YogaPoseScreen extends StatefulWidget {
  final YogaPose pose;

  const YogaPoseScreen({super.key, required this.pose});

  @override
  State<YogaPoseScreen> createState() => _YogaPoseScreenState();
}

class _YogaPoseScreenState extends State<YogaPoseScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (step < 0 || step >= widget.pose.steps.length) return;
    _fadeController.reverse().then((_) {
      setState(() => _currentStep = step);
      _fadeController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pose = widget.pose;
    final totalSteps = pose.steps.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          pose.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: theme.textTheme.bodyLarge?.color, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    //-------------------------------------
                    // POSE HERO CARD
                    //-------------------------------------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: pose.category == 'period-relief'
                              ? [AppColors.blush, AppColors.primary]
                              : [AppColors.lavender, AppColors.mintAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: (pose.category == 'period-relief'
                                    ? AppColors.primary
                                    : AppColors.lavender)
                                .withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(pose.icon, size: 56, color: Colors.white),
                          const SizedBox(height: 12),
                          Text(
                            pose.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Difficulty + Duration badge row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildBadge(
                                pose.difficulty.toUpperCase(),
                                Icons.speed,
                              ),
                              if (pose.holdSeconds > 0) ...[
                                const SizedBox(width: 10),
                                _buildBadge(
                                  '${pose.holdSeconds}s hold',
                                  Icons.timer,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    //-------------------------------------
                    // DESCRIPTION
                    //-------------------------------------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.lavender.withOpacity(0.08)
                            : AppColors.lavender.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.lavender
                              .withOpacity(isDark ? 0.15 : 0.12),
                        ),
                      ),
                      child: Text(
                        pose.description,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 24),

                    //-------------------------------------
                    // STEP PROGRESS INDICATOR
                    //-------------------------------------
                    Row(
                      children: List.generate(totalSteps, (i) {
                        final isActive = i == _currentStep;
                        final isDone = i < _currentStep;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _goToStep(i),
                            child: Container(
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? AppColors.mintAccent
                                    : isActive
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.grey[700]
                                            : Colors.grey[300]),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 8),

                    // Step label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step ${_currentStep + 1} of $totalSteps',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        if (_currentStep == totalSteps - 1)
                          Text(
                            '✨ Final step!',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mintAccent,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    //-------------------------------------
                    // ANIMATED STEP CARD
                    //-------------------------------------
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.card
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(
                                isDark ? 0.15 : 0.10),
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Step number circle
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.lavender,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${_currentStep + 1}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              pose.steps[_currentStep],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    //-------------------------------------
                    // ALL STEPS LIST (collapsed)
                    //-------------------------------------
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'All Steps',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(totalSteps, (i) {
                      final isActive = i == _currentStep;
                      final isDone = i < _currentStep;
                      return GestureDetector(
                        onTap: () => _goToStep(i),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withOpacity(0.10)
                                : isDone
                                    ? AppColors.mintAccent.withOpacity(0.08)
                                    : (isDark
                                        ? AppColors.card
                                        : AppColors.cardLight),
                            borderRadius: BorderRadius.circular(12),
                            border: isActive
                                ? Border.all(
                                    color: AppColors.primary.withOpacity(0.3))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDone
                                      ? AppColors.mintAccent
                                      : isActive
                                          ? AppColors.primary
                                          : (isDark
                                              ? Colors.grey[700]
                                              : Colors.grey[300]),
                                ),
                                child: Center(
                                  child: isDone
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 16)
                                      : Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isActive
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600]),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  pose.steps[i],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isDone
                                        ? AppColors.mintAccent
                                        : theme.textTheme.bodyLarge?.color,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            //-------------------------------------
            // BOTTOM NAVIGATION
            //-------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.card : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Previous
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _currentStep > 0 ? () => _goToStep(_currentStep - 1) : null,
                      icon: const Icon(Icons.arrow_back_ios, size: 16),
                      label: const Text('Previous'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Next / Done
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _currentStep < totalSteps - 1
                          ? () => _goToStep(_currentStep + 1)
                          : () => Navigator.pop(context),
                      icon: Icon(
                        _currentStep < totalSteps - 1
                            ? Icons.arrow_forward_ios
                            : Icons.check_circle,
                        size: 16,
                      ),
                      label: Text(
                        _currentStep < totalSteps - 1 ? 'Next' : 'Done!',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}