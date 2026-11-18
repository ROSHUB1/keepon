import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utilities/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../shared/models/location_record.dart';
import '../../../shared/providers/protection_controller.dart';
import '../../../shared/providers/providers.dart';

/// Locations KEEPON recorded during an alarm session. Stored encrypted on this phone only.
class LocationLogCard extends ConsumerStatefulWidget {
  const LocationLogCard({super.key});

  @override
  ConsumerState<LocationLogCard> createState() => _LocationLogCardState();
}

class _LocationLogCardState extends ConsumerState<LocationLogCard> {
  List<LocationLogEntry>? _entries;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await ref.read(bridgeProvider).locationLog();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reload when the native side saved something new (it pings through refresh()).
    ref.listen(protectionProvider.select((p) => p.sessionActive), (_, __) => _load());
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final entries = _entries ?? const <LocationLogEntry>[];
    final shown = entries.take(5).toList();
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text('Recorded during alarms', style: text.titleSmall)),
                TextButton(onPressed: _loading ? null : _load, child: const Text('Refresh')),
              ],
            ),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                _loading
                    ? 'Loading...'
                    : 'Nothing recorded yet. When an alarm session is active, KEEPON saves the phone\'s location here, encrypted, on this phone only.',
                style: text.bodySmall,
              ),
            )
          else ...[
            for (final e in shown) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${e.latitude.toStringAsFixed(5)}, ${e.longitude.toStringAsFixed(5)}',
                            style: text.titleSmall,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (e.live ? AppColors.success : AppColors.warning).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            e.live ? 'Current' : 'Last known',
                            style: text.labelSmall?.copyWith(color: e.live ? AppColors.success : AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fix ${formatDateTimeFull(e.fixTime)} · ${e.provider} · '
                      '${e.accuracyMeters == null ? 'accuracy n/a' : '±${e.accuracyMeters!.round()} m'} · '
                      '${e.online ? 'online' : 'offline'}',
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
            if (entries.length > shown.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('${entries.length - shown.length} older entries saved.', style: text.bodySmall),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final ok = await showConfirmation(
                    context,
                    title: 'Delete recorded locations?',
                    message: 'The location log on this phone will be deleted. This cannot be undone.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (!ok) return;
                  await ref.read(bridgeProvider).clearLocationLog();
                  await _load();
                },
                child: const Text('Delete log'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
