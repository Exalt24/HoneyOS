import 'package:web/web.dart' as web;

/// Navigates the tab to a blank page, then asks the browser to close it. Browsers
/// only honour close() for tabs a script opened, so the blank page is the
/// fallback the original app used.
void closeTab() {
  web.window.open('about:blank', '_self');
  web.window.close();
}
