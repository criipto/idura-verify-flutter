/// The acr values the Idura Verify backend recognises, one per eID.
///
/// The typed builders in `eid/` produce these for you, so you only need them
/// when reaching for `Other` — either for an eID this package does not model yet
/// or to pin a modifier we do not expose.
///
/// A full acr value is these joined with any modifiers by a colon, e.g.
/// `urn:grn:authn:dk:mitid:substantial`.
abstract final class AcrValues {
  /// Danish MitID. Takes a level modifier: `low`, `substantial`, `high` or
  /// `business`.
  static const String danishMitId = 'urn:grn:authn:dk:mitid';

  /// Norwegian BankID. Takes a level modifier: `substantial` or `high`.
  static const String norwegianBankId = 'urn:grn:authn:no:bankid';

  /// Swedish BankID. Takes a device modifier: `same-device` or `another-device`.
  static const String swedishBankId = 'urn:grn:authn:se:bankid';

  /// Swedish Freja ID. The registration level travels as a
  /// `minregistrationlevel:` login hint rather than an acr modifier.
  static const String swedishFrejaId = 'urn:grn:authn:se:frejaid';

  /// Norwegian Vipps.
  static const String norwegianVipps = 'urn:grn:authn:no:vipps';

  /// Age verification, which returns an `is_over_N` claim instead of an
  /// identity. Note the shape: no `grn:authn` segment.
  static const String ageVerification = 'urn:age-verification';

  /// A test eID that needs no authenticator app, so it is the only flow that
  /// runs on an emulator. Enable it per domain in the Idura dashboard.
  static const String mock = 'urn:grn:authn:mock';
}
