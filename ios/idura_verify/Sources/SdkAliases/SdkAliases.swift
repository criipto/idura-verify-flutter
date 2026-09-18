import IduraVerify

/// Names the SDK's `Prompt`, which the bridge target cannot spell.
///
/// Two things collide there. The SDK's module and its main class are both called
/// `IduraVerify`, so `IduraVerify.Prompt` resolves to the *class* and fails with
/// "'Prompt' is not a member type of class 'IduraVerify.IduraVerify'" — module
/// qualification is unavailable for every top-level type in that module. And the
/// generated `Prompt` from `pigeons/messages.dart` shadows the imported one, so the
/// unqualified spelling is taken. Between them the SDK's enum has no spelling at all.
///
/// This module has no `Prompt` of its own, so here the unqualified name resolves to
/// the SDK's and can be re-exported under one that does not collide. `moduleAliases`
/// on the product dependency is the tidier fix and does work under `swift build`, but
/// Xcode's build system rejects it ("failed to find blueprint corresponding to PIF
/// GUID: PACKAGE-TARGET:IduraVerify"), and every Flutter iOS build goes through Xcode.
///
/// Add to this file only for the same reason: a name the bridge target cannot reach.
/// It is not a place for wrappers.
public typealias SdkPrompt = Prompt
