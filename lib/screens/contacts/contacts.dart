import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/contacts_service.dart';
import '../../core/utils/phone_formatter.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  bool _isLoading = false;

  // Native method channel for automatic calls
  static const platform = MethodChannel('com.example.my_app/dialer');

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    print('🔵 Loading contacts...');
    final response = await ContactsService.getContacts();
    print('🟡 Contacts response: ${response.success} - ${response.message}');

    if (response.success && response.data != null) {
      setState(() {
        _contacts = response.data ?? [];
        _isLoading = false;
      });
    } else {
      if (mounted) {
        final errorMsg = response.message ?? 'Failed to load contacts';

        // Show additional debug info for token issues
        if (errorMsg.contains('No token') || errorMsg.contains('token')) {
          print('❌ Token Issue Detected: $errorMsg');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Authentication error: $errorMsg. Please login again.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeContact(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Contact'),
        content: const Text('Are you sure you want to remove this contact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final contact = _contacts[index];
              final response = await ContactsService.deleteContact(contact.id);
              if (response.success) {
                setState(() {
                  _contacts.removeAt(index);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact removed')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      response.message ?? 'Failed to remove contact',
                    ),
                  ),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _callContact(String phoneNumber) async {
    // Remove any non-digit characters from phone number
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid phone number')));
      }
      return;
    }

    print('📞 Attempting to call: $cleanedNumber');

    // Request call permission
    print('📞 Requesting CALL_PHONE permission...');
    final callPermission = await Permission.phone.request();

    if (callPermission.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call permission is required to make calls'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      print('❌ Call permission denied');
      return;
    } else if (callPermission.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Call permission is permanently denied. Please enable it in app settings to make calls.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      print('❌ Call permission permanently denied');
      return;
    }

    // Use native method to make automatic call
    try {
      final result = await platform.invokeMethod('makeCall', {
        'phoneNumber': cleanedNumber,
      });
      if (result == true) {
        print('✅ Call initiated automatically to: $cleanedNumber');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calling...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('❌ Failed to initiate call');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initiate call'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } on PlatformException catch (e) {
      print('❌ Platform exception: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calling contact: ${e.message}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calling contact: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print('❌ Error: $e');
    }
  }

  void _addContact() {
    showDialog(
      context: context,
      builder: (context) => _AddContactDialog(
        onAdd: (name, phone, countryCode, priority) async {
          final response = await ContactsService.addContact(
            name: name,
            phone: phone,
            priority: priority,
            countryCode: countryCode,
          );
          if (response.success && response.data != null) {
            setState(() {
              _contacts.add(response.data!);
              _contacts.sort((a, b) => a.priority.compareTo(b.priority));
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contact added successfully')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.message ?? 'Failed to add contact'),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFull = _contacts.length >= 3;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: theme.textTheme.bodyLarge?.color,
            ),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            Text(
              'Add up to 3 trusted contacts',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.blueGrey : Colors.blueGrey[600],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Contacts will be called in priority order. First to answer becomes the primary contact.',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFB0A0C0)
                                  : Colors.black87,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _contacts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_add_outlined,
                                  size: 48,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No emergency contacts yet',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _contacts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final contact = _contacts[index];
                              return _buildContactTile(
                                index,
                                contact,
                                theme,
                                isDark,
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: isFull ? null : _addContact,
                        icon: Icon(
                          isFull ? Icons.block : Icons.person_add_alt_1,
                          color: Colors.white,
                        ),
                        label: Text(
                          isFull
                              ? 'Maximum contacts added'
                              : 'Add Emergency Contact',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          disabledBackgroundColor: isDark
                              ? const Color(0xFF2D1B3D)
                              : Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildContactTile(
    int index,
    Contact contact,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.textTheme.bodyLarge!.color!.withOpacity(0.05),
        ),
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
            child: Text(
              '${contact.priority}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      color: Colors.grey,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        PhoneFormatter.formatPhoneNumber(
                          contact.phone,
                          contact.countryCode,
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey[700],
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _callContact(contact.phone),
            icon: const Icon(
              Icons.phone_outlined,
              color: Colors.green,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.green.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _removeContact(index),
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: theme.textTheme.bodyLarge!.color!.withOpacity(
                0.05,
              ),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddContactDialog extends StatefulWidget {
  final Function(String name, String phone, String countryCode, int priority)
  onAdd;

  const _AddContactDialog({required this.onAdd});

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  int _selectedPriority = 1;
  String _selectedCountry = 'IN';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _phoneController.addListener(() {
      setState(() {}); // Update max length based on country
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  int _getMaxPhoneLength() {
    final country = PhoneFormatter.supportedCountries[_selectedCountry];
    return country?.numberLength ?? 10;
  }

  String? _validatePhoneNumber(String value) {
    return PhoneFormatter.validatePhoneNumber(value, _selectedCountry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countries = PhoneFormatter.getAvailableCountries();

    return AlertDialog(
      title: const Text('Add Emergency Contact'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Contact Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                hintText: 'e.g., Mom, Dad, Sister',
              ),
            ),
            const SizedBox(height: 20),

            // Country Selection
            DropdownButtonFormField<String>(
              value: _selectedCountry,
              decoration: const InputDecoration(
                labelText: 'Country',
                prefixIcon: Icon(Icons.public),
              ),
              items: countries.map((country) {
                return DropdownMenuItem(
                  value: country.countryCode,
                  child: Text('${country.name} (${country.dialCode})'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCountry = value;
                    _phoneController.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Phone Number
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText:
                    'e.g., ${_selectedCountry == 'US'
                        ? '1234567890'
                        : _selectedCountry == 'UK'
                        ? '9876543210'
                        : '9876543210'}',
                helperText: 'Enter ${_getMaxPhoneLength()} digits',
                errorText: _phoneController.text.isNotEmpty
                    ? _validatePhoneNumber(_phoneController.text)
                    : null,
              ),
              maxLength: _getMaxPhoneLength(),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Priority
            DropdownButtonFormField<int>(
              value: _selectedPriority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Priority 1 (First)')),
                DropdownMenuItem(value: 2, child: Text('Priority 2 (Second)')),
                DropdownMenuItem(value: 3, child: Text('Priority 3 (Third)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPriority = value;
                  });
                }
              },
            ),

            // Show formatted number preview
            if (_phoneController.text.isNotEmpty &&
                _validatePhoneNumber(_phoneController.text) == null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phone Number:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        PhoneFormatter.formatPhoneNumber(
                          _phoneController.text,
                          _selectedCountry,
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _isLoading || _validatePhoneNumber(_phoneController.text) != null
              ? null
              : () async {
                  if (_nameController.text.isEmpty ||
                      _phoneController.text.isEmpty ||
                      _validatePhoneNumber(_phoneController.text) != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all fields correctly'),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _isLoading = true;
                  });

                  widget.onAdd(
                    _nameController.text,
                    _phoneController.text,
                    _selectedCountry,
                    _selectedPriority,
                  );

                  Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.scaffoldBackgroundColor,
                    ),
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
