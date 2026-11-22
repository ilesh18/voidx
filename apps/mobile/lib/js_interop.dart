// lib/js_interop.dart
// Platform-safe JavaScript interop for the legacy Home.dart web integration
// (Windy map callbacks). On Android (non-web) these are no-ops so the release
// build compiles without dart:js (which is web-only).
import 'js_interop_stub.dart' if (dart.library.js) 'js_interop_web.dart';

void jsCall(String method, [List<dynamic>? args]) => jsImplCall(method, args);
void jsSet(String key, dynamic value) => jsImplSet(key, value);
dynamic jsGet(String key) => jsImplGet(key);
