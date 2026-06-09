import 'package:ai_expense_tracker/features/model_asset/model_asset_config.dart';
import 'package:ai_expense_tracker/features/model_asset/model_asset_controller.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/formatters.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:ai_expense_tracker/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Full-screen model download and verification UI.
class ModelDownloadScreen extends ConsumerWidget {
  /// Creates the download screen.
  const ModelDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(modelAssetControllerProvider);
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(LucideIcons.x),
            onPressed: () => context.pop(),
          ),
          title: const Text('Gemma model'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: GlassPanel(
              padding: const EdgeInsets.all(22),
              child: modelAsync.when(
                loading: () => const ShadProgress(),
                error: (error, stackTrace) => Text(error.toString()),
                data: (model) => _ModelBody(model: model),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelBody extends ConsumerWidget {
  const _ModelBody({required this.model});

  final ModelAssetState model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloading = model.phase == ModelAssetPhase.downloading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(LucideIcons.bot, size: 42, color: AppTheme.accent),
        const SizedBox(height: 18),
        const Text(
          'Gemma 4 E2B LiteRT-LM',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          model.message ?? 'Download once for private SMS parsing.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xA3FFFFFF)),
        ),
        const SizedBox(height: 22),
        ShadProgress(
          value: downloading
              ? model.progress
              : model.isReady
              ? 1
              : 0,
        ),
        const SizedBox(height: 12),
        Text(
          downloading
              ? '${(model.progress * 100).toStringAsFixed(1)}%  ${formatSpeed(model.bytesPerSecond)}  ETA ${formatEta(model.eta)}'
              : '$gemmaModelFilename  ${(gemmaExpectedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 22),
        if (downloading)
          ShadButton.destructive(
            onPressed: ref.read(modelAssetControllerProvider.notifier).cancel,
            child: const Text('Cancel'),
          )
        else if (model.isReady)
          ShadButton(
            onPressed: () => context.pop(),
            leading: const Icon(LucideIcons.check),
            child: const Text('Ready'),
          )
        else
          ShadButton(
            onPressed: () =>
                ref.read(modelAssetControllerProvider.notifier).download(),
            leading: const Icon(LucideIcons.download),
            child: const Text('Download'),
          ),
      ],
    );
  }
}
