import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';

import '../../ast/syntax_tree.dart';
import '../../encoder/tex/encoder.dart';
import '../../render/layout/line_editable.dart';
import '../../utils/render_box_extensions.dart';
import '../controller.dart';

enum ExtraSelectionChangedCause {
  // Selection handle dragged,
  handle,

  // Unfocused
  unfocus,

  // Changed by other code directly manipulating controller.
  exterior,
}

mixin SelectionManagerMixin<T extends StatefulWidget> on State<T>
    implements TextSelectionDelegate {
  MathController get controller;

  FocusNode get focusNode;

  bool get hasFocus;

  late FocusNode _oldFocusNode;

  late MathController _oldController;

  @override
  void initState() {
    super.initState();
    _oldFocusNode = focusNode..addListener(_handleFocusChange);
    _oldController = controller..addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (focusNode != _oldFocusNode) {
      _oldFocusNode.removeListener(_handleFocusChange);
      _oldFocusNode = focusNode..addListener(_handleFocusChange);
      _handleFocusChange();
    }
    if (controller != _oldController) {
      _oldController.removeListener(_onControllerChanged);
      _oldController = controller..addListener(_onControllerChanged);
      _onControllerChanged();
    }
  }

  @override
  void dispose() {
    _oldController.removeListener(_onControllerChanged);
    _oldFocusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!hasFocus) {
      handleSelectionChanged(TextSelection.collapsed(offset: -1), null,
          ExtraSelectionChangedCause.unfocus);
    }
  }

  SyntaxTree? _oldAst;
  TextSelection? _oldSelection;
  void _onControllerChanged() {
    if (_oldAst != controller.ast || _oldSelection != controller.selection) {
      handleSelectionChanged(
          controller.selection, null, ExtraSelectionChangedCause.exterior);
    }
  }

  void onSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause);

  @mustCallSuper
  void handleSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause,
      [ExtraSelectionChangedCause? extraCause]) {
    if (extraCause != ExtraSelectionChangedCause.unfocus &&
        extraCause != ExtraSelectionChangedCause.exterior &&
        !hasFocus) {
      focusNode.requestFocus();
    }
    _oldAst = controller.ast;
    _oldSelection = selection;
    controller.selection = selection;
    onSelectionChanged(selection, cause);
  }

  void selectPositionAt({
    required Offset from,
    Offset? to,
    required SelectionChangedCause cause,
  }) {
    final fromPosition = getPositionForOffset(from);
    final toPosition = to == null ? fromPosition : getPositionForOffset(to);
    handleSelectionChanged(
      TextSelection(baseOffset: fromPosition, extentOffset: toPosition),
      cause,
    );
  }

  void selectWordAt({
    required Offset offset,
    required SelectionChangedCause cause,
  }) {
    handleSelectionChanged(
      getWordRangeAtPoint(offset),
      cause,
    );
  }

  RenderEditableLine getRenderLineAtOffset(Offset globalOffset) {
    final rootRenderBox = this.rootRenderBox;
    final rootOffset = rootRenderBox.globalToLocal(globalOffset);
    final constrainedOffset = Offset(
      rootOffset.dx.clamp(0.0, rootRenderBox.size.width),
      rootOffset.dy.clamp(0.0, rootRenderBox.size.height),
    );
    return (controller.ast.greenRoot.key!.currentContext!.findRenderObject()
                as RenderEditableLine)
            .hittestFindLowest<RenderEditableLine>(constrainedOffset) ??
        controller.ast.greenRoot.key!.currentContext!.findRenderObject()
            as RenderEditableLine;
  }

  RenderBox get rootRenderBox => context.findRenderObject() as RenderBox;

  int getPositionForOffset(Offset globalOffset) {
    final target = getRenderLineAtOffset(globalOffset);
    final caretIndex = target.getCaretIndexForPoint(globalOffset);
    return target.node.pos + target.node.caretPositions[caretIndex];
  }

  Offset getLocalEndpointForPosition(int position) {
    final node = controller.ast.findNodeManagesPosition(position);
    var caretIndex = node.caretPositions
        .indexWhere((caretPosition) => caretPosition >= position);
    if (caretIndex == -1) {
      caretIndex = node.caretPositions.length - 1;
    }
    final renderLine =
        node.key!.currentContext!.findRenderObject() as RenderEditableLine;
    final globalOffset = renderLine.getEndpointForCaretIndex(caretIndex);

    return rootRenderBox.globalToLocal(globalOffset);
  }

  TextSelection getWordRangeAtPoint(Offset globalOffset) {
    final target = getRenderLineAtOffset(globalOffset);
    final caretIndex = target.getNearestLeftCaretIndexForPoint(globalOffset);
    final node = target.node;
    final extentCaretIndex = math.max(
      0,
      caretIndex + 1 >= node.caretPositions.length
          ? caretIndex - 1
          : caretIndex + 1,
    );
    final base = node.pos + node.caretPositions[caretIndex];
    final extent = node.pos + node.caretPositions[extentCaretIndex];
    return TextSelection(
      baseOffset: math.min(base, extent),
      extentOffset: math.max(base, extent),
    );
  }

  TextSelection getWordsRangeInRange({
    required Offset from,
    required Offset to,
  }) {
    final range1 = getWordRangeAtPoint(from);
    final range2 = getWordRangeAtPoint(to);

    if (range1.start <= range2.start) {
      return TextSelection(baseOffset: range1.start, extentOffset: range2.end);
    } else {
      return TextSelection(baseOffset: range1.end, extentOffset: range2.start);
    }
  }

  Rect getLocalEditingRegion() {
    final root = controller.ast.greenRoot.key!.currentContext!
        .findRenderObject() as RenderEditableLine;
    return Rect.fromPoints(
      Offset.zero,
      root.size.bottomRight(Offset.zero),
    );
  }

  @override
  void bringIntoView(TextPosition position) {
    // SelectableMath is not itself scrollable, but it can live inside a
    // scrollable parent. Reveal the syntax node containing the requested
    // position when such a parent exists.
    final node = controller.ast.findNodeManagesPosition(position.offset);
    final targetContext = node.key?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      unawaited(Scrollable.ensureVisible(targetContext));
    }
  }

  @override
  void userUpdateTextEditingValue(
    TextEditingValue value,
    SelectionChangedCause cause,
  ) {
    // The math surface is read-only. Accept selection-only updates from the
    // platform text-input bridge while ignoring attempts to edit its content.
    if (value.text == textEditingValue.text) {
      textEditingValue = value;
    }
  }

  @override
  void selectAll(SelectionChangedCause cause) {
    final end = math.max(0, controller.ast.greenRoot.capturedCursor - 1);
    handleSelectionChanged(
      TextSelection(baseOffset: 0, extentOffset: end),
      cause,
    );
    if (cause == SelectionChangedCause.toolbar) {
      bringIntoView(TextPosition(offset: controller.selection.extentOffset));
    }
  }

  @override
  void copySelection(SelectionChangedCause cause) {
    if (!copyEnabled || controller.selection.isCollapsed) return;
    final selectedTex = controller.selectedNodes.encodeTex();
    unawaited(Clipboard.setData(ClipboardData(text: selectedTex)));
    if (cause == SelectionChangedCause.toolbar) {
      bringIntoView(TextPosition(offset: controller.selection.extentOffset));
      hideToolbar();
    }
  }

  @override
  void cutSelection(SelectionChangedCause cause) {
    // SelectableMath is read-only; cutting is intentionally disabled.
  }

  @override
  Future<void> pasteText(SelectionChangedCause cause) async {
    // SelectableMath is read-only; pasting is intentionally disabled.
  }

  @override
  TextEditingValue get textEditingValue {
    final encodeResult = controller.selectedNodes.encodeTex();
    String string;
    if (controller.selection.start == 0 &&
        controller.selection.end ==
            controller.ast.greenRoot.capturedCursor - 1) {
      string = encodeResult;
    } else {
      string = '$encodeResult$_selectAllReservedTag';
    }
    return TextEditingValue(
      text: string,
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: encodeResult.length,
      ),
    );
  }

  static const _selectAllReservedTag = 'THIS MARKUP SHOULD NOT APPEAR!';

  set textEditingValue(TextEditingValue value) {
    // Select All ?
    if (value.selection.start == 0 &&
        value.selection.end == value.text.length &&
        value.text.length > controller.ast.greenRoot.capturedCursor - 1) {
      handleSelectionChanged(
        TextSelection(
          baseOffset: 0,
          extentOffset: controller.ast.greenRoot.capturedCursor - 1,
        ),
        null,
        ExtraSelectionChangedCause.handle,
      );
    }
  }
}
