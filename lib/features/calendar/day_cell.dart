import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import 'calendar_month.dart';

/// One calendar day. Taps are handled here; long-press drag is handled by
/// the grid so the finger can move across cells.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.data,
    required this.isDragTarget,
    required this.onTap,
    required this.onDeleteStart,
    required this.onClearEnd,
  });

  final DayCellData data;
  final bool isDragTarget;
  final void Function(Rect globalRect) onTap;
  final VoidCallback onDeleteStart;
  final VoidCallback onClearEnd;

  @override
  Widget build(BuildContext context) {
    final d = data;
    Color? fill;
    Color textColor = d.date.weekday == DateTime.sunday
        ? AppColors.sunday
        : AppColors.text;
    Border? border;
    var bold = false;

    if (d.kind == DayKind.actual && d.isStart) {
      fill = AppColors.actualStart;
      textColor = Colors.white;
      bold = true;
    } else if (d.kind == DayKind.actual) {
      fill = AppColors.actual;
      textColor = AppColors.text;
    } else if (d.kind == DayKind.predicted) {
      fill = AppColors.predictedFill;
      textColor = AppColors.predictedText;
      border = Border.all(color: AppColors.predictedBorder);
    }
    if (isDragTarget) {
      border = Border.all(color: AppColors.text, width: 2);
    } else if (d.isToday && fill == null) {
      border = Border.all(color: AppColors.text, width: 1.2);
    }

    final showX = d.isStart || d.isEnd;
    final xColor = d.isStart ? Colors.white : AppColors.actualStart;

    return Opacity(
      opacity: d.inMonth ? 1 : 0.35,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final box = context.findRenderObject()! as RenderBox;
          onTap(box.localToGlobal(Offset.zero) & box.size);
        },
        child: Semantics(
          button: true,
          label: _semanticLabel(d),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: fill,
              border: border,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${d.date.day}',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                          fontWeight: bold || d.isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (d.isToday && fill != null)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: textColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showX)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: GestureDetector(
                      key: ValueKey(
                        '${d.isStart ? 'delete-start' : 'clear-end'}-${d.date}',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onTap: d.isStart ? onDeleteStart : onClearEnd,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: Center(
                          child: Icon(Icons.close, size: 12, color: xColor),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _semanticLabel(DayCellData d) {
    final parts = <String>['${d.date.month}월 ${d.date.day}일'];
    if (d.kind == DayKind.actual) parts.add(d.isStart ? '생리 시작일' : '생리 기간');
    if (d.isEnd) parts.add('생리 종료일');
    if (d.kind == DayKind.predicted) parts.add('예상 생리 기간');
    if (d.isToday) parts.add('오늘');
    return parts.join(', ');
  }
}
