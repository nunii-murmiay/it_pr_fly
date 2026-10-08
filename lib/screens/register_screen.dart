import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../state/auth_notifier.dart';
import '../validation/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  PasswordStrength get _strength => PasswordStrength.evaluate(_password.text);

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_strength.isStrong) {
      setState(() => _error = 'Пароль не проходит усиленную проверку');
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthNotifier>().register(
        username: _username.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
      );
      if (!mounted) return;
      context.go('/products');
    } on ValidationException catch (e) {
      final details = e.errors.values.join('; ');
      setState(() => _error = details.isEmpty ? e.message : details);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Не удалось зарегистрироваться.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _strength;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Регистрация покупателя',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Новый пользователь получает роль «Покупатель».',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: 'Логин',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) =>
                                AppValidators.minLength(v, 3, field: 'Логин'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fullName,
                        decoration: const InputDecoration(
                          labelText: 'ФИО',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) => AppValidators.required(v, field: 'ФИО'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: AppValidators.email,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed:
                                () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final base = AppValidators.required(
                            v,
                            field: 'Пароль',
                          );
                          if (base != null) return base;
                          final st = PasswordStrength.evaluate(v!);
                          if (!st.isStrong) {
                            return 'Пароль: ≥8 символов, цифра и спецсимвол';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      _RuleRow(
                        ok: s.hasMinLength,
                        label: 'Не менее 8 символов',
                      ),
                      _RuleRow(ok: s.hasDigit, label: 'Есть цифра'),
                      _RuleRow(
                        ok: s.hasSpecial,
                        label: 'Есть специальный символ (!@#\$%…)',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child:
                            _loading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Зарегистрироваться'),
                      ),
                      TextButton(
                        onPressed: _loading ? null : () => context.go('/login'),
                        child: const Text('Уже есть аккаунт — войти'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordStrength {
  final bool hasMinLength;
  final bool hasDigit;
  final bool hasSpecial;

  const PasswordStrength({
    required this.hasMinLength,
    required this.hasDigit,
    required this.hasSpecial,
  });

  bool get isStrong => hasMinLength && hasDigit && hasSpecial;

  static PasswordStrength evaluate(String value) {
    return PasswordStrength(
      hasMinLength: value.length >= 8,
      hasDigit: RegExp(r'\d').hasMatch(value),
      hasSpecial: RegExp(
        r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/]',
      ).hasMatch(value),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final bool ok;
  final String label;

  const _RuleRow({required this.ok, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green.shade700 : Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
