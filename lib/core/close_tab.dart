// "Buzz Out" closes the browser tab. That needs the browser, so the web
// implementation sits behind a conditional export and everything else (the
// tests, the analyzer, a future desktop build) gets a no-op.
export 'close_tab_stub.dart' if (dart.library.js_interop) 'close_tab_web.dart';
