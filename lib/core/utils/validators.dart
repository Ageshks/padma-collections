/// Form validators shared by the customer and admin forms.
///
/// All messages are written for end users, never developers.
class AppValidators {
  AppValidators._();

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? name(String? value, {String field = 'Name'}) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return '$field is required';
    if (v.length < 2) return '$field must be at least 2 characters';
    if (v.length > 60) return '$field must be under 60 characters';
    return null;
  }

  static String? email(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required';
    // Deliberately permissive: Firebase is the real authority on validity.
    final RegExp re = RegExp(r'^[\w.+\-]+@[\w\-]+\.[\w\-.]+$');
    if (!re.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (v.length > 72) return 'Password must be under 72 characters';
    return null;
  }

  /// Registration is stricter than login, to keep accounts secure.
  static String? strongPassword(String? value) {
    final String? basic = password(value);
    if (basic != null) return basic;
    final String v = value!;
    final bool hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
    final bool hasDigit = RegExp(r'\d').hasMatch(v);
    if (!hasLetter || !hasDigit) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  /// Accepts 10-digit Indian numbers, optionally with +91 / spaces.
  static String? phone(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 'Phone number is required';
    if (digits.length == 12 && digits.startsWith('91')) {
      // valid with country code
    } else if (digits.length != 10) {
      return 'Enter a valid 10-digit phone number';
    }
    if (RegExp(r'^[01]').hasMatch(digits.substring(digits.length - 10))) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Same as [phone] but optional (used for profile fields).
  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return phone(value);
  }

  /// Admin-entered WhatsApp number: 10–15 digits with an optional country code.
  static String? whatsappNumber(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 'WhatsApp number is required';
    if (digits.length < 10 || digits.length > 15) {
      return 'Enter a valid number with country code';
    }
    return null;
  }

  static String? price(String? value, {String field = 'Price'}) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return '$field is required';
    final double? parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return '$field cannot be negative';
    if (parsed > 10000000) return '$field looks too large';
    return null;
  }

  static String? percentage(String? value, {String field = 'Percentage'}) {
    final String? basic = price(value, field: field);
    if (basic != null) return basic;
    final double parsed = double.parse((value ?? '').trim());
    if (parsed < 0 || parsed > 100) return '$field must be between 0 and 100';
    return null;
  }

  static String? stock(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Stock is required';
    final int? parsed = int.tryParse(v);
    if (parsed == null) return 'Enter a whole number';
    if (parsed < 0) return 'Stock cannot be negative';
    return null;
  }

  /// Delivery addresses: enough length to be useful, not so much it breaks UI.
  static String? address(String? value, {int minLength = 10}) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Delivery address is required';
    if (v.length < minLength) {
      return 'Please enter a complete address (at least $minLength characters)';
    }
    if (v.length > 400) return 'Address is too long';
    return null;
  }

  static String? sku(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'SKU is required';
    if (v.length > 32) return 'SKU must be under 32 characters';
    if (!RegExp(r'^[A-Za-z0-9\-_/]+$').hasMatch(v)) {
      return 'Use only letters, numbers, - , _ or /';
    }
    return null;
  }

  static String? searchQuery(String? value) {
    if (value == null) return null;
    if (value.length > 80) return 'Search is too long';
    return null;
  }

  static String? url(String? value, {bool required = false}) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return required ? 'Link is required' : null;
    final Uri? uri = Uri.tryParse(v);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Enter a valid link (https://…)';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Links must start with http:// or https://';
    }
    return null;
  }
}
