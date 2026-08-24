import 'dart:convert';

import 'models.dart';

/// Kept as one file rather than a directory, mirroring the iOS SDK's single
/// `EID.swift`, so a change there ports across by reading the two side by side.
///
/// Every builder is immutable: `withX()` returns a new instance and never
/// mutates the receiver, matching the iOS structs rather than the mutable
/// Kotlin classes. That is what makes branching off a partially built eID safe.

/// Standard base64 with padding, which is what both native SDKs emit for
/// `message:` and `mock:` hints.
String _base64(String value) => base64.encode(utf8.encode(value));

/// Which eID to authenticate with, and what to ask it for.
///
/// Build one with a typed factory rather than constructing it directly:
///
/// ```dart
/// await login(DanishMitID.substantial().prefillSsn('1234564444'));
/// ```
///
/// Reach for [Other] when you need an eID or a modifier this package does not
/// model yet. It is not a lesser path: both native SDKs derive app-switch
/// behaviour from the acr value's prefix, so `Other` behaves identically to the
/// typed builder that produces the same value.
abstract class Eid {
  /// Creates an eID. Use a typed factory such as [DanishMitID.substantial] or
  /// [Other.new] instead of calling this.
  Eid({
    required List<String> acrValues,
    List<String> scopes = const [],
    List<String> loginHints = const [],
    this.action,
  }) : acrValues = List.unmodifiable(acrValues),
       scopes = List.unmodifiable(scopes),
       loginHints = List.unmodifiable(loginHints);

  /// The acr value in segments: the eID's base value, then any modifiers.
  final List<String> acrValues;

  /// OIDC scopes beyond `openid`, which the native SDK adds itself.
  final List<String> scopes;

  /// `login_hint` entries, each `key:value`.
  final List<String> loginHints;

  /// The verb the eID app shows the user, when this eID supports setting one.
  final Action? action;

  /// [acrValues] joined by colons, which is the single value that reaches the
  /// authorization endpoint as `acr_values`.
  String get acrValue => acrValues.join(':');

  /// Requests an additional OIDC scope. An escape hatch for scopes this package
  /// does not expose a typed method for.
  Eid withScope(String scope);

  /// Adds a raw `login_hint` entry. An escape hatch for hints this package does
  /// not expose a typed method for.
  Eid withLoginHint(String loginHint);

  // Deliberately no toString(). Login hints can carry a prefilled national
  // identity number, so a default-formatted eID is not safe to log.
}

/// Danish MitID.
///
/// Pick a level with [substantial], [high], [low] or [business]. `substantial`
/// is the usual choice; `high` additionally requires a MitID with a hardware
/// authenticator.
final class DanishMitID extends Eid {
  DanishMitID._({
    required super.acrValues,
    super.scopes,
    super.loginHints,
    super.action,
  });

  DanishMitID._level(String level)
    : this._(acrValues: ['urn:grn:authn:dk:mitid', level]);

  /// The level most integrations want.
  factory DanishMitID.substantial() => DanishMitID._level('substantial');

  /// Requires a hardware authenticator, so not every user can complete it.
  factory DanishMitID.high() => DanishMitID._level('high');

  /// A lower assurance level.
  factory DanishMitID.low() => DanishMitID._level('low');

  /// MitID Erhverv, for authenticating on behalf of a company.
  factory DanishMitID.business() => DanishMitID._level('business');

  DanishMitID _copy({
    List<String>? scopes,
    List<String>? loginHints,
    Action? action,
  }) => DanishMitID._(
    acrValues: acrValues,
    scopes: scopes ?? this.scopes,
    loginHints: loginHints ?? this.loginHints,
    action: action ?? this.action,
  );

  @override
  DanishMitID withScope(String scope) => _copy(scopes: [...scopes, scope]);

  @override
  DanishMitID withLoginHint(String loginHint) =>
      _copy(loginHints: [...loginHints, loginHint]);

  /// Shows the user a message during the flow. Typically used with
  /// [withAction], e.g. to say what they are signing.
  DanishMitID withMessage(String message) =>
      withLoginHint('message:${_base64(message)}');

  /// Changes the verb the MitID app shows, for flows that are not a plain login.
  DanishMitID withAction(Action action) => _copy(action: action);

  /// Requests the user's national identity number as an `ssn` claim.
  DanishMitID withSsn() => withScope('ssn');

  /// Requests the user's address claims.
  DanishMitID withAddress() => withScope('address');

  /// Prefills the flow with a known national identity number, and requests the
  /// `ssn` scope so the claim comes back.
  DanishMitID prefillSsn(String ssn) => withSsn().withLoginHint('sub:$ssn');

  /// Prefills the MitID UUID of a returning user so they can skip entering
  /// their username. Get it from a previous login's `uuid` claim.
  ///
  /// See https://docs.idura.com/verify/e-ids/danish-mitid/#reauthentication
  DanishMitID prefillUuid(String uuid) => withLoginHint('uuid:$uuid');

  /// Prefills a company's Danish VAT id for a MitID Erhverv login. Pass the
  /// digits only; the `DK` prefix is added for you.
  DanishMitID prefillVatId(String vatId) => withLoginHint('vatid:DK$vatId');
}

/// Norwegian BankID.
final class NorwegianBankID extends Eid {
  NorwegianBankID._({
    required super.acrValues,
    super.scopes,
    super.loginHints,
    super.action,
  });

  NorwegianBankID._level(String level)
    : this._(acrValues: ['urn:grn:authn:no:bankid', level]);

  /// The level most integrations want.
  factory NorwegianBankID.substantial() =>
      NorwegianBankID._level('substantial');

  /// A higher assurance level.
  factory NorwegianBankID.high() => NorwegianBankID._level('high');

  NorwegianBankID _copy({
    List<String>? scopes,
    List<String>? loginHints,
    Action? action,
  }) => NorwegianBankID._(
    acrValues: acrValues,
    scopes: scopes ?? this.scopes,
    loginHints: loginHints ?? this.loginHints,
    action: action ?? this.action,
  );

  @override
  NorwegianBankID withScope(String scope) => _copy(scopes: [...scopes, scope]);

  @override
  NorwegianBankID withLoginHint(String loginHint) =>
      _copy(loginHints: [...loginHints, loginHint]);

  /// Requests the user's national identity number as an `ssn` claim.
  NorwegianBankID withSsn() => withScope('ssn');
}

/// Swedish BankID.
///
/// Pick how the user reaches their BankID: [sameDevice] when the app is on this
/// phone, [otherDevice] to show a QR code they scan with another device, or
/// [selectorPage] to let them choose.
final class SwedishBankID extends Eid {
  SwedishBankID._({
    required super.acrValues,
    super.scopes,
    super.loginHints,
    super.action,
  });

  SwedishBankID._modifier(String? modifier)
    : this._(acrValues: ['urn:grn:authn:se:bankid', ?modifier]);

  /// Shows a QR code for the user to scan with BankID on another device.
  factory SwedishBankID.otherDevice() =>
      SwedishBankID._modifier('another-device:qr');

  /// Switches to the BankID app on this device.
  factory SwedishBankID.sameDevice() => SwedishBankID._modifier('same-device');

  /// Lets the user pick same-device or another-device themselves.
  factory SwedishBankID.selectorPage() => SwedishBankID._modifier(null);

  SwedishBankID _copy({
    List<String>? scopes,
    List<String>? loginHints,
    Action? action,
  }) => SwedishBankID._(
    acrValues: acrValues,
    scopes: scopes ?? this.scopes,
    loginHints: loginHints ?? this.loginHints,
    action: action ?? this.action,
  );

  @override
  SwedishBankID withScope(String scope) => _copy(scopes: [...scopes, scope]);

  @override
  SwedishBankID withLoginHint(String loginHint) =>
      _copy(loginHints: [...loginHints, loginHint]);

  /// Shows the user a message during the flow.
  SwedishBankID withMessage(String message) =>
      withLoginHint('message:${_base64(message)}');

  /// Requests the user's personnummer as an `ssn` claim.
  SwedishBankID withSsn() => withScope('ssn');

  /// Asks the user to sign [message] rather than to log in, which is
  /// [withMessage] plus [Action.sign].
  SwedishBankID sign(String message) =>
      withMessage(message)._copy(action: Action.sign);
}

/// Norwegian Vipps.
final class Vipps extends Eid {
  Vipps._({
    required super.acrValues,
    super.scopes,
    super.loginHints,
    super.action,
  });

  /// Vipps takes no level or device modifier.
  factory Vipps() => Vipps._(acrValues: const ['urn:grn:authn:no:vipps']);

  Vipps _copy({
    List<String>? scopes,
    List<String>? loginHints,
    Action? action,
  }) => Vipps._(
    acrValues: acrValues,
    scopes: scopes ?? this.scopes,
    loginHints: loginHints ?? this.loginHints,
    action: action ?? this.action,
  );

  @override
  Vipps withScope(String scope) => _copy(scopes: [...scopes, scope]);

  @override
  Vipps withLoginHint(String loginHint) =>
      _copy(loginHints: [...loginHints, loginHint]);

  /// Requests the user's email address.
  Vipps withEmail() => withScope('email');

  /// Requests the user's phone number.
  Vipps withPhone() => withScope('phone');

  /// Requests the user's address claims.
  Vipps withAddress() => withScope('address');

  /// Requests the user's date of birth.
  Vipps withBirthdate() => withScope('birthdate');

  /// Requests the user's national identity number as an `ssn` claim.
  Vipps withSsn() => withScope('ssn');
}

/// Entry point for Swedish Freja ID, whose registration levels are separate
/// types because only the higher ones can request the extended scopes.
abstract final class FrejaID {
  /// Any Freja account, including one that has never been identity verified.
  static FrejaIDBasic basic() => FrejaIDBasic._create();

  /// Requires an identity-verified account, and unlocks the extended scopes.
  static FrejaIDExtendedOrPlus extended() =>
      FrejaIDExtendedOrPlus._level('extended');

  /// Requires an account verified against a physical identity document, and
  /// unlocks the extended scopes.
  static FrejaIDExtendedOrPlus plus() => FrejaIDExtendedOrPlus._level('plus');
}

/// Freja ID at the `basic` registration level. Create it with [FrejaID.basic].
final class FrejaIDBasic extends Eid {
  FrejaIDBasic._({
    required super.acrValues,
    super.scopes,
    super.loginHints,
    super.action,
  });

  FrejaIDBasic._create()
    : this._(
        acrValues: const ['urn:grn:authn:se:frejaid'],
        loginHints: const ['minregistrationlevel:basic'],
      );

  FrejaIDBasic _copy({
    List<String>? scopes,
    List<String>? loginHints,
    Action? action,
  }) => FrejaIDBasic._(
    acrValues: acrValues,
    scopes: scopes ?? this.scopes,
    loginHints: loginHints ?? this.loginHints,
    action: action ?? this.action,
  );

  @override
  FrejaIDBasic withScope(String scope) => _copy(scopes: [...scopes, scope]);

  @override
  FrejaIDBasic withLoginHint(String loginHint) =>
      _copy(loginHints: [...loginHints, loginHint]);

  /// Requests the user's primary email address.
  FrejaIDBasic withEmail() => withScope('frejaid:email_address');

  /// Requests every email address on the account.
  FrejaIDBasic withAllEmails() => withScope('frejaid:all_email_addresses');

  /// Requests every phone number on the account.
  FrejaIDBasic withPhoneNumbers() => withScope('frejaid:all_phone_numbers');

  /// Requests the account's registration level as a claim.
  FrejaIDBasic withRegistrationLevel() =>
      withScope('frejaid:registration_level');

  /// Asks the user to sign [message] rather than to log in. [title] is shown
  /// above the message in the Freja app.
  FrejaIDBasic sign(String message, {String? title}) {
    var result = _copy(action: Action.sign);
    if (title != null) {
      result = result.withLoginHint('title:${_base64(title)}');
    }
    return result.withLoginHint('message:${_base64(message)}');
  }
}

/// Freja ID at the `extended` or `plus` registration level. Create it with
/// [FrejaID.extended] or [FrejaID.plus].
///
/// Both levels share a type because they differ only in the
/// `minregistrationlevel` hint, and expose the same extended scopes.
final class FrejaIDExtendedOrPlus extends Eid {
  FrejaIDExtendedOrPlus._({
    required super.acrValues,
    super.scopes,
    super.loginHints,
    super.action,
  });

  FrejaIDExtendedOrPlus._level(String level)
    : this._(
        acrValues: const ['urn:grn:authn:se:frejaid'],
        loginHints: ['minregistrationlevel:$level'],
      );

  FrejaIDExtendedOrPlus _copy({
    List<String>? scopes,
    List<String>? loginHints,
    Action? action,
  }) => FrejaIDExtendedOrPlus._(
    acrValues: acrValues,
    scopes: scopes ?? this.scopes,
    loginHints: loginHints ?? this.loginHints,
    action: action ?? this.action,
  );

  @override
  FrejaIDExtendedOrPlus withScope(String scope) =>
      _copy(scopes: [...scopes, scope]);

  @override
  FrejaIDExtendedOrPlus withLoginHint(String loginHint) =>
      _copy(loginHints: [...loginHints, loginHint]);

  /// Requests the user's primary email address.
  FrejaIDExtendedOrPlus withEmail() => withScope('frejaid:email_address');

  /// Requests every email address on the account.
  FrejaIDExtendedOrPlus withAllEmails() =>
      withScope('frejaid:all_email_addresses');

  /// Requests every phone number on the account.
  FrejaIDExtendedOrPlus withPhoneNumbers() =>
      withScope('frejaid:all_phone_numbers');

  /// Requests the account's registration level as a claim.
  FrejaIDExtendedOrPlus withRegistrationLevel() =>
      withScope('frejaid:registration_level');

  /// Requests the user's name and other basic profile claims.
  FrejaIDExtendedOrPlus withBasicUserInfo() =>
      withScope('frejaid:basic_user_info');

  /// Requests the user's date of birth.
  FrejaIDExtendedOrPlus withDateOfBirth() => withScope('frejaid:date_of_birth');

  /// Requests the user's age.
  FrejaIDExtendedOrPlus withAge() => withScope('frejaid:age');

  /// Requests the user's personnummer.
  FrejaIDExtendedOrPlus withSsn() => withScope('frejaid:ssn');

  /// Requests the user's addresses.
  FrejaIDExtendedOrPlus withAddresses() => withScope('frejaid:addresses');

  /// Requests the identity document backing the account.
  FrejaIDExtendedOrPlus withDocument() => withScope('frejaid:document');

  /// Requests the user's photo.
  FrejaIDExtendedOrPlus withPhoto() => withScope('frejaid:photo');

  /// Requests the photo from the user's identity document.
  FrejaIDExtendedOrPlus withDocumentPhoto() =>
      withScope('frejaid:document_photo');

  /// Requires a face scan in addition to the default confirmation method.
  FrejaIDExtendedOrPlus withDefaultAndFaceConfirmation() =>
      withLoginHint('userconfirmationmethod:defaultandface');

  /// Asks the user to sign [message] rather than to log in. [title] is shown
  /// above the message in the Freja app.
  FrejaIDExtendedOrPlus sign(String message, {String? title}) {
    var result = _copy(action: Action.sign);
    if (title != null) {
      result = result.withLoginHint('title:${_base64(title)}');
    }
    return result.withLoginHint('message:${_base64(message)}');
  }
}

/// A test eID that needs no authenticator app, so it is the only flow that runs
/// on an Android emulator. Enable it per domain in the Idura dashboard.
///
/// Still impossible on the iOS Simulator: the associated-domains entitlement
/// the callback needs is stripped there.
final class Mock extends Eid {
  Mock._({
    required super.acrValues,
    super.scopes,
    super.loginHints,
    super.action,
  });

  /// A mock login that returns the domain's default claims.
  factory Mock() => Mock._(acrValues: const ['urn:grn:authn:mock']);

  Mock _copy({
    List<String>? scopes,
    List<String>? loginHints,
    Action? action,
  }) => Mock._(
    acrValues: acrValues,
    scopes: scopes ?? this.scopes,
    loginHints: loginHints ?? this.loginHints,
    action: action ?? this.action,
  );

  @override
  Mock withScope(String scope) => _copy(scopes: [...scopes, scope]);

  @override
  Mock withLoginHint(String loginHint) =>
      _copy(loginHints: [...loginHints, loginHint]);

  /// Inserts [data] into the returned ID token's claims, so you can drive a
  /// test through a known identity.
  Mock withMockData(Map<String, Object?> data) =>
      withLoginHint('mock:${_base64(jsonEncode(data))}');
}

/// Any eID by its acr value, for one this package does not model yet or a
/// modifier it does not expose.
///
/// Behaviourally identical to the typed builder that produces the same value:
/// both native SDKs decide on app-switch from the acr value's prefix, not from
/// which builder produced it.
final class Other extends Eid {
  Other._({
    required super.acrValues,
    super.scopes,
    super.loginHints,
    super.action,
  });

  /// [acrValue] is the complete value including any modifiers, e.g.
  /// `urn:grn:authn:dk:mitid:substantial`.
  factory Other(String acrValue) => Other._(acrValues: [acrValue]);

  Other _copy({
    List<String>? scopes,
    List<String>? loginHints,
    Action? action,
  }) => Other._(
    acrValues: acrValues,
    scopes: scopes ?? this.scopes,
    loginHints: loginHints ?? this.loginHints,
    action: action ?? this.action,
  );

  @override
  Other withScope(String scope) => _copy(scopes: [...scopes, scope]);

  @override
  Other withLoginHint(String loginHint) =>
      _copy(loginHints: [...loginHints, loginHint]);

  // Deliberately no withMessage or withAction, matching the iOS SDK where
  // `Other` conforms to plain `EID`. Whether an eID supports them is not
  // knowable from an arbitrary acr value, so an untyped eID gets the untyped
  // escape hatch: withLoginHint('message:<base64>') or 'action:<verb>'.
}

/// The country whose age-verification rules apply.
enum AgeVerificationCountry {
  /// Denmark.
  denmark('DK'),

  /// Sweden.
  sweden('SE'),

  /// Norway.
  norway('NO'),

  /// Finland.
  finland('FI');

  const AgeVerificationCountry(this.wireValue);

  /// The value sent as the `country:` login hint.
  final String wireValue;
}

/// The age threshold to verify against.
enum AgeVerificationAge {
  /// 15 or older.
  over15(15),

  /// 16 or older.
  over16(16),

  /// 18 or older.
  over18(18),

  /// 21 or older.
  over21(21);

  const AgeVerificationAge(this.years);

  /// The number in the requested `is_over_N` scope and claim.
  final int years;
}

/// Age verification, which returns an `is_over_N` boolean claim instead of
/// identifying the user.
final class AgeVerification extends Eid {
  AgeVerification._({
    required super.acrValues,
    super.scopes,
    super.loginHints,
    super.action,
  });

  /// Verifies the user is at least [age].
  ///
  /// Note the acr value's shape: unlike every other eID it has no `grn:authn`
  /// segment, so it is not a typo.
  factory AgeVerification.over(AgeVerificationAge age) =>
      AgeVerification._(acrValues: const ['urn:age-verification']).over(age);

  AgeVerification _copy({
    List<String>? scopes,
    List<String>? loginHints,
    Action? action,
  }) => AgeVerification._(
    acrValues: acrValues,
    scopes: scopes ?? this.scopes,
    loginHints: loginHints ?? this.loginHints,
    action: action ?? this.action,
  );

  @override
  AgeVerification withScope(String scope) => _copy(scopes: [...scopes, scope]);

  @override
  AgeVerification withLoginHint(String loginHint) =>
      _copy(loginHints: [...loginHints, loginHint]);

  /// Adds a second threshold, so one login can answer more than one question.
  AgeVerification over(AgeVerificationAge age) =>
      withScope('is_over_${age.years}');

  /// Restricts which eIDs are offered to those of [country].
  AgeVerification withCountry(AgeVerificationCountry country) =>
      withLoginHint('country:${country.wireValue}');
}
