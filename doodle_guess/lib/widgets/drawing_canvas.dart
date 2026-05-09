import 'package:flutter/material.dart';
import '../models/drawing_point.dart';

class DrawingCanvas extends StatefulWidget {
  final Color selectedColor;
  final double strokeWidth;
  final List<DrawingPoint?> points;
  final void Function(List<DrawingPoint?> points) onPointsChanged;

  const DrawingCanvas({
    super.key,
    required this.selectedColor,
    required this.strokeWidth,
    required this.points,
    required this.onPointsChanged,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  Paint get _currentPaint => Paint()
    ..color = widget.selectedColor
    ..strokeWidth = widget.strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  void _onPanStart(DragStartDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final localOffset = box.globalToLocal(details.globalPosition);
    widget.onPointsChanged([
      ...widget.points,
      DrawingPoint(offset: localOffset, paint: _currentPaint),
    ]);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final localOffset = box.globalToLocal(details.globalPosition);
    widget.onPointsChanged([
      ...widget.points,
      DrawingPoint(offset: localOffset, paint: _currentPaint),
    ]);
  }

  void _onPanEnd(DragEndDetails _) {
    widget.onPointsChanged([...widget.points, null]);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: CustomPaint(
        painter: _CanvasPainter(points: widget.points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  _CanvasPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current != null && next != null) {
        // Normal line segment
        canvas.drawLine(current.offset, next.offset, current.paint);
      } else if (current != null && next == null) {
        // Only draw a dot if this point has no predecessor either
        // i.e. it's a completely isolated single tap, not a stroke end
        final hasPrev = i > 0 && points[i - 1] != null;
        if (!hasPrev) {
          canvas.drawCircle(
            current.offset,
            current.paint.strokeWidth / 2,
            current.paint..style = PaintingStyle.fill,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) => true;
}