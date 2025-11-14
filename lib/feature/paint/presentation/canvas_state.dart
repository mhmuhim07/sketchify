import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider
final canvasProvider = StateNotifierProvider<CanvasNotifier, CanvasState>((ref) {
  return CanvasNotifier();
});

// Entities
enum ShapeType {
  brush,
  line,
  rect,
  circle,
  arrow,
  triangle,
  hexagon,
  star,
  ellipse,
  diamond,
  pentagon,
}

abstract class ActionEntity {}

class StrokeEntity extends ActionEntity {
  final List<Offset> points;
  final Color color;
  final double size;
  StrokeEntity(this.points, this.color, this.size);
}

class ShapeEntity extends ActionEntity {
  final ShapeType type;
  Offset start;
  Offset end;
  final Color color;
  final double size;
  ShapeEntity(this.type, this.start, this.end, this.color, this.size);
}

// State
class CanvasState {
  final List<ActionEntity> actions;
  final List<ActionEntity> undone;
  final List<int> selectedIndices;
  final Rect? selectionRect;
  final ShapeType selectedTool;
  final Color selectedColor;
  final double brushSize;

  CanvasState({
    this.actions = const [],
    this.undone = const [],
    this.selectedIndices = const [],
    this.selectionRect,
    this.selectedTool = ShapeType.brush,
    this.selectedColor = Colors.black,
    this.brushSize = 3,
  });

  CanvasState copyWith({
    List<ActionEntity>? actions,
    List<ActionEntity>? undone,
    List<int>? selectedIndices,
    Rect? selectionRect,
    ShapeType? selectedTool,
    Color? selectedColor,
    double? brushSize,
  }) {
    return CanvasState(
      actions: actions ?? this.actions,
      undone: undone ?? this.undone,
      selectedIndices: selectedIndices ?? this.selectedIndices,
      selectionRect: selectionRect,
      selectedTool: selectedTool ?? this.selectedTool,
      selectedColor: selectedColor ?? this.selectedColor,
      brushSize: brushSize ?? this.brushSize,
    );
  }
}

// Notifier
class CanvasNotifier extends StateNotifier<CanvasState> {
  CanvasNotifier() : super(CanvasState());

  void selectTool(ShapeType tool) => state = state.copyWith(selectedTool: tool);
  void selectColor(Color c) => state = state.copyWith(selectedColor: c);
  void selectSize(double s) => state = state.copyWith(brushSize: s);

  void undo() {
    if (state.actions.isEmpty) return;
    final last = state.actions.last;
    state = state.copyWith(
        actions: [...state.actions]..removeLast(),
        undone: [...state.undone, last],
        selectedIndices: [],
        selectionRect: null);
  }

  void redo() {
    if (state.undone.isEmpty) return;
    final last = state.undone.last;
    state = state.copyWith(
        actions: [...state.actions, last],
        undone: state.undone.sublist(0, state.undone.length - 1));
  }

  void clearAll() =>
      state = state.copyWith(actions: [], undone: [], selectedIndices: [], selectionRect: null);

  void deleteSelected() {
    final newActions = [...state.actions];
    state.selectedIndices.reversed.forEach(newActions.removeAt);
    state = state.copyWith(actions: newActions, selectedIndices: [], selectionRect: null);
  }

  // Drawing
  void onPanStart(Offset pos, PointerDeviceKind? kind) {
    if (state.selectedTool == ShapeType.brush) {
      final s = StrokeEntity([pos], state.selectedColor, state.brushSize);
      state = state.copyWith(actions: [...state.actions, s], undone: []);
    } else {
      final s = ShapeEntity(state.selectedTool, pos, pos, state.selectedColor, state.brushSize);
      state = state.copyWith(actions: [...state.actions, s], undone: []);
    }
  }

  void onPanUpdate(Offset pos) {
    final last = state.actions.last;
    if (last is StrokeEntity) {
      last.points.add(pos);
      state = state.copyWith(actions: [...state.actions]);
    } else if (last is ShapeEntity) {
      last.end = pos;
      state = state.copyWith(actions: [...state.actions]);
    }
  }

  void onPanEnd() {
    state = state.copyWith();
  }

  // Selection & Move
  void moveSelected(Offset newPos) {
    if (state.selectedIndices.isEmpty) return;
    final dx = newPos.dx - state.selectionRect!.center.dx;
    final dy = newPos.dy - state.selectionRect!.center.dy;
    final newActions = [...state.actions];
    for (int idx in state.selectedIndices) {
      final a = newActions[idx];
      if (a is StrokeEntity) {
        for (int i = 0; i < a.points.length; i++) {
          a.points[i] = a.points[i] + Offset(dx, dy);
        }
      } else if (a is ShapeEntity) {
        a.start += Offset(dx, dy);
        a.end += Offset(dx, dy);
      }
    }
    final rect = state.selectionRect!.shift(Offset(dx, dy));
    state = state.copyWith(actions: newActions, selectionRect: rect);
  }
}
