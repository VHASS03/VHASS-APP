import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'yoga_pose_data.dart';

class YogaPoseScreen extends StatelessWidget {

  final YogaPose pose;

  const YogaPoseScreen({super.key, required this.pose});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: Text(pose.name),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            Expanded(
              child: Lottie.asset(
                pose.animation,
                repeat: true,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              pose.description,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Steps",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            ...pose.steps.map(
                  (step) => ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text(step),
              ),
            )

          ],
        ),
      ),
    );
  }
}