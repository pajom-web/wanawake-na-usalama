import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/tactical_theme.dart';

class PoliceLoginPage extends ConsumerStatefulWidget {
  const PoliceLoginPage({super.key});

  @override
  ConsumerState<PoliceLoginPage> createState() => _PoliceLoginPageState();
}

class _PoliceLoginPageState extends ConsumerState<PoliceLoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(policeControllerProvider);
    final controller = ref.read(policeControllerProvider.notifier);
    final l10n = context.l10n;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 460),
          child: TacticalPanel(
            padding: EdgeInsets.all(24),
            borderColor: TacticalColors.borderStrong,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: TacticalColors.active,
                      size: 30,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TacticalEyebrow(
                            l10n.t('login.restricted'),
                            color: TacticalColors.active,
                          ),
                          SizedBox(height: 3),
                          Text(
                            l10n.t('login.title'),
                            style: TextStyle(
                              color: TacticalColors.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Container(
                  padding: EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: TacticalColors.background,
                    border: Border.all(color: TacticalColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: TacticalColors.low,
                        size: 17,
                      ),
                      SizedBox(width: 8),
                      Expanded(child: Text(l10n.t('login.instructions'))),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                TextField(
                  controller: _usernameController,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.t('login.username'),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.t('login.password'),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _login(controller),
                ),
                if (state.error != null) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TacticalColors.critical.withValues(alpha: 0.1),
                      border: Border.all(
                        color: TacticalColors.critical.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.error(state.error!),
                      style: TextStyle(color: TacticalColors.critical),
                    ),
                  ),
                ],
                SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: state.isLoading ? null : () => _login(controller),
                  icon: state.isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.login),
                  label: Text(l10n.t('login.submit')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login(PoliceController controller) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await controller.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
  }
}
