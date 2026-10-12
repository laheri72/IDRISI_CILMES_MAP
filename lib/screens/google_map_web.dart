import 'package:flutter/material.dart';
import 'dart:ui_web' as ui;
import 'package:web/web.dart' as web;

bool _registered = false;

Widget getGoogleMapWidget(String url) {
  const String viewType = 'google-my-map-iframe';

  if (!_registered) {
    ui.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = web.HTMLIFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      },
    );
    _registered = true;
  }

  return const HtmlElementView(viewType: viewType);
}
