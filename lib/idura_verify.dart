/// Accept Danish MitID, Swedish BankID, Norwegian BankID, Vipps and Freja ID
/// eID logins in your Flutter app with Idura Verify.
///
/// This is the only entry point consumers import. Everything under `lib/src/`
/// is package-private, including the generated Pigeon bridge.
library;

export 'src/acr_values.dart';
export 'src/exceptions.dart';
export 'src/jwt.dart';
export 'src/login_result.dart';
// The generated bridge is an implementation detail, but these two are part of
// the public surface, so they are re-exported by name rather than duplicated
// into hand-written enums that could drift from the schema.
export 'src/messages.g.dart' show NotConfiguredCode, Prompt;
export 'src/models.dart';
