import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/local_date.dart';
import 'calendar_month.dart';
import 'day_cell.dart';

/// 7×6 grid of uniform cells. Owns the long-press drag gesture: press and
/// hold a start/end date, move, release to drop (§4.4).
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.cells,
    required this.dragTarget,
    required this.onTapDay,
    required this.onDeleteStart,
    required this.onClearEnd,
    required this.onDragBegin,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    this.cellHeight = 54,
  });

  final List<DayCellData> cells;
  final LocalDate? dragTarget;
  final void Function(DayCellData day, Rect globalRect) onTapDay;
  final void Function(DayCellData day) onDeleteStart;
  final void Function(DayCellData day) onClearEnd;

  /// Return true if the pressed day is draggable (an actual start/end).
  final bool Function(LocalDate date) onDragBegin;
  final void Function(LocalDate date) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;
  final double cellHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;

        LocalDate dateAt(Offset local) {
          final col = (local.dx / cellWidth).floor().clamp(0, 6);
          final row = (local.dy / cellHeight).floor().clamp(0, 5);
          return cells[row * 7 + col].date;
        }

        // Drag state lives in the controller (a local flag here would be
        // reset by the rebuilds the drag itself triggers). Updates without
        // an active drag are ignored there.
        return GestureDetector(
          onLongPressStart: (e) {
            if (onDragBegin(dateAt(e.localPosition))) {
              HapticFeedback.selectionClick();
            }
          },
          onLongPressMoveUpdate: (e) => onDragUpdate(dateAt(e.localPosition)),
          onLongPressEnd: (_) => onDragEnd(),
          onLongPressCancel: onDragCancel,
          child: SizedBox(
            height: cellHeight * 6,
            child: Column(
              children: [
                for (var row = 0; row < 6; row++)
                  SizedBox(
                    height: cellHeight,
                    child: Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          SizedBox(
                            width: cellWidth,
                            child: _cell(cells[row * 7 + col]),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cell(DayCellData d) => DayCell(
    key: ValueKey('day-${d.date}'),
    data: d,
    isDragTarget: dragTarget == d.date,
    onTap: (rect) => onTapDay(d, rect),
    onDeleteStart: () => onDeleteStart(d),
    onClearEnd: () => onClearEnd(d),
  );
}
