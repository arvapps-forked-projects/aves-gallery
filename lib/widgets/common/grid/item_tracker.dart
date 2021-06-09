import 'dart:async';

import 'package:aves/model/highlight.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/widgets/common/grid/section_layout.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

mixin GridItemTrackerMixin<T, U extends StatefulWidget> on State<U>, WidgetsBindingObserver {
  ValueNotifier<double> get appBarHeightNotifier;

  ScrollController get scrollController;

  GlobalKey get scrollableKey;

  Size get scrollableSize {
    final scrollableContext = scrollableKey.currentContext!;
    return (scrollableContext.findRenderObject() as RenderBox).size;
  }

  Orientation get _windowOrientation {
    final size = WidgetsBinding.instance!.window.physicalSize;
    return size.width > size.height ? Orientation.landscape : Orientation.portrait;
  }

  final List<StreamSubscription> _subscriptions = [];

  // grid section metrics before the app is laid out with the new orientation
  late SectionedListLayout<T> _lastSectionedListLayout;
  late Size _lastScrollableSize;
  late Orientation _lastOrientation;

  @override
  void initState() {
    super.initState();
    final highlightInfo = context.read<HighlightInfo>();
    _subscriptions.add(highlightInfo.eventBus.on<TrackEvent<T>>().listen((e) => _trackItem(
          e.item,
          alignment: e.alignment,
          animate: e.animate,
          highlightItem: e.highlightItem,
        )));
    WidgetsBinding.instance!.addObserver(this);
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _lastSectionedListLayout = context.read<SectionedListLayout<T>>();
      _lastScrollableSize = scrollableSize;
      _lastOrientation = _windowOrientation;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
    super.dispose();
  }

  // about scrolling & offset retrieval:
  // `Scrollable.ensureVisible` only works on already rendered objects
  // `RenderViewport.showOnScreen` can find any `RenderSliver`, but not always a `RenderMetadata`
  // `RenderViewport.scrollOffsetOf` is a good alternative
  Future<void> _trackItem(
    T item, {
    required Alignment alignment,
    required bool animate,
    required Object? highlightItem,
  }) async {
    final sectionedListLayout = context.read<SectionedListLayout<T>>();
    final tileRect = sectionedListLayout.getTileRect(item);
    if (tileRect == null) return;

    // most of the time the app bar will be scrolled away after scaling,
    // so we compensate for it to center the focal point thumbnail
    final appBarHeight = appBarHeightNotifier.value;
    final scrollOffset = appBarHeight + tileRect.top + (tileRect.height - scrollableSize.height) * ((alignment.y + 1) / 2);

    if (animate) {
      if (scrollOffset > 0) {
        await scrollController.animateTo(
          scrollOffset,
          duration: Duration(milliseconds: (scrollOffset / 2).round().clamp(Durations.highlightScrollAnimationMinMillis, Durations.highlightScrollAnimationMaxMillis)),
          curve: Curves.easeInOutCubic,
        );
      }
    } else {
      final maxScrollExtent = scrollController.position.maxScrollExtent;
      scrollController.jumpTo(scrollOffset.clamp(.0, maxScrollExtent));
      await Future.delayed(Durations.highlightJumpDelay);
    }

    if (highlightItem != null) {
      context.read<HighlightInfo>().set(highlightItem);
    }
  }

  @override
  void didChangeMetrics() {
    // the timing of `didChangeMetrics` is unreliable w.r.t. `MediaQuery` update (and following app layout)
    // most of the time, this is called before `MediaQuery` is updated, but not all the time
    final orientation = _windowOrientation;
    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
      _onWindowOrientationChange();
    }
  }

  void _onWindowOrientationChange() {
    final layout = _lastSectionedListLayout;
    final halfSize = _lastScrollableSize / 2;
    final center = Offset(
      halfSize.width,
      halfSize.height + scrollController.offset - appBarHeightNotifier.value,
    );
    var pivotItem = layout.getItemAt(center) ?? layout.getItemAt(Offset(0, center.dy));
    if (pivotItem == null) {
      final pivotSectionKey = layout.getSectionAt(center.dy)?.sectionKey;
      if (pivotSectionKey != null) {
        pivotItem = layout.sections[pivotSectionKey]?.firstOrNull;
      }
    }

    WidgetsBinding.instance!.addPostFrameCallback((_) {
      if (pivotItem != null) {
        context.read<HighlightInfo>().trackItem(pivotItem, animate: false);
      }
      _lastSectionedListLayout = context.read<SectionedListLayout<T>>();
      _lastScrollableSize = scrollableSize;
    });
  }
}
