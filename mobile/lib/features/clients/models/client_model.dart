/// Modèle représentant un client
class ClientModel {
  final String id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? cnibNumber;
  final String? birthDate;
  final String? operatorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Champ joint (non stocké en base)
  final String? operatorName;

  ClientModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.cnibNumber,
    this.birthDate,
    this.operatorId,
    this.operatorName,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'cnib_number': cnibNumber,
        'birth_date': birthDate,
        'operator_id': operatorId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ClientModel.fromMap(Map<String, dynamic> map) => ClientModel(
        id: map['id'] as String,
        firstName: map['first_name'] as String,
        lastName: map['last_name'] as String,
        phoneNumber: map['phone_number'] as String,
        cnibNumber: map['cnib_number'] as String?,
        birthDate: map['birth_date'] as String?,
        operatorId: map['operator_id'] as String?,
        operatorName: map['operator_name'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  ClientModel copyWith({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? cnibNumber,
    String? birthDate,
    String? operatorId,
  }) =>
      ClientModel(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        cnibNumber: cnibNumber ?? this.cnibNumber,
        birthDate: birthDate ?? this.birthDate,
        operatorId: operatorId ?? this.operatorId,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
