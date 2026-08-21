import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'idura_verify_method_channel.dart';

abstract class IduraVerifyPlatform extends PlatformInterface {
  /// Constructs a IduraVerifyPlatform.
  IduraVerifyPlatform() : super(token: _token);

  static final Object _token = Object();

  static IduraVerifyPlatform _instance = MethodChannelIduraVerify();

  /// The default instance of [IduraVerifyPlatform] to use.
  ///
  /// Defaults to [MethodChannelIduraVerify].
  static IduraVerifyPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [IduraVerifyPlatform] when
  /// they register themselves.
  static set instance(IduraVerifyPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
