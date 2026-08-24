// `Prompt` deliberately lives in pigeons/messages.dart instead of here: it
// crosses the bridge, so generating it is what keeps the Dart, Kotlin and Swift
// spellings from drifting. `Action` never crosses — it is encoded into a login
// hint on this side — so it stays hand written.

/// The verb the eID app shows the user, for flows that are not a plain login.
///
/// Only some eIDs support it; the builders that do expose a `withAction`.
enum Action {
  /// Log in. The default for every eID.
  login('login'),

  /// Confirm something the app has already shown the user.
  confirm('confirm'),

  /// Accept, e.g. terms.
  accept('accept'),

  /// Approve, e.g. a payment.
  approve('approve'),

  /// Sign a document.
  sign('sign');

  const Action(this.wireValue);

  /// The value sent as the `action:` login hint.
  final String wireValue;
}
