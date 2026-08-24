import 'idura_verify_platform_interface.dart';

class IduraVerify {
  Future<String?> getPlatformVersion() {
    return IduraVerifyPlatform.instance.getPlatformVersion();
  }
}
