import 'package:flutter/material.dart';

/// Пороги окна из практической работы: 360 / 768 / 1280 / 1920.
class Breakpoints {
  Breakpoints._();

  /// Ниже — нижняя навигация и одна колонка карточек.
  static const double phone = 768;

  /// От этой ширины — таблица и развёрнутая боковая навигация.
  static const double desktop = 1280;

  /// На широком мониторе содержимое не растягивается на весь экран.
  static const double contentMax = 1440;

  static const dialogConstraints = BoxConstraints(maxWidth: 440);
}

/// Короткие числовые поля (цена, остаток, рейтинг, баллы) не растягиваются.
class FieldWrap extends StatelessWidget {
  final List<Widget> children;
  final double fieldWidth;

  const FieldWrap({super.key, required this.children, this.fieldWidth = 200});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final child in children) SizedBox(width: fieldWidth, child: child),
      ],
    );
  }
}
