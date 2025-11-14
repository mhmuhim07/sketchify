import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:sketchify/feature/paint/presentation/canvas_state.dart';

class CanvasPainter extends CustomPainter {
  final CanvasState state;
  CanvasPainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < state.actions.length; i++) {
      final a = state.actions[i];
      paint.color = (a is StrokeEntity) ? a.color : (a as ShapeEntity).color;
      paint.strokeWidth = (a is StrokeEntity) ? a.size : (a as ShapeEntity).size;

      if (a is StrokeEntity) {
        for (int j = 0; j < a.points.length - 1; j++) {
          canvas.drawLine(a.points[j], a.points[j + 1], paint);
        }
      } else if (a is ShapeEntity) {
        _drawShape(canvas, a, paint);
      }
    }

    // Draw selection rectangle
    if (state.selectionRect != null && state.selectedIndices.isNotEmpty) {
      final selPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      canvas.drawRect(state.selectionRect!, selPaint..strokeWidth = 1..style=PaintingStyle.stroke..isAntiAlias=true);
    }
  }

  void _drawShape(Canvas canvas, ShapeEntity s, Paint paint) {
    switch (s.type) {
      case ShapeType.line:
        canvas.drawLine(s.start, s.end, paint);
        break;
      case ShapeType.rect:
        canvas.drawRect(Rect.fromPoints(s.start, s.end), paint);
        break;
      case ShapeType.circle:
        final radius = (s.end - s.start).distance;
        canvas.drawCircle(s.start, radius, paint);
        break;
      case ShapeType.arrow:
        _drawArrow(canvas, s.start, s.end, paint);
        break;
      case ShapeType.triangle:
        _drawPolygon(canvas, s.start, s.end, paint, 3);
        break;
      case ShapeType.hexagon:
        _drawPolygon(canvas, s.start, s.end, paint, 6);
        break;
      case ShapeType.star:
        _drawStar(canvas, s.start, s.end, paint);
        break;
      case ShapeType.ellipse:
        canvas.drawOval(Rect.fromPoints(s.start, s.end), paint);
        break;
      case ShapeType.diamond:
        _drawDiamond(canvas, s.start, s.end, paint);
        break;
      case ShapeType.pentagon:
        _drawPolygon(canvas, s.start, s.end, paint, 5);
        break;
      default:
        break;
    }
  }

  // Helper methods (same as previous)
  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    final headSize = 10.0;
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final path = Path();
    path.moveTo(end.dx, end.dy);
    path.lineTo(end.dx - headSize * math.cos(angle - math.pi / 6),
        end.dy - headSize * math.sin(angle - math.pi / 6));
    path.moveTo(end.dx, end.dy);
    path.lineTo(end.dx - headSize * math.cos(angle + math.pi / 6),
        end.dy - headSize * math.sin(angle + math.pi / 6));
    canvas.drawPath(path, paint);
  }

  void _drawPolygon(Canvas canvas, Offset start, Offset end, Paint paint, int sides) {
    final path = Path();
    final center = Offset((start.dx + end.dx)/2, (start.dy + end.dy)/2);
    final radius = (end - start).distance /2;
    for (int i=0; i<=sides; i++){
      final angle = 2*math.pi*i/sides - math.pi/2;
      final x = center.dx + radius*math.cos(angle);
      final y = center.dy + radius*math.sin(angle);
      if (i==0) path.moveTo(x,y);
      else path.lineTo(x,y);
    }
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset start, Offset end, Paint paint){
    final path = Path();
    final center = Offset((start.dx + end.dx)/2, (start.dy + end.dy)/2);
    final radius = (end - start).distance /2;
    for (int i=0;i<=5;i++){
      final angle = 2*math.pi*i/5 - math.pi/2;
      final r = i.isEven ? radius : radius/2;
      final x = center.dx + r*math.cos(angle);
      final y = center.dy + r*math.sin(angle);
      if (i==0) path.moveTo(x,y);
      else path.lineTo(x,y);
    }
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Offset start, Offset end, Paint paint){
    final path = Path();
    final center = Offset((start.dx + end.dx)/2, (start.dy + end.dy)/2);
    path.moveTo(center.dx, start.dy);
    path.lineTo(end.dx, center.dy);
    path.lineTo(center.dx, end.dy);
    path.lineTo(start.dx, center.dy);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
