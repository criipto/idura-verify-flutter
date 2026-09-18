package eu.idura.verify.flutter

import android.content.Intent
import android.util.Log
import eu.idura.verify.IduraVerify
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel

private const val TAG = "IduraVerifyFlutter"

/** Binds the Flutter `idura_verify` package to `eu.idura:verify`. */
class IduraVerifyPlugin :
  FlutterPlugin,
  ActivityAware,
  PluginRegistry.ActivityResultListener,
  IduraVerifyHostApi {
  /**
   * An attached activity, the scope its logins run on and the SDK instance built for
   * it, as one object because they share one lifetime.
   */
  private class Attachment(
    val binding: ActivityPluginBinding,
  ) {
    /**
     * Bounds every login to this plugin's attachment, not to the host activity. Pigeon
     * launches each call on an unstructured `CoroutineScope(Dispatchers.Main)` bound to
     * no lifecycle, so without this a login whose result can no longer arrive would wait
     * forever.
     *
     * `MainScope()` rather than the host's `lifecycleScope`. It is simply the wrong
     * lifetime. `lifecycleScope` ends when the activity is destroyed, whereas what
     * decides whether a pending login can still be answered is whether this plugin is
     * still attached: on a plain `Activity` host the browser result reaches the SDK only
     * through the [onActivityResult] listener registered in [onAttachedToActivity] and
     * removed in [onDetachedFromActivity]. Those two moments differ —
     * `FlutterFragment.onDetach` detaches the engine from an activity that goes on
     * living — and there an activity-scoped job would keep waiting on a result nothing
     * is left to deliver.
     */
    val scope: CoroutineScope = MainScope()

    /** Null until the first [requireSdk], which is the only thing that assigns it. */
    var sdk: IduraVerify? = null
      private set

    /**
     * The SDK instance for this attachment's activity, building it if needed.
     *
     * Nothing checks that the activity still matches, because it cannot differ: the
     * embedding detaches before every attach — `attachToActivity` calls
     * `detachFromAppComponent()` first — so an instance never outlives the
     * attachment that built it.
     */
    fun requireSdk(): IduraVerify = sdk ?: constructSdk(binding.activity).also { sdk = it }
  }

  private var attachment: Attachment? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    IduraVerifyHostApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    IduraVerifyHostApi.setUp(binding.binaryMessenger, null)
  }

  /**
   * Notably does not construct the SDK. Attach happens at every engine-to-activity
   * handover, which for most apps means app start, and constructing there would
   * spend two requests plus a browser scan on the main thread whether or not the
   * app ever shows a login button. [warmUp] is how an app asks for that work, and
   * [login] does it if nobody asked.
   */
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    attachment = Attachment(binding)
    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivity() {
    attachment?.let {
      // Cancelling completes any in-flight login's Dart future with a typed error.
      // It cannot be resumed: the SDK's continuation is tied to the activity's result
      // registry, so once the activity is gone nothing would ever resume it.
      it.scope.cancel()
      it.binding.removeActivityResultListener(this)
    }
    // Which also discards the SDK instance, since the attachment owns it.
    attachment = null
  }

  // A configuration change recreates the activity, which invalidates the SDK
  // instance exactly as a real detach does, so both go down the same path.
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
    onAttachedToActivity(binding)

  override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

  /**
   * Hands the browser result to the SDK, for the hosts that cannot receive it
   * themselves.
   *
   * `FlutterActivity` is a plain `Activity`, so it has no `ActivityResultRegistry` and
   * the SDK launches the browser through `startActivityForResult` instead — this is
   * the only way the answer gets back. `FlutterFragmentActivity` does have one and the
   * SDK uses it, in which case `handleActivityResult` returns false and the result
   * carries on down the listener chain untouched. Forwarding unconditionally is
   * documented as safe for exactly that reason, which matters because a plugin cannot
   * know which host it was given.
   */
  override fun onActivityResult(
    requestCode: Int,
    resultCode: Int,
    data: Intent?,
  ): Boolean = attachment?.sdk?.handleActivityResult(requestCode, resultCode, data) ?: false

  override suspend fun warmUp() {
    // No activity is not an error here. A warm-up is a hint, and the only thing a
    // caller could do with the news is call login() anyway, which reports it properly.
    val attachment = this.attachment ?: return

    try {
      attachment.requireSdk()
    } catch (e: Exception) {
      // Logged rather than returned, because there is no variant to return it in.
      // A misconfigured app still fails at login() with the same message; this is
      // only so the reason is visible while an integration is being wired up.
      Log.w(TAG, "warmUp() could not build the Idura Verify SDK", e)
    }
  }

  override suspend fun login(request: NativeLoginRequest): NativeLoginResult {
    val attachment =
      this.attachment ?: return NativeNotConfigured(
        code = NotConfiguredCode.NO_ACTIVITY,
        message =
          "Idura Verify has no activity to present the login flow from. Call login() while " +
            "your Flutter UI is attached to an activity.",
      )

    // Setup diagnostics are settled before a scope is involved at all, because
    // [Attachment.requireSdk] does not suspend. That leaves [Attachment.scope]
    // standing for one thing only, a login that is actually in flight, so the
    // cancellation below can mean only what its message says.
    val sdk =
      try {
        attachment.requireSdk()
      } catch (e: Exception) {
        return e.toNativeLoginResult()
      }

    return try {
      attachment.scope.async { runLogin(sdk, request) }.await()
    } catch (e: CancellationException) {
      // Only reachable via onDetachedFromActivity. We are running on pigeon's own
      // scope, which is not cancelled, so returning a value here is legal and the
      // reply still goes out.
      NativeInternalError(
        message =
          "The login flow lost the activity presenting it before it completed. " +
            "The login has to be started again.",
      )
    }
  }

  private suspend fun runLogin(
    sdk: IduraVerify,
    request: NativeLoginRequest,
  ): NativeLoginResult =
    try {
      val result = sdk.login(request.toEid(), request.prompt?.toSdk())
      NativeLoginSuccess(idToken = result.jwt.token, traceId = result.traceId)
    } catch (e: CancellationException) {
      // Ours, from onDetachedFromActivity. Let `login` answer it, above.
      throw e
    } catch (e: Exception) {
      e.toNativeLoginResult()
    }
}
