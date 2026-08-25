package eu.idura.verify.flutter

import eu.idura.verify.IduraVerifyException
import eu.idura.verify.IduraVerifyInternalException
import eu.idura.verify.LoginAlreadyInProgressException
import eu.idura.verify.NoSuitableBrowserException
import eu.idura.verify.OAuthException
import eu.idura.verify.UserCancelledException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * `IduraVerifyException.traceId` has an `internal` setter, so this module cannot
 * assign it the way the SDK does. Reflection keeps the tests running against real
 * SDK exceptions rather than stand-ins that could disagree with them.
 */
private fun <T : IduraVerifyException> T.tracedAs(traceId: String): T =
  apply {
    IduraVerifyException::class.java.getDeclaredField("traceId").let {
      it.isAccessible = true
      it.set(this, traceId)
    }
  }

/**
 * Same reason, one step further: the SDK reserves construction of this one to itself,
 * so only reflection reaches it. Worth the reach rather than a stand-in, because the
 * mapping's whole premise is that this class sits inside the [IduraVerifyException]
 * hierarchy — a supertype change upstream has to fail here.
 */
private fun loginAlreadyInProgress(): LoginAlreadyInProgressException =
  LoginAlreadyInProgressException::class.java.declaredConstructors.first().let {
    it.isAccessible = true
    it.newInstance(*arrayOfNulls<Any?>(it.parameterCount)) as LoginAlreadyInProgressException
  }

internal class ErrorMappingTest {
  @Test
  fun `cancellation keeps its trace id`() {
    val result = UserCancelledException().tracedAs("trace-1").toNativeLoginResult()

    assertEquals(NativeUserCancelled(traceId = "trace-1"), result)
  }

  @Test
  fun `a failure with no span reported has no trace id`() {
    // Construction-time checks fail before a span exists, so null has to survive
    // rather than becoming an empty string.
    assertEquals(
      NativeUserCancelled(traceId = null),
      UserCancelledException().toNativeLoginResult(),
    )
  }

  @Test
  fun `no suitable browser`() {
    val result = NoSuitableBrowserException().tracedAs("trace-2").toNativeLoginResult()

    assertEquals(NativeNoSuitableBrowser(traceId = "trace-2"), result)
  }

  @Test
  fun `a rejected concurrent login keeps the rejected call's trace id`() {
    // The SDK attaches its own span before turning the call away, so this trace id
    // belongs to the rejected login rather than the one still running.
    val result = loginAlreadyInProgress().tracedAs("trace-concurrent").toNativeLoginResult()

    assertEquals(NativeFlowAlreadyInProgress(traceId = "trace-concurrent"), result)
  }

  @Test
  fun `an OAuth error keeps its code and description`() {
    val result =
      OAuthException("temporarily_unavailable", "Try again later")
        .tracedAs("trace-3")
        .toNativeLoginResult()

    assertEquals(
      NativeOAuthError(
        error = "temporarily_unavailable",
        errorDescription = "Try again later",
        traceId = "trace-3",
      ),
      result,
    )
  }

  @Test
  fun `an internal failure keeps its message`() {
    val result =
      IduraVerifyInternalException("State mismatch in OIDC response")
        .tracedAs("trace-4")
        .toNativeLoginResult()

    assertEquals(
      NativeInternalError(message = "State mismatch in OIDC response", traceId = "trace-4"),
      result,
    )
  }

  @Test
  fun `a setup mistake carries its code and message`() {
    val result =
      NotConfiguredSignal(
        NotConfiguredCode.HOST_ACTIVITY_NOT_LIFECYCLE_OWNER,
        "MainActivity has to implement LifecycleOwner.",
      ).toNativeLoginResult()

    assertEquals(
      NativeNotConfigured(
        code = NotConfiguredCode.HOST_ACTIVITY_NOT_LIFECYCLE_OWNER,
        message = "MainActivity has to implement LifecycleOwner.",
      ),
      result,
    )
  }

  @Test
  fun `an exception from outside the SDK hierarchy names its type`() {
    // What a failed OIDC discovery arrives as: AppAuth's raw AuthorizationException,
    // which IduraVerify.login's `catch (ex: IduraVerifyException)` does not see.
    val result = IllegalArgumentException("no protocol").toNativeLoginResult()

    assertEquals(
      NativeInternalError(message = "java.lang.IllegalArgumentException: no protocol"),
      result,
    )
    assertNull((result as NativeInternalError).traceId)
  }

  @Test
  fun `an exception with no message still names its type`() {
    assertEquals(
      NativeInternalError(message = "java.lang.NullPointerException"),
      NullPointerException().toNativeLoginResult(),
    )
  }
}
