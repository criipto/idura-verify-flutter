package eu.idura.verify.flutter

import eu.idura.verify.IduraVerifyInternalException
import eu.idura.verify.LoginAlreadyInProgressException
import eu.idura.verify.NoSuitableBrowserException
import eu.idura.verify.OAuthException
import eu.idura.verify.UserCancelledException

/**
 * Turns anything the SDK can throw into a result variant.
 *
 * Failures ride the success path as data rather than crossing as a channel error,
 * which is what keeps `traceId` attached to every outcome including cancellation.
 *
 * `DuplicateInstanceException` is deliberately absent. It is an
 * `IllegalStateException` rather than an `IduraVerifyException`, because it reports a
 * caller mistake rather than a failed login, and [constructSdk] turns it into the
 * setup diagnostic it deserves before it could reach here.
 */
internal fun Throwable.toNativeLoginResult(): NativeLoginResult =
  when (this) {
    is NotConfiguredSignal -> {
      NativeNotConfigured(code = code, message = message!!)
    }

    is UserCancelledException -> {
      NativeUserCancelled(traceId = traceId)
    }

    is NoSuitableBrowserException -> {
      NativeNoSuitableBrowser(traceId = traceId)
    }

    is LoginAlreadyInProgressException -> {
      NativeFlowAlreadyInProgress(traceId = traceId)
    }

    is OAuthException -> {
      NativeOAuthError(
        error = error,
        errorDescription = errorDescription,
        traceId = traceId,
      )
    }

    is IduraVerifyInternalException -> {
      NativeInternalError(
        message = message ?: "Idura Verify failed",
        traceId = traceId,
      )
    }

    // A catch-all for anything the SDK leaks untyped, which is a leak worth
    // reporting: naming the class is for a support ticket rather than for a user.
    else -> {
      NativeInternalError(
        message = message?.let { "${this::class.java.name}: $it" } ?: this::class.java.name,
      )
    }
  }
