/// Country information model
class CountryInfo {
  final String countryCode; // e.g., 'IN', 'US', 'UK'
  final String dialCode; // e.g., '+91', '+1', '+44'
  final String name; // e.g., 'India', 'United States'
  final int numberLength; // Expected phone number length (without country code)

  const CountryInfo({
    required this.countryCode,
    required this.dialCode,
    required this.name,
    required this.numberLength,
  });
}

class PhoneFormatter {
  // Supported countries mapping
  static const Map<String, CountryInfo> supportedCountries = {
    'IN': CountryInfo(
      countryCode: 'IN',
      dialCode: '+91',
      name: 'India',
      numberLength: 10,
    ),
    'US': CountryInfo(
      countryCode: 'US',
      dialCode: '+1',
      name: 'United States',
      numberLength: 10,
    ),
    'UK': CountryInfo(
      countryCode: 'UK',
      dialCode: '+44',
      name: 'United Kingdom',
      numberLength: 10,
    ),
    'CA': CountryInfo(
      countryCode: 'CA',
      dialCode: '+1',
      name: 'Canada',
      numberLength: 10,
    ),
    'AU': CountryInfo(
      countryCode: 'AU',
      dialCode: '+61',
      name: 'Australia',
      numberLength: 9,
    ),
    'SG': CountryInfo(
      countryCode: 'SG',
      dialCode: '+65',
      name: 'Singapore',
      numberLength: 8,
    ),
    'PK': CountryInfo(
      countryCode: 'PK',
      dialCode: '+92',
      name: 'Pakistan',
      numberLength: 10,
    ),
    'BD': CountryInfo(
      countryCode: 'BD',
      dialCode: '+880',
      name: 'Bangladesh',
      numberLength: 10,
    ),
  };

  /// Get all available countries as a list
  static List<CountryInfo> getAvailableCountries() {
    return supportedCountries.values.toList();
  }

  /// Format phone number based on country code
  /// Input: phoneNumber='7893214560', countryCode='IN'
  /// Output: '+91 789-321-4560'
  static String formatPhoneNumber(String phoneNumber, String countryCode) {
    final country = supportedCountries[countryCode];
    if (country == null) {
      // Default to raw number if country not found
      return phoneNumber;
    }

    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedNumber.isEmpty) {
      return '';
    }

    // Remove country code if it's already there
    String numberPart = cleanedNumber;
    if (cleanedNumber.startsWith(country.dialCode.replaceAll('+', ''))) {
      numberPart = cleanedNumber.substring(
        country.dialCode.replaceAll('+', '').length,
      );
    }

    // Format based on country-specific patterns
    return _formatByCountry(numberPart, country);
  }

  /// Country-specific formatting
  static String _formatByCountry(String number, CountryInfo country) {
    switch (country.countryCode) {
      case 'IN':
      case 'PK':
      case 'BD':
        // Format: +91 789-321-4560
        if (number.length >= 10) {
          return '${country.dialCode} ${number.substring(0, 3)}-${number.substring(3, 6)}-${number.substring(6, 10)}';
        }
        break;
      case 'US':
      case 'CA':
        // Format: +1 (789) 321-4560
        if (number.length >= 10) {
          return '${country.dialCode} (${number.substring(0, 3)}) ${number.substring(3, 6)}-${number.substring(6, 10)}';
        }
        break;
      case 'UK':
        // Format: +44 7893 214560
        if (number.length >= 10) {
          return '${country.dialCode} ${number.substring(0, 4)} ${number.substring(4, 7)} ${number.substring(7, 10)}';
        }
        break;
      case 'AU':
        // Format: +61 2 9876 5432
        if (number.length >= 9) {
          return '${country.dialCode} ${number.substring(0, 1)} ${number.substring(1, 5)} ${number.substring(5, 9)}';
        }
        break;
      case 'SG':
        // Format: +65 6789 5432
        if (number.length >= 8) {
          return '${country.dialCode} ${number.substring(0, 4)} ${number.substring(4, 8)}';
        }
        break;
    }

    // Default format if no specific format found
    return '${country.dialCode} $number';
  }

  /// Validate phone number for a specific country
  static bool isValidPhoneNumber(String phoneNumber, String countryCode) {
    final country = supportedCountries[countryCode];
    if (country == null) return false;

    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove country code if present
    String numberPart = cleanedNumber;
    if (cleanedNumber.startsWith(country.dialCode.replaceAll('+', ''))) {
      numberPart = cleanedNumber.substring(
        country.dialCode.replaceAll('+', '').length,
      );
    }

    // Check if number length matches expected length for the country
    return numberPart.length == country.numberLength;
  }

  /// Get error message for invalid phone number
  static String? validatePhoneNumber(String phoneNumber, String countryCode) {
    if (phoneNumber.isEmpty) {
      return 'Phone number is required';
    }

    final country = supportedCountries[countryCode];
    if (country == null) {
      return 'Invalid country code';
    }

    if (!isValidPhoneNumber(phoneNumber, countryCode)) {
      return 'Phone number must be ${country.numberLength} digits for ${country.name}';
    }

    return null;
  }

  /// Get raw number without formatting for making calls
  static String getRawPhoneNumber(String phoneNumber, String countryCode) {
    final country = supportedCountries[countryCode];
    if (country == null) {
      return phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    }

    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final dialCodeDigits = country.dialCode.replaceAll('+', '');

    // Remove country code if present
    if (cleanedNumber.startsWith(dialCodeDigits)) {
      return cleanedNumber.substring(dialCodeDigits.length);
    }

    return cleanedNumber;
  }

  /// Get full international format for calling
  static String getInternationalFormat(String phoneNumber, String countryCode) {
    final country = supportedCountries[countryCode];
    if (country == null) {
      return phoneNumber;
    }

    final rawNumber = getRawPhoneNumber(phoneNumber, countryCode);
    return '${country.dialCode}$rawNumber';
  }

  /// Format Indian phone number (deprecated, use formatPhoneNumber instead)
  /// Input: 7893214560
  /// Output: +91 789-321-4560
  static String formatIndianPhoneNumber(String phoneNumber) {
    return formatPhoneNumber(phoneNumber, 'IN');
  }
}
