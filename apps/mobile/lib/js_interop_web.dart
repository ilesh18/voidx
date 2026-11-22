// lib/js_interop_web.dart — browser implementation
import 'dart:js' as js;

void jsImplCall(String method, [List<dynamic>? args]) =>
    js.context.callMethod(method, args ?? []);
void jsImplSet(String key, dynamic value) => js.context[key] = value;
dynamic jsImplGet(String key) => js.context[key];
