import 'package:flutter/material.dart';
import '../../core/colors.dart';

class ContactModel {
  final String name;
  final String phone;
  ContactModel(this.name, this.phone);
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<ContactModel> _contacts = [
    ContactModel('Mom', '+91 98765 43210'),
    ContactModel('Dad', '+91 98765 43211'),
    ContactModel('Sister', '+91 98765 43212'),
  ];

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
  }

  void _addContact() {
    if (_contacts.length < 3) {
      setState(() {
        _contacts.add(ContactModel('New Contact', '+91 00000 00000'));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFull = _contacts.length >= 3;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // CHANGE 1: Use theme background
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            // CHANGE 2: Dynamic icon color
            icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Contacts',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                // CHANGE 3: Dynamic text color
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            Text(
              'Add up to 3 trusted contacts',
              style: TextStyle(
                fontSize: 12, 
                // CHANGE 4: Dynamic subtitle color
                color: isDark ? Colors.blueGrey : Colors.blueGrey[600],
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // --- PRIORITY INFO BANNER ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // CHANGE 5: Dynamic banner background (purple tint)
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Contacts will be called in priority order. First to answer becomes the primary contact.',
                      style: TextStyle(
                        // CHANGE 6: Dynamic banner text color
                        color: isDark ? const Color(0xFFB0A0C0) : Colors.black87, 
                        fontSize: 13, 
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // --- DYNAMIC CONTACT LIST ---
            Expanded(
              child: ListView.separated(
                itemCount: _contacts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildContactTile(index, _contacts[index].name, _contacts[index].phone, theme, isDark);
                },
              ),
            ),

            // --- ADD CONTACT BUTTON ---
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isFull ? null : _addContact,
                  icon: Icon(
                    isFull ? Icons.block : Icons.person_add_alt_1, 
                    color: Colors.white // Keep white as it's on a primary color background
                  ),
                  label: Text(
                    isFull ? 'Maximum contacts added' : 'Add Emergency Contact',
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 16, 
                      fontWeight: FontWeight.w600
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    // CHANGE 7: Use primary color from theme
                    backgroundColor: theme.colorScheme.primary,
                    disabledBackgroundColor: isDark ? const Color(0xFF2D1B3D) : Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(int index, String name, String phone, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // CHANGE 8: Dynamic card color
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textTheme.bodyLarge!.color!.withOpacity(0.05)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            radius: 24,
            child: const Icon(Icons.star, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    // CHANGE 9: Dynamic name color
                    color: theme.textTheme.bodyLarge?.color, 
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, color: Colors.grey, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      // CHANGE 10: Dynamic phone color
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey[700], 
                        fontSize: 14
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeContact(index),
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            style: IconButton.styleFrom(
              // CHANGE 11: Dynamic button background
              backgroundColor: theme.textTheme.bodyLarge!.color!.withOpacity(0.05),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}