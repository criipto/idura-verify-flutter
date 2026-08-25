package eu.idura.verify.flutter

import android.app.Activity
import android.content.pm.PackageManager
import androidx.lifecycle.LifecycleOwner
import eu.idura.verify.DuplicateInstanceException
import eu.idura.verify.IduraVerify

/**
 * `<meta-data>` keys carrying the configuration at runtime.
 *
 * A consuming app never writes these. Our own `AndroidManifest.xml` declares them
 * as `${iduraDomain}` and `${iduraClientId}`, which AGP leaves unresolved in the
 * AAR for the app's `manifestPlaceholders` to substitute — the same two values the
 * SDK's redirect activity already needs for its `android:host`. So the app
 * configures each one exactly once, in Gradle, and this is only how it reaches us
 * at runtime.
 *
 * Configuration is read natively rather than passed from Dart for the same reason:
 * the domain has to be in Gradle regardless, so taking it from Dart as well would
 * mean declaring one value in two places.
 */
internal const val META_DOMAIN = "eu.idura.verify.domain"
internal const val META_CLIENT_ID = "eu.idura.verify.clientId"

/** Where a consumer sets the value behind [META_DOMAIN]. */
private const val PLACEHOLDER_DOMAIN = "iduraDomain"

/** Where a consumer sets the value behind [META_CLIENT_ID]. */
private const val PLACEHOLDER_CLIENT_ID = "iduraClientId"

private fun gradleFix(
  placeholder: String,
  example: String,
) = "Set manifestPlaceholders[\"$placeholder\"] = \"$example\" in the defaultConfig block of " +
  "android/app/build.gradle.kts."

/**
 * A setup mistake in the host app, carrying the code and message Dart turns into
 * a `NotConfiguredException`.
 *
 * A throwable rather than a return type so the checks below can read as a
 * straight line, and so the SDK's own construction-time `IllegalArgumentException`
 * and `DuplicateInstanceException` join the same channel.
 */
internal class NotConfiguredSignal(
  val code: NotConfiguredCode,
  message: String,
) : Exception(message)

internal data class Configuration(
  val domain: String,
  val clientId: String,
)

/**
 * Reads the two values. [metaData] is a lookup rather than a `Bundle` so this stays
 * a pure function.
 *
 * Presence is all we check. The SDK validates the domain's shape itself as the first
 * statement of its constructor (`requireBareHost`, since 2.0.6) and does it more
 * strictly than we would, including the lower-case rule that matters because the
 * domain is compared verbatim against the ID token's `iss`. [constructSdk] turns that
 * `IllegalArgumentException` into [NotConfiguredCode.INVALID_DOMAIN], so the SDK's
 * message reaches Dart unaltered.
 *
 * An *absent* placeholder fails the build, since AGP refuses to merge a manifest
 * with an unsubstituted one. An *empty* one does not: AGP substitutes `""` without
 * complaint, which is what a `providers.environmentVariable(…).getOrElse("")` gives
 * you in a CI job missing the variable, so the blank checks below are the real
 * reason these branches exist. A host manifest suppressing our `<meta-data>` with
 * `tools:node="remove"` gets here too. Either way the message names the Gradle line,
 * because that is where the fix goes.
 */
internal fun readConfiguration(metaData: (String) -> String?): Configuration {
  val domain =
    metaData(META_DOMAIN)?.takeIf { it.isNotBlank() }
      ?: throw NotConfiguredSignal(
        NotConfiguredCode.MISSING_DOMAIN,
        "Idura Verify is missing its domain. " +
          gradleFix(PLACEHOLDER_DOMAIN, "your-domain.criipto.id"),
      )

  val clientId =
    metaData(META_CLIENT_ID)?.takeIf { it.isNotBlank() }
      ?: throw NotConfiguredSignal(
        NotConfiguredCode.MISSING_CLIENT_ID,
        "Idura Verify is missing its client id. " +
          gradleFix(PLACEHOLDER_CLIENT_ID, "urn:my:application:identifier:123"),
      )

  return Configuration(domain = domain, clientId = clientId)
}

/**
 * Builds an SDK instance for [activity], or throws [NotConfiguredSignal] naming
 * the fix.
 *
 * Not lazy and not cached here: the caller owns the instance's lifetime, because
 * the SDK ties itself to one activity and releases its result-registry callbacks
 * in that activity's `onDestroy`.
 */
internal fun constructSdk(activity: Activity): IduraVerify {
  // Checked here rather than left to the SDK, which rejects it with an
  // IllegalArgumentException — the same type its domain validation uses, and the branch
  // below reads that as an invalid domain. Keeping the two apart is what stops a
  // hand-rolled host from being reported as a configuration typo.
  //
  // Not reachable from either Flutter activity base class: FlutterActivity drives its own
  // LifecycleRegistry and FlutterFragmentActivity inherits one. It takes a host activity
  // written from scratch, which is why the message asks for the interface rather than
  // naming a superclass to extend.
  if (activity !is LifecycleOwner) {
    throw NotConfiguredSignal(
      NotConfiguredCode.HOST_ACTIVITY_NOT_LIFECYCLE_OWNER,
      "${activity::class.java.name} has to implement androidx.lifecycle.LifecycleOwner for " +
        "Idura Verify to follow its lifecycle. Host your Flutter UI in FlutterActivity or " +
        "FlutterFragmentActivity, or drive a LifecycleRegistry from your own activity callbacks.",
    )
  }

  val applicationInfo =
    activity.packageManager.getApplicationInfo(
      activity.packageName,
      PackageManager.GET_META_DATA,
    )
  val configuration = readConfiguration { applicationInfo.metaData?.getString(it) }

  return try {
    // The Activity overload, not the ComponentActivity one. It picks the machinery for the
    // browser result off the activity in hand: FlutterFragmentActivity brings its own result
    // registry and gets it used, while FlutterActivity has none and is launched through
    // startActivityForResult, which is what the plugin's onActivityResult forwarding serves.
    IduraVerify(
      clientID = configuration.clientId,
      domain = configuration.domain,
      activity = activity,
    )
  } catch (e: DuplicateInstanceException) {
    // The SDK's per-activity claim on "eu.idura.verify.authTab:$domain:$clientID". Since our
    // configuration comes from the manifest, every instance in the app is configured
    // identically, so the only way to collide is two Flutter engines sharing one activity.
    //
    // The SDK's own message leads, as in the branch below: it names the clientID and domain
    // that collided, which we would only be guessing at.
    throw NotConfiguredSignal(
      NotConfiguredCode.DUPLICATE_INSTANCE,
      (e.message ?: "Another Idura Verify instance is already active on this activity.") +
        " In Flutter this happens when two engines share an activity, for example two " +
        "FlutterFragments or an engine group in an add-to-app host. Give each engine its own " +
        "activity.",
    )
  } catch (e: IllegalArgumentException) {
    // The SDK's own `requireBareHost`, which is stricter than anything we would
    // write here and owns the rules. Pass its message through verbatim and only add
    // the one thing it cannot know: which Gradle line the value came from.
    throw NotConfiguredSignal(
      NotConfiguredCode.INVALID_DOMAIN,
      (e.message ?: "\"${configuration.domain}\" is not a valid Idura Verify domain.") +
        " " + gradleFix(PLACEHOLDER_DOMAIN, "your-domain.criipto.id"),
    )
  }
}
