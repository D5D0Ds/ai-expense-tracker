import 'package:ai_expense_tracker/features/model_asset/model_asset_controller.dart';
import 'package:ai_expense_tracker/features/settings/budget_controller.dart';
import 'package:ai_expense_tracker/features/settings/budget_input.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/platform/gemma_bridge.dart';
import 'package:ai_expense_tracker/shared/platform/permission_gateway.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:ai_expense_tracker/shared/widgets/glass_panel.dart';
import 'package:ai_expense_tracker/shared/widgets/tinted_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Settings for permissions, model status, and privacy.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates settings.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _refreshKey = 0;
  late final TextEditingController _budgetController;

  @override
  void initState() {
    super.initState();
    final now = ref.read(nowProvider)();
    final currentBudget = ref
        .read(budgetControllerProvider.notifier)
        .getBudgetForMonth(now);
    _budgetController = TextEditingController(
      text: currentBudget.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _request(AppPermission permission) async {
    await ref.read(permissionGatewayProvider).request(permission);
    if (mounted) setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(modelAssetControllerProvider).asData?.value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Permissions, model health, and local-only privacy controls.',
          style: TextStyle(color: Color(0xA3FFFFFF), height: 1.35),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Permissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              _PermissionRow(
                key: ValueKey('sms_$_refreshKey'),
                permission: AppPermission.sms,
                icon: LucideIcons.messageSquare,
                label: 'SMS access',
                description: 'Read expense hints from bank SMS',
                onRequest: () => _request(AppPermission.sms),
              ),
              const SizedBox(height: 12),
              _PermissionRow(
                key: ValueKey('notif_$_refreshKey'),
                permission: AppPermission.notification,
                icon: LucideIcons.bell,
                label: 'Notifications',
                description: 'Alerts for new SMS suggestions',
                onRequest: () => _request(AppPermission.notification),
                variant: _PermissionVariant.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gemma',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                model?.phase == ModelAssetPhase.ready
                    ? 'Model is loaded and ready.'
                    : 'Model is required for SMS parsing.',
                style: const TextStyle(color: Color(0xA3FFFFFF)),
              ),
              const SizedBox(height: 16),
              ShadButton.secondary(
                width: double.infinity,
                leading: const Icon(LucideIcons.download),
                onPressed: () => context.push('/model'),
                child: const Text('Manage model'),
              ),
              const SizedBox(height: 16),
              FutureBuilder<GemmaRuntimeDiagnostics>(
                future: ref.watch(gemmaDiagnosticsProvider.future),
                builder: (context, snapshot) {
                  final diagnostics = snapshot.data;
                  if (diagnostics == null) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Color(0x1FFFFFFF)),
                      const SizedBox(height: 16),
                      _RuntimeLine(
                        'Backend',
                        diagnostics.loaded
                            ? (diagnostics.backend ?? 'Loaded')
                            : 'Not loaded',
                      ),
                      if (diagnostics.initTimeMs != null)
                        _RuntimeLine(
                          'Init',
                          '${diagnostics.initTimeMs} ms',
                        ),
                      if (diagnostics.lastParseTimeMs != null)
                        _RuntimeLine(
                          'Last parse',
                          '${diagnostics.lastParseTimeMs} ms',
                        ),
                      if (diagnostics.timeToFirstTokenSeconds != null)
                        _RuntimeLine(
                          'TTFT',
                          '${diagnostics.timeToFirstTokenSeconds!.toStringAsFixed(2)} s',
                        ),
                      if (diagnostics.decodeTokensPerSecond != null)
                        _RuntimeLine(
                          'Decode',
                          '${diagnostics.decodeTokensPerSecond!.toStringAsFixed(1)} tok/s',
                        ),
                      if (diagnostics.lastError != null &&
                          diagnostics.lastError!.trim().isNotEmpty)
                        _RuntimeLine('Last error', diagnostics.lastError!),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Budget',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set your limit for current and future months. Past months will keep their historical budgets.',
                style: TextStyle(color: Color(0xA3FFFFFF), height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    '₹',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.turquoise,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadInput(
                      controller: _budgetController,
                      placeholder: const Text('40000'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ShadButton(
                    onPressed: () async {
                      final val = parseBudgetAmount(_budgetController.text);
                      if (val != null) {
                        final messenger = ScaffoldMessenger.of(context);
                        final now = ref.read(nowProvider)();
                        await ref
                            .read(budgetControllerProvider.notifier)
                            .setBudgetForMonth(now, val);
                        messenger.showSnackBar(
                           const SnackBar(
                            content: Text(
                              'Monthly budget updated successfully!',
                            ),
                            backgroundColor: AppTheme.turquoise,
                          ),
                        );
                      }
                    },
                    child: const Text('Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                'Expenses, SMS previews, and reports stay on this device. The app has no telemetry and no cloud sync.',
                style: TextStyle(color: Color(0xA3FFFFFF), height: 1.35),
              ),
              SizedBox(height: 16),
              _OpenAppSettingsButton(),
            ],
          ),
        ),
      ],
    );
  }
}

enum _PermissionVariant { primary, secondary }

class _PermissionRow extends ConsumerWidget {
  const _PermissionRow({
    required this.permission,
    required this.icon,
    required this.label,
    required this.description,
    required this.onRequest,
    this.variant = _PermissionVariant.primary,
    super.key,
  });

  final AppPermission permission;
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onRequest;
  final _PermissionVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<AppPermissionStatus>(
      future: ref.watch(permissionGatewayProvider).status(permission),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final granted = status == AppPermissionStatus.granted;
        final blocked = status == AppPermissionStatus.blocked;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: granted
                ? AppTheme.accent.withValues(alpha: 0.06)
                : AppTheme.surfaceMuted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: granted
                  ? AppTheme.accent.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: granted
                      ? AppTheme.accent.withValues(alpha: 0.14)
                      : AppTheme.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: granted ? AppTheme.accent : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (granted)
                const TintedPill(
                      label: 'Granted',
                      color: AppTheme.accent,
                      icon: LucideIcons.check,
                    )
                    .animate()
                    .fadeIn(duration: 200.ms)
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1),
                      duration: 250.ms,
                      curve: Curves.easeOutBack,
                    )
              else if (blocked)
                const TintedPill(
                  label: 'Blocked',
                  color: AppTheme.coral,
                  icon: LucideIcons.ban,
                )
              else if (variant == _PermissionVariant.primary)
                ShadButton(
                  size: ShadButtonSize.sm,
                  leading: const Icon(LucideIcons.shieldCheck, size: 16),
                  onPressed: onRequest,
                  child: const Text('Grant'),
                )
              else
                ShadButton.secondary(
                  size: ShadButtonSize.sm,
                  leading: const Icon(LucideIcons.shieldCheck, size: 16),
                  onPressed: onRequest,
                  child: const Text('Grant'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OpenAppSettingsButton extends ConsumerWidget {
  const _OpenAppSettingsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShadButton.ghost(
      leading: const Icon(LucideIcons.settings),
      onPressed: () => ref.read(permissionGatewayProvider).openSettings(),
      child: const Text('Android app settings'),
    );
  }
}

class _RuntimeLine extends StatelessWidget {
  const _RuntimeLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xA3FFFFFF)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
