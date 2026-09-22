import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class PreviewSecurityService {
  Future<void> setPreviewProtected(bool protected);
}

class PlatformPreviewSecurityService implements PreviewSecurityService {
  static const _channel = MethodChannel('stealth_breaker/preview_security');
  bool _protected = false;

  @override
  Future<void> setPreviewProtected(bool protected) async {
    if (_protected == protected) return;
    _protected = protected;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>(
          protected ? 'enableSecurePreview' : 'disableSecurePreview');
    } on MissingPluginException {
      // Other embedders intentionally have no native secure-window handler.
    } on PlatformException {
      // A window transition must never stop gameplay from progressing.
    }
  }
}

class NoopPreviewSecurityService implements PreviewSecurityService {
  const NoopPreviewSecurityService();
  @override
  Future<void> setPreviewProtected(bool protected) async {}
}
