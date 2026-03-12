import 'package:flutter/material.dart';

class AIChatScreen extends StatefulWidget {

  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {

  final controller = TextEditingController();

  final List<Map<String,String>> messages = [];

  void sendMessage(){

    if(controller.text.isEmpty) return;

    setState(() {

      messages.add({
        "role":"user",
        "text":controller.text
      });

      messages.add({
        "role":"ai",
        "text":"I'm here for you 💜 Remember to rest and stay hydrated."
      });

    });

    controller.clear();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("AI Wellness Companion"),
      ),

      body: Column(
        children: [

          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context,i){

                final m = messages[i];

                return Align(
                  alignment: m["role"]=="user"
                      ? Alignment.centerRight
                      : Alignment.centerLeft,

                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: m["role"]=="user"
                          ? Colors.purple
                          : Colors.grey.shade300,

                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Text(
                      m["text"]!,
                      style: TextStyle(
                        color: m["role"]=="user"
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                );

              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [

                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                        hintText: "Ask something..."
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                )

              ],
            ),
          )

        ],
      ),
    );
  }
}