/// Device Instruction Model
/// Backend sends instructions, device executes them
class DeviceInstruction {
  final String action; // 'CALL' or 'SEND_SMS'
  final String phoneNumber;
  final String contactName;
  final int priority;
  final String sosId;
  final String
  countryCode; // Country code for phone formatting (e.g., 'IN', 'US')

  DeviceInstruction({
    required this.action,
    required this.phoneNumber,
    required this.contactName,
    required this.priority,
    required this.sosId,
    this.countryCode = 'IN', // Default to India
  });

  factory DeviceInstruction.fromJson(Map<String, dynamic> json) {
    return DeviceInstruction(
      action: json['action'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      contactName: json['contactName'] ?? '',
      priority: json['priority'] ?? 0,
      sosId: json['sosId'] ?? '',
      countryCode: json['countryCode'] ?? 'IN',
    );
  }
}
