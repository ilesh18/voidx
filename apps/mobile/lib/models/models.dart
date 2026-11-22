// models/sos_request.dart
import 'dart:convert';
import 'package:flutter/material.dart';

class SosRequest {
  final String sosId;
  final String userId;
  final String deviceId;
  final double lat;
  final double lng;
  final double accuracyMeters;
  final String category;
  final String description;
  final String severity;
  final int peopleAffected;
  final List<String> preferredAssistance;
  final String status;
  final String createdAt;
  final Map<String, dynamic>? assignedTeam;
  final List<dynamic> statusHistory;
  final bool isOfflineSynced;
  final double? distanceFromResponderKm;

  const SosRequest({
    required this.sosId,
    required this.userId,
    required this.deviceId,
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    required this.category,
    required this.description,
    required this.severity,
    required this.peopleAffected,
    required this.preferredAssistance,
    required this.status,
    required this.createdAt,
    this.assignedTeam,
    required this.statusHistory,
    this.isOfflineSynced = false,
    this.distanceFromResponderKm,
  });

  factory SosRequest.fromJson(Map<String, dynamic> j) => SosRequest(
        sosId: j['sos_id'] ?? '',
        userId: j['user_id'] ?? '',
        deviceId: j['device_id'] ?? '',
        lat: (j['lat'] ?? 0).toDouble(),
        lng: (j['lng'] ?? 0).toDouble(),
        accuracyMeters: (j['accuracy_meters'] ?? 10).toDouble(),
        category: j['category'] ?? 'general',
        description: j['description'] ?? '',
        severity: j['severity'] ?? 'HIGH',
        peopleAffected: j['people_affected'] ?? 1,
        preferredAssistance: List<String>.from(j['preferred_assistance'] ?? []),
        status: j['status'] ?? 'PENDING',
        createdAt: j['created_at'] ?? '',
        assignedTeam: j['assigned_team'],
        statusHistory: j['status_history'] ?? [],
        isOfflineSynced: j['is_offline_synced'] ?? false,
        distanceFromResponderKm: j['distance_from_responder_km']?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'sos_id': sosId,
        'user_id': userId,
        'device_id': deviceId,
        'lat': lat,
        'lng': lng,
        'accuracy_meters': accuracyMeters,
        'category': category,
        'description': description,
        'severity': severity,
        'people_affected': peopleAffected,
        'preferred_assistance': preferredAssistance,
        'status': status,
        'created_at': createdAt,
        'is_offline_synced': isOfflineSynced,
      };

  String toJsonString() => jsonEncode(toJson());

  SosRequest copyWith({String? status, Map<String, dynamic>? assignedTeam}) =>
      SosRequest(
        sosId: sosId,
        userId: userId,
        deviceId: deviceId,
        lat: lat,
        lng: lng,
        accuracyMeters: accuracyMeters,
        category: category,
        description: description,
        severity: severity,
        peopleAffected: peopleAffected,
        preferredAssistance: preferredAssistance,
        status: status ?? this.status,
        createdAt: createdAt,
        assignedTeam: assignedTeam ?? this.assignedTeam,
        statusHistory: statusHistory,
        isOfflineSynced: isOfflineSynced,
        distanceFromResponderKm: distanceFromResponderKm,
      );

  Color get severityColor {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return const Color(0xFFFF1744);
      case 'HIGH':     return const Color(0xFFFF6D00);
      case 'MEDIUM':   return const Color(0xFFFFD600);
      default:         return const Color(0xFF00E676);
    }
  }
}

// models/rescue_team.dart
class RescueTeam {
  final String teamId;
  final String teamName;
  final String category;
  final double lat;
  final double lng;
  final String status;
  final List<String> capabilities;
  final String contact;
  final double? distanceKm;
  final int? dataAgeSeconds;

  const RescueTeam({
    required this.teamId,
    required this.teamName,
    required this.category,
    required this.lat,
    required this.lng,
    required this.status,
    required this.capabilities,
    required this.contact,
    this.distanceKm,
    this.dataAgeSeconds,
  });

  factory RescueTeam.fromJson(Map<String, dynamic> j) => RescueTeam(
        teamId: j['team_id'] ?? '',
        teamName: j['team_name'] ?? '',
        category: j['category'] ?? 'rescue',
        lat: (j['lat'] ?? 0).toDouble(),
        lng: (j['lng'] ?? 0).toDouble(),
        status: j['status'] ?? 'unknown',
        capabilities: List<String>.from(j['capabilities'] ?? []),
        contact: j['contact'] ?? '',
        distanceKm: j['distance_km']?.toDouble(),
        dataAgeSeconds: j['data_age_seconds'],
      );
}

// models/cyclone_data.dart
class CycloneData {
  final String stormId;
  final String stormName;
  final String agency;
  final double latitude;
  final double longitude;
  final double maxSustainedWindKmh;
  final double maxSustainedWindKts;
  final String category;
  final String status;
  final String updatedAt;

  const CycloneData({
    required this.stormId,
    required this.stormName,
    required this.agency,
    required this.latitude,
    required this.longitude,
    required this.maxSustainedWindKmh,
    required this.maxSustainedWindKts,
    required this.category,
    required this.status,
    required this.updatedAt,
  });

  factory CycloneData.fromJson(Map<String, dynamic> j) => CycloneData(
        stormId: j['storm_id'] ?? '',
        stormName: j['storm_name'] ?? 'Unknown Storm',
        agency: j['agency'] ?? 'IMD',
        latitude: (j['latitude'] ?? 0).toDouble(),
        longitude: (j['longitude'] ?? 0).toDouble(),
        maxSustainedWindKmh: (j['max_sustained_wind_kmh'] ?? 0).toDouble(),
        maxSustainedWindKts: (j['max_sustained_wind_kts'] ?? 0).toDouble(),
        category: j['category'] ?? 'TD',
        status: j['status'] ?? 'active',
        updatedAt: j['updated_at'] ?? '',
      );
}
