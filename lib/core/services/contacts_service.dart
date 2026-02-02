import '../models/api_response.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'dart:convert';

/// Contact model
class Contact {
  final String id;
  final String name;
  final String phone;
  final String countryCode; // e.g., 'IN', 'US', 'UK'
  final int priority;
  final bool isActive;

  Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.countryCode,
    required this.priority,
    required this.isActive,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      countryCode: json['countryCode'] ?? 'IN',
      priority: json['priority'] ?? 0,
      isActive: json['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'countryCode': countryCode,
    'priority': priority,
  };
}

class ContactResponse {
  final List<Contact> contacts;

  ContactResponse({required this.contacts});

  factory ContactResponse.fromJson(Map<String, dynamic> json) {
    List<Contact> contacts = [];
    if (json['contacts'] is List) {
      contacts = (json['contacts'] as List)
          .map((item) => Contact.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return ContactResponse(contacts: contacts);
  }
}

/// Contacts Service
class ContactsService {
  /// Get all emergency contacts
  static Future<ApiResponse<List<Contact>>> getContacts() async {
    try {
      final response = await ApiService.get<List<Contact>>(
        '/contacts',
        fromJson: (data) {
          if (data is Map<String, dynamic>) {
            return ContactResponse.fromJson(data).contacts;
          }
          return [];
        },
      );
      return response;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Add new emergency contact
  static Future<ApiResponse<Contact>> addContact({
    required String name,
    required String phone,
    required String countryCode,
    required int priority,
  }) async {
    try {
      final response = await ApiService.post<Contact>(
        '/contacts',
        {
          'name': name,
          'phone': phone,
          'countryCode': countryCode,
          'priority': priority,
        },
        fromJson: (data) {
          if (data is Map<String, dynamic> && data.containsKey('contact')) {
            return Contact.fromJson(data['contact']);
          }
          return Contact.fromJson(data as Map<String, dynamic>);
        },
      );
      return response;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to add contact: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Update emergency contact
  static Future<ApiResponse<Contact>> updateContact({
    required String id,
    required String name,
    required String phone,
    required String countryCode,
    required int priority,
  }) async {
    try {
      final response = await ApiService.put<Contact>(
        '/contacts/$id',
        {
          'name': name,
          'phone': phone,
          'countryCode': countryCode,
          'priority': priority,
        },
        fromJson: (data) {
          if (data is Map<String, dynamic> && data.containsKey('contact')) {
            return Contact.fromJson(data['contact']);
          }
          return Contact.fromJson(data as Map<String, dynamic>);
        },
      );
      return response;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to update contact: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Delete emergency contact
  static Future<ApiResponse<void>> deleteContact(String id) async {
    try {
      final response = await ApiService.delete('/contacts/$id');
      return response;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to delete contact: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Preload and cache emergency contacts for instant SOS access
  /// Call this after login to avoid delays during emergency
  static Future<void> preloadContacts() async {
    try {
      print('📥 Preloading emergency contacts...');
      final response = await getContacts();

      if (response.success && response.data != null) {
        // Cache contacts locally for instant access
        final contactsJson = jsonEncode(
          response.data!
              .map(
                (c) => {
                  'id': c.id,
                  'name': c.name,
                  'phone': c.phone,
                  'countryCode': c.countryCode,
                  'priority': c.priority,
                  'isActive': c.isActive,
                },
              )
              .toList(),
        );
        await StorageService.cacheContacts(contactsJson);
        print('✅ Preloaded ${response.data!.length} emergency contacts');
      } else {
        print('⚠️ No contacts to preload: ${response.message}');
      }
    } catch (e) {
      print('❌ Error preloading contacts: $e');
    }
  }

  /// Get contacts from cache (instant, no network delay)
  /// Falls back to network if cache is empty
  static Future<ApiResponse<List<Contact>>> getContactsFromCache() async {
    try {
      final cachedJson = await StorageService.getCachedContacts();

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> contactsList = jsonDecode(cachedJson);
        final contacts = contactsList
            .map((json) => Contact.fromJson(json as Map<String, dynamic>))
            .toList();
        print('✅ Loaded ${contacts.length} contacts from cache (instant)');
        return ApiResponse(
          success: true,
          data: contacts,
          message: 'Loaded from cache',
        );
      }

      // Fallback to network if no cache
      print('⚠️ No cached contacts, fetching from network...');
      return await getContacts();
    } catch (e) {
      print('❌ Error loading from cache, fetching from network: $e');
      return await getContacts();
    }
  }
}
