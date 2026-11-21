import 'package:flutter/material.dart';

class DestructiveConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String dismissLabel;
  final String confirmLabel;
  final String semanticsLabel;
  final IconData icon;
  final Key? dismissButtonKey;
  final Key? confirmButtonKey;

  const DestructiveConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.dismissLabel,
    required this.confirmLabel,
    required this.semanticsLabel,
    required this.icon,
    this.dismissButtonKey,
    this.confirmButtonKey,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String dismissLabel,
    required String confirmLabel,
    required String semanticsLabel,
    required IconData icon,
    Key? dismissButtonKey,
    Key? confirmButtonKey,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DestructiveConfirmDialog(
        title: title,
        message: message,
        dismissLabel: dismissLabel,
        confirmLabel: confirmLabel,
        semanticsLabel: semanticsLabel,
        icon: icon,
        dismissButtonKey: dismissButtonKey,
        confirmButtonKey: confirmButtonKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF1E5AA8);
    const dangerColor = Color(0xFFC41E1E);
    const dangerIconColor = Color(0xFFA52A2A);
    const softRed = Color(0xFFFDECEC);

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: softRed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: 26,
                      color: dangerIconColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1A2530),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4A5568),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 8,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          key: dismissButtonKey,
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: brandColor,
                            side: const BorderSide(color: Color(0xFFE3E8EF)),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            dismissLabel,
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              color: brandColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 14,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          key: confirmButtonKey,
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dangerColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              confirmLabel,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
