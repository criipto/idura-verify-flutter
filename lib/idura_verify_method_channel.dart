import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'idura_verify_platform_interface.dart';

/// An implementation of [IduraVerifyPlatform] that uses method channels.
class MethodChannelIduraVerify extends IduraVerifyPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('idura_verify');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
