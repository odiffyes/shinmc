import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

enum DateAction { start, end }

/// Small bubble with exactly two buttons, 시작 / 종료 (§4.1), anchored
/// above (or below) the tapped cell. Dismisses on outside tap.
Future<DateAction?> showDateActionPopup(BuildContext context, Rect anchor) {
  return showGeneralDialog<DateAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, _, _) {
      const width = 148.0;
      const height = 44.0;
      final screen = MediaQuery.sizeOf(context);
      final left = (anchor.center.dx - width / 2).clamp(
        8.0,
        screen.width - width - 8,
      );
      final above = anchor.top - height - 6;
      final top = above > MediaQuery.paddingOf(context).top + 8
          ? above
          : anchor.bottom + 6;
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: Material(
              color: Colors.white,
              elevation: 1,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.separator),
              ),
              child: Row(
                children: [
                  _button(context, '시작', DateAction.start),
                  Container(width: 1, height: 22, color: AppColors.separator),
                  _button(context, '종료', DateAction.end),
                ],
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

Widget _button(BuildContext context, String label, DateAction action) =>
    Expanded(
      child: InkWell(
        key: ValueKey('popup-${action.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(action),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.actualStart,
            ),
          ),
        ),
      ),
    );
