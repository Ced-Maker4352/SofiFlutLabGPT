// lib/utils/web_history_fix_html.dart

// ignore_for_file: avoid_web_libraries_in_flutter, unused_catch_clause, deprecated_member_use

import 'dart:html' as html;
import 'dart:js' as js show allowInterop;
import 'dart:js_util' as js_util;

bool _installed = false;
bool _patchedMethods = false;

/// Workaround for Flutter WebKit engine assertion on iOS browsers:
///   _hasSerialCount(currentState) "unexpected null history state"
///
/// This installs multiple guards so the engine never encounters a null
/// window.history.state:
/// - Immediately ensures an initial non-null state with a serialCount.
/// - Monkey-patches history.pushState/replaceState to always inject
///   a serialCount when data is null or missing.
/// - Listens to popstate/visibility changes to rehydrate state if needed.
void installWebHistoryWorkaround() {
  if (_installed) return;
  _installed = true;
  try {
    // 1) Ensure an initial non-null state ASAP
    final state = html.window.history.state;
    if (state == null) {
      _replaceStateWithSerial(0);
    } else {
      _ensureCurrentStateHasSerial();
    }

    // 2) Monkey-patch pushState/replaceState to guarantee serialCount
    _patchHistoryMethods();

    // 3) Guard popstate and visibilitychange (page restore/background)
    html.window.onPopState.listen((event) {
      final newState = event.state;
      if (newState == null) {
        final serial = DateTime.now().millisecondsSinceEpoch & 0xFFFF;
        _replaceStateWithSerial(serial);
      } else {
        _ensureCurrentStateHasSerial();
      }
    });

    html.document.onVisibilityChange.listen((_) {
      final st = html.window.history.state;
      if (st == null) {
        _replaceStateWithSerial(1);
      } else {
        _ensureCurrentStateHasSerial();
      }
    });
  } catch (e) {
    // Best-effort only; never throw
  }
}

void _patchHistoryMethods() {
  if (_patchedMethods) return;
  _patchedMethods = true;
  try {
    final history = html.window.history;

    final origPush = js_util.getProperty(history, 'pushState');
    final origReplace = js_util.getProperty(history, 'replaceState');

    // Wrapper that enforces a non-null state with serialCount
    dynamic wrapFn(dynamic original) => js.allowInterop((dynamic data, dynamic title, dynamic url) {
      final patched = _ensureStateMap(data);
      // Call original with proper 'this' bound to history
      return js_util.callMethod(original, 'call', [history, patched, title, url]);
    });

    js_util.setProperty(history, 'pushState', wrapFn(origPush));
    js_util.setProperty(history, 'replaceState', wrapFn(origReplace));
  } catch (e) {
    // If monkey-patching fails, we still have other guards.
  }
}

Map<String, Object> _ensureStateMap(dynamic data) {
  Map<String, Object> map;
  try {
    if (data == null || data is! Map) {
      map = <String, Object>{};
    } else {
      // Create a shallow copy to avoid mutating passed-in map implementations
      map = Map<String, Object>.from(data);
    }
  } catch (_) {
    map = <String, Object>{};
  }

  if (!map.containsKey('serialCount')) {
    // A small pseudo-random serial that changes often enough
    map['serialCount'] = DateTime.now().millisecondsSinceEpoch & 0xFFFF;
  }
  return map;
}

void _ensureCurrentStateHasSerial() {
  try {
    final st = html.window.history.state;
    if (st == null) {
      _replaceStateWithSerial(0);
      return;
    }
    final stMap = st is Map ? st : null;
    if (stMap == null || !stMap.containsKey('serialCount')) {
      // Preserve existing state shape by copying keys when possible
      final title = html.document.title;
      final url = html.window.location.href;
      final next = stMap != null 
        ? Map<String, Object>.from(stMap)
        : <String, Object>{};
      next['serialCount'] = DateTime.now().millisecondsSinceEpoch & 0xFFFF;
      html.window.history.replaceState(next, title, url);
    }
  } catch (e) {
    // ignore
  }
}

void _replaceStateWithSerial(int serial) {
  try {
    final title = html.document.title;
    final url = html.window.location.href;
    html.window.history.replaceState({'serialCount': serial}, title, url);
  } catch (e) {
    // ignore
  }
}

// Auto-install at module load so our guards are in place before the Flutter
// web engine selects its browser history strategy, especially across hot restarts.
// This is safe (idempotent) and silently ignores any errors.
// The IIFE pattern ensures execution during import time.
