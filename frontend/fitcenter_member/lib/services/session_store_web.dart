import 'dart:js_interop';

import 'session_store.dart';

@JS('window.sessionStorage')
external _Storage get _storage;

extension type _Storage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

const _key = 'fitcenter.member.session';

class _TabSessionStore implements SessionStore {
  // Storage can be blocked by the browser; the app then behaves as without it.
  @override
  String? read() {
    try {
      return _storage.getItem(_key);
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String value) {
    try {
      _storage.setItem(_key, value);
    } catch (_) {}
  }

  @override
  void clear() {
    try {
      _storage.removeItem(_key);
    } catch (_) {}
  }
}

SessionStore? createTabSessionStore() => _TabSessionStore();
