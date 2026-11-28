import 'session_store_stub.dart'
    if (dart.library.js_interop) 'session_store_web.dart'
    as platform;

/// Optional place to keep the signed-in session across a page reload.
abstract class SessionStore {
  String? read();
  void write(String value);
  void clear();
}

/// Local testing aid, OFF unless built with
/// --dart-define=KEEP_SESSION_ON_RELOAD=true. Release builds keep tokens in
/// memory only.
const keepSessionOnReload = bool.fromEnvironment('KEEP_SESSION_ON_RELOAD');

/// Browser tab storage (cleared when the tab closes); null on other platforms.
SessionStore? tabSessionStore() => platform.createTabSessionStore();
