import 'package:flutter_test/flutter_test.dart';
import 'package:idura_verify/idura_verify.dart';
import 'package:idura_verify/idura_verify_platform_interface.dart';
import 'package:idura_verify/idura_verify_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockIduraVerifyPlatform
    with MockPlatformInterfaceMixin
    implements IduraVerifyPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final IduraVerifyPlatform initialPlatform = IduraVerifyPlatform.instance;

  test('$MethodChannelIduraVerify is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelIduraVerify>());
  });

  test('getPlatformVersion', () async {
    IduraVerify iduraVerifyPlugin = IduraVerify();
    MockIduraVerifyPlatform fakePlatform = MockIduraVerifyPlatform();
    IduraVerifyPlatform.instance = fakePlatform;

    expect(await iduraVerifyPlugin.getPlatformVersion(), '42');
  });
}
