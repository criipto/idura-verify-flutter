import 'package:flutter/material.dart';
import 'package:idura_verify/idura_verify.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idura Verify',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const LoginScreen(),
    );
  }
}

/// One button per eID. Mock leads because it is the only flow that needs no
/// authenticator app, so it is what to reach for when checking a fresh setup.
/// It carries mock data so a login shows an identity the caller chose, which
/// is also what the end-to-end test asserts came back.
///
/// Every builder here takes the plainest form of its eID. The `withX()` methods
/// requesting extra claims are left off deliberately: a scope the Idura domain
/// has not been granted fails the login, so an example that requested them would
/// break on any tenant but ours.
List<({String label, Eid Function() build})> _eids() => [
  (label: 'Mock', build: () => Mock().withMockData({'name': 'foobar'})),
  (label: 'Danish MitID', build: DanishMitID.substantial),
  (label: 'Swedish BankID', build: SwedishBankID.sameDevice),
  (label: 'Norwegian BankID', build: NorwegianBankID.substantial),
  (label: 'Vipps', build: Vipps.new),
  (label: 'Freja ID', build: FrejaID.basic),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// The last completed login, if there was one.
  LoginResult? _result;

  /// The last failure, excluding cancellation — a user backing out is a normal
  /// action and this screen shows nothing for it.
  IduraVerifyException? _error;

  /// Disables the buttons for the duration of a login. Without it Android
  /// answers the second overlapping call with [LoginAlreadyInProgressException],
  /// which is correct but is not what a user should have to see.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Optional, and deliberately not awaited: it builds the native SDK — OIDC
    // discovery, the JWKS fetch, and on Android the scan for a usable browser —
    // while the user is still reading this screen, so the first login does not
    // pay for it. It reports nothing, because a real misconfiguration comes back
    // out of login() naming the fix either way.
    warmUp();
  }

  Future<void> _login(Eid eid) async {
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });

    try {
      final result = await login(eid);
      if (mounted) setState(() => _result = result);
    } on UserCancelledException {
      // Nothing to show. Covers both dismissing the browser and cancelling
      // inside the eID app, which is the point of collapsing `access_denied`
      // into this one type.
    } on IduraVerifyException catch (e) {
      // Everything else, including setup mistakes. Nothing outside this
      // hierarchy can escape login(), so there is no second catch to write.
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Idura Verify')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final eid in _eids())
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  onPressed: _busy ? null : () => _login(eid.build()),
                  child: Text(eid.label),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_result case final result?) _Result(result),
            if (_error case final error?) _Failure(error),
          ],
        ),
      ),
    );
  }
}

/// A completed login. Shows the claims rather than the token: the ID token is a
/// credential, and the thing worth seeing is what the eID actually returned.
class _Result extends StatelessWidget {
  const _Result(this.result);

  final LoginResult result;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Logged in',
      colour: Theme.of(context).colorScheme.primary,
      child: SelectableText(
        [
          'identityscheme: ${result.claims.identityScheme}',
          'sub: ${result.claims.subject}',
          'traceId: ${result.traceId}',
          '',
          // Whatever the eID returned beyond the claims the SDK requires, which
          // is where a requested scope shows up.
          ...result.claims.raw.entries.map((e) => '${e.key}: ${e.value}'),
        ].join('\n'),
      ),
    );
  }
}

/// A failure, shown the way a developer wants to see one rather than the way a
/// user should: the message is aimed at whoever wired the integration up.
class _Failure extends StatelessWidget {
  const _Failure(this.error);

  final IduraVerifyException error;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: error.runtimeType.toString(),
      colour: Theme.of(context).colorScheme.error,
      child: SelectableText(
        [
          error.message,
          // The one field worth branching on, because it says which setup
          // mistake this is without parsing the message.
          if (error case NotConfiguredException(:final code)) '\ncode: $code',
          if (error.traceId case final traceId?) '\ntraceId: $traceId',
        ].join(),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.colour, required this.child});

  final String title;
  final Color colour;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: colour),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
