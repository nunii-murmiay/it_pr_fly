import '../core/pb_ids.dart';

/// Карта лояльности клиента (аналог LibraryCard, связь 1:1 с Customer).
class LoyaltyCard {
  final String id;
  final String number;
  final DateTime issuedAt;
  final int points;
  final String level;

  const LoyaltyCard({
    this.id = '',
    required this.number,
    required this.issuedAt,
    required this.points,
    required this.level,
  });

  LoyaltyCard copyWith({
    String? id,
    String? number,
    DateTime? issuedAt,
    int? points,
    String? level,
  }) {
    return LoyaltyCard(
      id: id ?? this.id,
      number: number ?? this.number,
      issuedAt: issuedAt ?? this.issuedAt,
      points: points ?? this.points,
      level: level ?? this.level,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'number': number,
    'issuedAt': issuedAt.toIso8601String(),
    'points': points,
    'level': level,
  };

  factory LoyaltyCard.fromJson(Map<String, dynamic> json) => LoyaltyCard(
    id: pbId(json['id']),
    number: json['number'] as String? ?? '',
    issuedAt:
        json['issuedAt'] == null
            ? DateTime.now()
            : DateTime.tryParse(json['issuedAt'].toString()) ?? DateTime.now(),
    points: (json['points'] as num?)?.toInt() ?? 0,
    level: json['level'] as String? ?? 'Стандарт',
  );

  static const levels = ['Стандарт', 'Серебро', 'Золото', 'Платина'];
}
