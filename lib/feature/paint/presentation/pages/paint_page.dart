import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

enum ShapeType { brush, line, rect, circle, arrow, hexagon, star }

abstract class CanvasAction {}

class StrokeAction extends CanvasAction {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  StrokeAction(this.points, this.color, this.strokeWidth);
}

class ShapeAction extends CanvasAction {
  final ShapeType type;
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  ShapeAction(this.type, this.start, this.end, this.color, this.strokeWidth);
}

class CanvasState {
  final List<CanvasAction> actions;
  final List<int> selectedIndices;
  final Rect? selectionRect;
  final Color selectedColor;
  final double strokeWidth;
  final ShapeType selectedTool;
  final CanvasAction? preview;

  CanvasState({
    required this.actions,
    required this.selectedIndices,
    required this.selectionRect,
    required this.selectedColor,
    required this.strokeWidth,
    required this.selectedTool,
    this.preview,
  });

  CanvasState copyWith({
    List<CanvasAction>? actions,
    List<int>? selectedIndices,
    Rect? selectionRect,
    Color? selectedColor,
    double? strokeWidth,
    ShapeType? selectedTool,
    CanvasAction? preview,
  }) =>
      CanvasState(
        actions: actions ?? this.actions,
        selectedIndices: selectedIndices ?? this.selectedIndices,
        selectionRect: selectionRect ?? this.selectionRect,
        selectedColor: selectedColor ?? this.selectedColor,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        selectedTool: selectedTool ?? this.selectedTool,
        preview: preview,
      );

  CanvasState.initial()
      : actions = [],
        selectedIndices = [],
        selectionRect = null,
        selectedColor = Colors.black,
        strokeWidth = 3,
        selectedTool = ShapeType.brush,
        preview = null;
}

class CanvasNotifier extends StateNotifier<CanvasState> {
  CanvasNotifier() : super(CanvasState.initial());

  void selectTool(ShapeType tool) =>
      state = state.copyWith(selectedTool: tool, selectionRect: null, selectedIndices: []);

  void selectColor(Color color) => state = state.copyWith(selectedColor: color);

  void setStrokeWidth(double width) => state = state.copyWith(strokeWidth: width);

  void addPreview(CanvasAction action) => state = state.copyWith(preview: action);

  void commitPreview() {
    if (state.preview != null) {
      final newActions = [...state.actions, state.preview!];
      state = state.copyWith(actions: newActions, preview: null);
    }
  }

  void undo() {
    if (state.actions.isEmpty) return;
    final newActions = [...state.actions]..removeLast();
    state = state.copyWith(actions: newActions, selectedIndices: [], selectionRect: null);
  }

  void clearAll() => state = state.copyWith(actions: [], selectedIndices: [], selectionRect: null);

  void startSelection(Offset pos) => state = state.copyWith(selectionRect: Rect.fromLTWH(pos.dx, pos.dy, 0, 0));

  void updateSelection(Offset pos) {
    final sel = state.selectionRect!;
    final left = math.min(sel.left, pos.dx);
    final top = math.min(sel.top, pos.dy);
    final right = math.max(sel.right, pos.dx);
    final bottom = math.max(sel.bottom, pos.dy);
    state = state.copyWith(selectionRect: Rect.fromLTRB(left, top, right, bottom));
  }

  void finishSelection() {
    final sel = state.selectionRect;
    if (sel == null) return;
    final selRect = sel;
    final selected = <int>[];
    for (int i = 0; i < state.actions.length; i++) {
      final a = state.actions[i];
      bool intersects = false;
      if (a is StrokeAction) {
        for (int k = 0; k < a.points.length; k++) {
          if (selRect.contains(a.points[k])) {
            intersects = true;
            break;
          }
          if (k + 1 < a.points.length) {
            if (_segmentIntersectsRect(a.points[k], a.points[k + 1], selRect)) {
              intersects = true;
              break;
            }
          }
        }
      } else if (a is ShapeAction) {
        final r = Rect.fromPoints(a.start, a.end);
        if (selRect.overlaps(r)) intersects = true;
      }
      if (intersects) selected.add(i);
    }
    state = state.copyWith(selectedIndices: selected, selectionRect: null);
  }

  void moveSelected(Offset delta) {
    final actions = [...state.actions];
    for (final idx in state.selectedIndices) {
      final a = actions[idx];
      if (a is StrokeAction) {
        final newPoints = a.points.map((p) => p + delta).toList();
        actions[idx] = StrokeAction(newPoints, a.color, a.strokeWidth);
      } else if (a is ShapeAction) {
        actions[idx] = ShapeAction(a.type, a.start + delta, a.end + delta, a.color, a.strokeWidth);
      }
    }
    state = state.copyWith(actions: actions);
  }

  void deleteSelected() {
    final actions = state.actions
        .asMap()
        .entries
        .where((entry) => !state.selectedIndices.contains(entry.key))
        .map((entry) => entry.value)
        .toList();    state = state.copyWith(actions: actions, selectedIndices: [], selectionRect: null);
  }

  bool _segmentIntersectsRect(Offset p1, Offset p2, Rect rect) {
    // bounding box fast check
    final lineRect = Rect.fromPoints(p1, p2);
    if (!lineRect.overlaps(rect)) return false;

    // simple check: if either end inside
    if (rect.contains(p1) || rect.contains(p2)) return true;

    return false; // simplified for demo, can improve with line-rectangle intersection
  }
}

final canvasProvider = StateNotifierProvider<CanvasNotifier, CanvasState>((ref) => CanvasNotifier());

class PaintPage extends ConsumerStatefulWidget {
  const PaintPage({super.key});

  @override
  ConsumerState<PaintPage> createState() => _PaintPageState();
}

class _PaintPageState extends ConsumerState<PaintPage> {
  Offset? start;
  Offset? lastPoint;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(canvasProvider);
    final notifier = ref.read(canvasProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text("Mini Paint")),
      body: Column(
        children: [
          // Toolbar
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              DropdownButton<ShapeType>(
                value: state.selectedTool,
                items: ShapeType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) notifier.selectTool(v);
                },
              ),
              GestureDetector(
                onTap: () async {
                  Color pickerColor = state.selectedColor;
                  await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Pick color"),
                        content: SingleChildScrollView(
                            child: ColorPicker(
                                pickerColor: pickerColor,
                                onColorChanged: (c) => pickerColor = c)),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                notifier.selectColor(pickerColor);
                              },
                              child: const Text("OK"))
                        ],
                      ));
                },
                child: Container(
                  width: 24,
                  height: 24,
                  color: state.selectedColor,
                ),
              ),
              Slider(
                value: state.strokeWidth,
                min: 1,
                max: 20,
                onChanged: notifier.setStrokeWidth,
              ),
              IconButton(onPressed: notifier.undo, icon: const Icon(Icons.undo)),
              IconButton(onPressed: notifier.clearAll, icon: const Icon(Icons.delete)),
            ],
          ),
          Expanded(
            child: GestureDetector(
              onPanStart: (details) {
                final pos = details.localPosition;
                if (state.selectedTool == ShapeType.brush) {
                  notifier.addPreview(
                      StrokeAction([pos], state.selectedColor, state.strokeWidth));
                  lastPoint = pos;
                } else {
                  start = pos;
                }
              },
              onPanUpdate: (details) {
                final pos = details.localPosition;
                if (state.selectedTool == ShapeType.brush && lastPoint != null) {
                  final preview = state.preview as StrokeAction;
                  final points = [...preview.points, pos];
                  notifier.addPreview(StrokeAction(points, preview.color, preview.strokeWidth));
                  lastPoint = pos;
                } else if (start != null) {
                  notifier.addPreview(
                      ShapeAction(state.selectedTool, start!, pos, state.selectedColor, state.strokeWidth));
                }
              },
              onPanEnd: (details) {
                notifier.commitPreview();
                start = null;
                lastPoint = null;
              },
              child: CustomPaint(
                painter: _CanvasPainter(state),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final CanvasState state;
  _CanvasPainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = Colors.white); // background

    for (final a in state.actions) {
      _drawAction(canvas, a);
    }
    if (state.preview != null) _drawAction(canvas, state.preview!);

    // Draw selection
    if (state.selectedIndices.isNotEmpty) {
      final boxes = state.selectedIndices.map((i) {
        final a = state.actions[i];
        if (a is StrokeAction) {
          double minX = a.points.map((p) => p.dx).reduce(math.min);
          double maxX = a.points.map((p) => p.dx).reduce(math.max);
          double minY = a.points.map((p) => p.dy).reduce(math.min);
          double maxY = a.points.map((p) => p.dy).reduce(math.max);
          return Rect.fromLTRB(minX, minY, maxX, maxY);
        } else if (a is ShapeAction) {
          return Rect.fromPoints(a.start, a.end);
        }
        return Rect.zero;
      });
      double left = boxes.map((r) => r.left).reduce(math.min);
      double top = boxes.map((r) => r.top).reduce(math.min);
      double right = boxes.map((r) => r.right).reduce(math.max);
      double bottom = boxes.map((r) => r.bottom).reduce(math.max);
      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom),
          Paint()..color = Colors.blue.withOpacity(0.3));
    }
  }

  void _drawAction(Canvas canvas, CanvasAction a) {
    if (a is StrokeAction) {
      final paint = Paint()
        ..color = a.color
        ..strokeWidth = a.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < a.points.length - 1; i++) {
        canvas.drawLine(a.points[i], a.points[i + 1], paint);
      }
    } else if (a is ShapeAction) {
      final paint = Paint()
        ..color = a.color
        ..strokeWidth = a.strokeWidth
        ..style = PaintingStyle.stroke;
      switch (a.type) {
        case ShapeType.line:
          canvas.drawLine(a.start, a.end, paint);
          break;
        case ShapeType.rect:
          canvas.drawRect(Rect.fromPoints(a.start, a.end), paint);
          break;
        case ShapeType.circle:
          final r = (a.end - a.start).distance;
          canvas.drawCircle(a.start, r, paint);
          break;
        case ShapeType.arrow:
          _drawArrow(canvas, a.start, a.end, paint);
          break;
        case ShapeType.hexagon:
          _drawPolygon(canvas, a.start, a.end, 6, paint);
          break;
        case ShapeType.star:
          _drawStar(canvas, a.start, a.end, 5, paint);
          break;
        default:
          break;
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const size = 10.0;
    final p1 = Offset(end.dx - size * math.cos(angle - math.pi / 6),
        end.dy - size * math.sin(angle - math.pi / 6));
    final p2 = Offset(end.dx - size * math.cos(angle + math.pi / 6),
        end.dy - size * math.sin(angle + math.pi / 6));
    canvas.drawLine(end, p1, paint);
    canvas.drawLine(end, p2, paint);
  }

  void _drawPolygon(Canvas canvas, Offset start, Offset end, int sides, Paint paint) {
    final center = start;
    final radius = (end - start).distance;
    final path = Path();
    for (int i = 0; i <= sides; i++) {
      final angle = i * 2 * math.pi / sides;
      final point = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      if (i == 0) path.moveTo(point.dx, point.dy);
      else path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset start, Offset end, int points, Paint paint) {
    final center = start;
    final radius = (end - start).distance;
    final innerRadius = radius / 2.5;
    final path = Path();
    for (int i = 0; i <= points * 2; i++) {
      final r = i.isEven ? radius : innerRadius;
      final angle = i * math.pi / points;
      final point = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      if (i == 0) path.moveTo(point.dx, point.dy);
      else path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
