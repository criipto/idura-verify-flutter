import 'package:flutter_test/flutter_test.dart';
import 'package:idura_verify/idura_verify.dart';

/// The acr value, scopes and hints are the plugin's entire contract with the
/// backend: the native side only replays them onto `Other(acrValue)`, so a typo
/// here is a login that fails on a real device and nowhere earlier. These are
/// ported from `idura-verify-ios/Tests/IduraVerifyTests/EIDTest.swift` plus one
/// case per builder, so the two SDKs can be diffed against each other.
///
/// Two of the iOS cases do not port: `supportsAppSwitch_typedBuilders` and
/// `supportsAppSwitch_otherFallback` assert on `EID.supportsAppSwitch`, which is
/// SDK-internal and derived from the acr value's prefix on the native side. Dart
/// never sees it.
void main() {
  group('Danish MitID', () {
    test('levels produce the documented acr values', () {
      expect(DanishMitID.low().acrValue, 'urn:grn:authn:dk:mitid:low');
      expect(
        DanishMitID.substantial().acrValue,
        'urn:grn:authn:dk:mitid:substantial',
      );
      expect(DanishMitID.high().acrValue, 'urn:grn:authn:dk:mitid:high');
      expect(
        DanishMitID.business().acrValue,
        'urn:grn:authn:dk:mitid:business',
      );
    });

    test('withSsn requests the scope only', () {
      final eid = DanishMitID.substantial().withSsn();

      expect(eid.acrValue, 'urn:grn:authn:dk:mitid:substantial');
      expect(eid.scopes, ['ssn']);
      expect(eid.loginHints, isEmpty);
    });

    test('prefillSsn requests the scope as well as prefilling', () {
      final eid = DanishMitID.high().prefillSsn('1234564444');

      expect(eid.acrValue, 'urn:grn:authn:dk:mitid:high');
      expect(eid.scopes, ['ssn']);
      expect(eid.loginHints, ['sub:1234564444']);
    });

    test('prefillUuid and prefillVatId add hints, not scopes', () {
      expect(DanishMitID.substantial().prefillUuid('abc').loginHints, [
        'uuid:abc',
      ]);
      expect(DanishMitID.business().prefillVatId('12345678').loginHints, [
        'vatid:DK12345678',
      ]);
      expect(DanishMitID.substantial().prefillUuid('abc').scopes, isEmpty);
    });

    test('withAddress requests the scope', () {
      expect(DanishMitID.substantial().withAddress().scopes, ['address']);
    });

    test('withMessage base64 encodes, withAction is separate', () {
      final eid = DanishMitID.substantial()
          .withMessage('Approve payment')
          .withAction(Action.approve);

      expect(eid.loginHints, ['message:QXBwcm92ZSBwYXltZW50']);
      expect(eid.action, Action.approve);
    });
  });

  group('Norwegian BankID', () {
    test('levels produce the documented acr values', () {
      expect(
        NorwegianBankID.substantial().acrValue,
        'urn:grn:authn:no:bankid:substantial',
      );
      expect(NorwegianBankID.high().acrValue, 'urn:grn:authn:no:bankid:high');
    });

    test('withSsn requests the scope', () {
      expect(NorwegianBankID.high().withSsn().scopes, ['ssn']);
    });
  });

  group('Swedish BankID', () {
    test(
      'device choice becomes an acr modifier, and selectorPage adds none',
      () {
        expect(
          SwedishBankID.sameDevice().acrValue,
          'urn:grn:authn:se:bankid:same-device',
        );
        expect(
          SwedishBankID.otherDevice().acrValue,
          'urn:grn:authn:se:bankid:another-device:qr',
        );
        expect(
          SwedishBankID.selectorPage().acrValue,
          'urn:grn:authn:se:bankid',
        );
      },
    );

    test('sign is withMessage plus the sign action', () {
      final eid = SwedishBankID.sameDevice().sign('Sign here');

      expect(eid.loginHints, ['message:U2lnbiBoZXJl']);
      expect(eid.action, Action.sign);
    });

    test('a plain login carries no action', () {
      expect(SwedishBankID.sameDevice().withSsn().action, isNull);
    });
  });

  group('Vipps', () {
    test('takes no modifier', () {
      expect(Vipps().acrValue, 'urn:grn:authn:no:vipps');
    });

    test('every typed request is a plain scope', () {
      final eid = Vipps()
          .withEmail()
          .withPhone()
          .withAddress()
          .withBirthdate()
          .withSsn();

      expect(eid.scopes, ['email', 'phone', 'address', 'birthdate', 'ssn']);
      expect(eid.loginHints, isEmpty);
    });
  });

  group('Freja ID', () {
    test('the registration level travels as a hint, not an acr modifier', () {
      expect(FrejaID.basic().acrValue, 'urn:grn:authn:se:frejaid');
      expect(FrejaID.basic().loginHints, ['minregistrationlevel:basic']);
      expect(FrejaID.extended().loginHints, ['minregistrationlevel:extended']);
      expect(FrejaID.plus().loginHints, ['minregistrationlevel:plus']);
      expect(FrejaID.plus().acrValue, 'urn:grn:authn:se:frejaid');
    });

    test('basic exposes the contact scopes', () {
      final eid = FrejaID.basic()
          .withEmail()
          .withAllEmails()
          .withPhoneNumbers()
          .withRegistrationLevel();

      expect(eid.scopes, [
        'frejaid:email_address',
        'frejaid:all_email_addresses',
        'frejaid:all_phone_numbers',
        'frejaid:registration_level',
      ]);
    });

    test('extended adds the identity scopes', () {
      final eid = FrejaID.extended()
          .withBasicUserInfo()
          .withDateOfBirth()
          .withAge()
          .withSsn()
          .withAddresses()
          .withDocument()
          .withPhoto()
          .withDocumentPhoto();

      expect(eid.scopes, [
        'frejaid:basic_user_info',
        'frejaid:date_of_birth',
        'frejaid:age',
        'frejaid:ssn',
        'frejaid:addresses',
        'frejaid:document',
        'frejaid:photo',
        'frejaid:document_photo',
      ]);
    });

    test('withDefaultAndFaceConfirmation adds a hint', () {
      expect(FrejaID.plus().withDefaultAndFaceConfirmation().loginHints, [
        'minregistrationlevel:plus',
        'userconfirmationmethod:defaultandface',
      ]);
    });

    test('sign puts the title before the message', () {
      final eid = FrejaID.extended().sign(
        'Sign here',
        title: 'Terms of service',
      );

      expect(eid.action, Action.sign);
      expect(eid.loginHints, [
        'minregistrationlevel:extended',
        'title:VGVybXMgb2Ygc2VydmljZQ==',
        'message:U2lnbiBoZXJl',
      ]);
    });

    test('sign without a title omits the title hint', () {
      expect(FrejaID.basic().sign('Sign here').loginHints, [
        'minregistrationlevel:basic',
        'message:U2lnbiBoZXJl',
      ]);
    });
  });

  group('Mock', () {
    test('takes no modifier', () {
      expect(Mock().acrValue, 'urn:grn:authn:mock');
    });

    test('withMockData encodes the claims as base64 JSON', () {
      expect(Mock().withMockData({'sub': '1234', 'name': 'Alice'}).loginHints, [
        'mock:eyJzdWIiOiIxMjM0IiwibmFtZSI6IkFsaWNlIn0=',
      ]);
    });
  });

  group('age verification', () {
    test('the threshold is a scope and the country a hint', () {
      final eid = AgeVerification.over(
        AgeVerificationAge.over18,
      ).withCountry(AgeVerificationCountry.denmark);

      expect(eid.acrValue, 'urn:age-verification');
      expect(eid.scopes, ['is_over_18']);
      expect(eid.loginHints, ['country:DK']);
    });

    test('one login can ask more than one threshold', () {
      final eid = AgeVerification.over(
        AgeVerificationAge.over15,
      ).over(AgeVerificationAge.over21);

      expect(eid.scopes, ['is_over_15', 'is_over_21']);
    });

    test('every country maps to its ISO code', () {
      expect(AgeVerificationCountry.values.map((c) => c.wireValue), [
        'DK',
        'SE',
        'NO',
        'FI',
      ]);
    });
  });

  group('Other', () {
    test('takes the complete acr value, modifiers included', () {
      final eid = Other(
        'urn:grn:authn:foo:bar',
      ).withScope('something').withLoginHint('key:value');

      expect(eid.acrValue, 'urn:grn:authn:foo:bar');
      expect(eid.scopes, ['something']);
      expect(eid.loginHints, ['key:value']);
    });
  });

  group('immutability', () {
    // The regression test from EIDTest.swift: builders are values, so branching
    // off a half-built eID must not write back into the one it branched from.
    test('branches do not share state', () {
      final base = DanishMitID.substantial().withMessage('hello');
      final withUuid = base.prefillUuid('abc');

      expect(base.loginHints, ['message:aGVsbG8=']);
      expect(withUuid.loginHints, ['message:aGVsbG8=', 'uuid:abc']);
    });

    test('the exposed lists reject mutation', () {
      final eid = Vipps().withSsn();

      expect(() => eid.scopes.add('email'), throwsUnsupportedError);
      expect(() => eid.loginHints.add('key:value'), throwsUnsupportedError);
      expect(() => eid.acrValues.add('extra'), throwsUnsupportedError);
    });
  });
}
