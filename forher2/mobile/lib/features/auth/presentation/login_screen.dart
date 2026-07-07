import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_toggle_button.dart';
import '../../../core/theme/safety_colors.dart';
import '../../../core/theme/theme_toggle_button.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  bool _registerMode = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final error = auth.hasError ? auth.error.toString() : null;
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 52,
                    maxWidth: 460,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _BrandHeader()),
                          SizedBox(width: 12),
                          LanguageToggleButton(),
                          SizedBox(width: 8),
                          ThemeToggleButton(),
                        ],
                      ),
                      const SizedBox(height: 36),
                      _ModeSwitch(
                        registerMode: _registerMode,
                        onChanged: (value) =>
                            setState(() => _registerMode = value),
                      ),
                      const SizedBox(height: 22),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _SafetyInput(
                              controller: _username,
                              label: l10n.username,
                              icon: Icons.person_outline,
                            ),
                            if (_registerMode) ...[
                              const SizedBox(height: 14),
                              _SafetyInput(
                                controller: _displayName,
                                label: l10n.displayName,
                                icon: Icons.badge_outlined,
                              ),
                              const SizedBox(height: 14),
                              _SafetyInput(
                                controller: _email,
                                label: l10n.email,
                                icon: Icons.mail_outline,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ],
                            const SizedBox(height: 14),
                            _SafetyInput(
                              controller: _password,
                              label: l10n.password,
                              icon: Icons.lock_outline,
                              obscureText: _hidePassword,
                              trailing: IconButton(
                                tooltip: _hidePassword
                                    ? l10n.showPassword
                                    : l10n.hidePassword,
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          error,
                          style: TextStyle(
                            color: context.safetyColors.accent,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: auth.isLoading ? null : _submit,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _registerMode
                                    ? l10n.createAccount
                                    : l10n.secureLogin,
                              ),
                      ),
                      const SizedBox(height: 28),
                      const _TrustStrip(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_registerMode) {
      ref.read(authControllerProvider.notifier).register(
            username: _username.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            displayName: _displayName.text.trim(),
          );
    } else {
      ref
          .read(authControllerProvider.notifier)
          .login(_username.text.trim(), _password.text);
    }
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.22),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            Icons.shield_outlined,
            color: colors.accent,
            size: 34,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          l10n.appTitle,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.brandCopy,
          style: TextStyle(
            color: colors.secondaryText,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.registerMode, required this.onChanged});

  final bool registerMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final l10n = context.l10n;

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: l10n.login,
            selected: !registerMode,
            onTap: () => onChanged(false),
          ),
          _ModeButton(
            label: l10n.register,
            selected: registerMode,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : colors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyInput extends StatelessWidget {
  const _SafetyInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.trailing,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final l10n = context.l10n;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: (value) => value == null || value.trim().isEmpty
          ? l10n.fieldRequired(label)
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colors.secondaryText),
        suffixIcon: trailing,
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final l10n = context.l10n;

    return Row(
      children: [
        Icon(Icons.lock_outline, size: 18, color: colors.secondaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.trustStrip,
            style: TextStyle(
              color: colors.secondaryText,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
