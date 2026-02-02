/**
 * Core Type Definitions for VHASS Backend
 */

export enum SOSStatus {
  IDLE = 'IDLE',
  TRIGGERED = 'TRIGGERED',
  CONTACTING = 'CONTACTING',
  RESPONDER_ASSIGNED = 'RESPONDER_ASSIGNED',
  ACTIVE = 'ACTIVE',
  CANCELLED = 'CANCELLED',
  RESOLVED = 'RESOLVED'
}

export enum DeviceType {
  SMARTPHONE = 'SMARTPHONE',
  WEARABLE = 'WEARABLE',
  IOT_BUTTON = 'IOT_BUTTON',
  BLE_DEVICE = 'BLE_DEVICE'
}

export enum LogType {
  AUTH = 'AUTH',
  SOS_TRIGGER = 'SOS_TRIGGER',
  SOS_END = 'SOS_END',
  CALL_ATTEMPT = 'CALL_ATTEMPT',
  SMS_ATTEMPT = 'SMS_ATTEMPT',
  DEVICE_PAIR = 'DEVICE_PAIR',
  LOCATION_UPDATE = 'LOCATION_UPDATE',
  ESCALATION = 'ESCALATION',
  SOS_DEACTIVATION = 'SOS_DEACTIVATION',
  PIN_UPDATE = 'PIN_UPDATE'
}

export interface Location {
  latitude: number;
  longitude: number;
  accuracy?: number;
  timestamp: Date;
  address?: string;
}

export interface CallInstruction {
  action: 'CALL';
  phoneNumber: string;
  contactName: string;
  priority: number;
  sosId: string;
  countryCode?: string; // For phone number formatting (e.g., 'IN', 'US')
}

export interface SMSInstruction {
  action: 'SEND_SMS';
  phoneNumber: string;
  message: string;
  contactName: string;
  sosId: string;
  countryCode?: string; // For phone number formatting (e.g., 'IN', 'US')
}

export type DeviceInstruction = CallInstruction | SMSInstruction;

export interface SOSState {
  sosId: string;
  userId: string;
  deviceId: string;
  status: SOSStatus;
  currentContactIndex: number;
  startedAt: Date;
  lastLocation?: Location;
  escalationJobId?: string;
}

export interface SocketAuth {
  userId: string;
  deviceId: string;
  sosId?: string;
}

