import 'package:flutter/material.dart';
import 'dart:ui_web' as ui;
import 'package:web/web.dart' as web;

bool _registered = false;

Widget getGoogleMapWidget(String url) {
  const String viewType = 'google-my-map-iframe';

  if (!_registered) {
    ui.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId, {Object? params}) {
        final iframe = web.HTMLIFrameElement()
          ..src = params as String
          ..title = 'Ikhwan climes custom modern map'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      },
    );
    _registered = true;
  }

  return HtmlElementView(
      key: ValueKey(url), viewType: viewType, creationParams: url);
}
