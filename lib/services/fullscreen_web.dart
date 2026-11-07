import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject get _document => globalContext.getProperty<JSObject>('document'.toJS);

/// Must be called from a user gesture (e.g. the Start button's onPressed).
/// Hides the browser tab strip / address bar so other tabs aren't visible.
void enterBrowserFullscreen() {
  try {
    final root = _document.getProperty<JSObject>('documentElement'.toJS);
    root.callMethod('requestFullscreen'.toJS);
    // Chrome/Edge: stop Esc from leaving fullscreen instantly (hold Esc to exit).
    final nav = globalContext.getProperty<JSObject>('navigator'.toJS);
    final keyboard = nav.getProperty<JSObject?>('keyboard'.toJS);
    if (keyboard != null) {
      keyboard.callMethod('lock'.toJS, ['Escape'.toJS].toJS);
    }
  } catch (_) {}
}

void exitBrowserFullscreen() {
  try {
    final nav = globalContext.getProperty<JSObject>('navigator'.toJS);
    final keyboard = nav.getProperty<JSObject?>('keyboard'.toJS);
    keyboard?.callMethod('unlock'.toJS);
    final el = _document.getProperty<JSObject?>('fullscreenElement'.toJS);
    if (el != null) _document.callMethod('exitFullscreen'.toJS);
  } catch (_) {}
}

bool _listening = false;

void listenFullscreenExit(void Function() onExit) {
  if (_listening) return;
  _listening = true;
  void handler(JSAny event) {
    final el = _document.getProperty<JSObject?>('fullscreenElement'.toJS);
    if (el == null) onExit();
  }
  _document.callMethod('addEventListener'.toJS, 'fullscreenchange'.toJS, handler.toJS);
}
