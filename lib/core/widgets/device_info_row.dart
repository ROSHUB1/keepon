import 'package:flutter/material.dart';

/// Label on the left, value on the right, optional action under the value.
class DeviceInformationRow extends StatelessWidget {
  const DeviceInformationRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label, style: text.bodySmall)),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, textAlign: TextAlign.end, style: text.titleSmall?.copyWith(color: valueColor)),
                if (actionLabel != null)
                  TextButton(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(48, 36)),
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
