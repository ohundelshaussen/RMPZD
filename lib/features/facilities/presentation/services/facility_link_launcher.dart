import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class FacilityLinkLauncher {
  Future<bool> launch(Uri uri);
}

class UrlFacilityLinkLauncher implements FacilityLinkLauncher {
  const UrlFacilityLinkLauncher();

  @override
  Future<bool> launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
