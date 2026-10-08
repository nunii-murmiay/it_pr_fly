import 'package:flutter/material.dart';

/// Множественный выбор через FilterChip внутри FormField.
class ChipMultiSelectFormField extends StatelessWidget {
  final String label;
  final List<String> value;
  final List<({String id, String name})> options;
  final ValueChanged<List<String>> onChanged;
  final String? Function(List<String>?)? validator;
  final String emptyHint;

  const ChipMultiSelectFormField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.validator,
    this.emptyHint = 'Нет доступных вариантов',
  });

  @override
  Widget build(BuildContext context) {
    return FormField<List<String>>(
      initialValue: value,
      validator: validator,
      builder: (field) {
        // синхронизация внешнего value
        if (!_same(field.value, value)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            field.didChange(value);
          });
        }
        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            errorText: field.errorText,
          ),
          child:
              options.isEmpty
                  ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      emptyHint,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                  : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        options.map((o) {
                          final selected = (field.value ?? const []).contains(
                            o.id,
                          );
                          return FilterChip(
                            label: Text(o.name),
                            selected: selected,
                            onSelected: (_) {
                              final next = [
                                ...(field.value ?? const <String>[]),
                              ];
                              selected ? next.remove(o.id) : next.add(o.id);
                              field.didChange(next);
                              onChanged(next);
                            },
                          );
                        }).toList(),
                  ),
        );
      },
    );
  }

  bool _same(List<String>? a, List<String> b) {
    if (a == null) return false;
    if (a.length != b.length) return false;
    for (final x in a) {
      if (!b.contains(x)) return false;
    }
    return true;
  }
}
