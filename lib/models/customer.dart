import '../core/pb_ids.dart';

import 'loyalty_card.dart';

/// Клиент зоомагазина (аналог Reader) с вложенной картой лояльности.
class Customer {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final LoyaltyCard card;
  final DateTime? deletedAt;

  const Customer({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.card,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Customer copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    LoyaltyCard? card,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Customer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      card: card ?? this.card,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'card': card.toJson(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    final cardJson = json['card'];
    final card =
        cardJson is Map<String, dynamic>
            ? LoyaltyCard.fromJson(cardJson)
            : LoyaltyCard(
              number: '',
              issuedAt: DateTime.now(),
              points: 0,
              level: 'Стандарт',
            );

    return Customer(
      id: pbId(json['id']),
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      card: card,
      deletedAt: pbDate(json['deletedAt']),
    );
  }
}
