package eu.idura.verify.flutter

import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

internal class IduraVerifyPluginTest {
  @Test
  fun `a login with no activity attached is a setup error, not a hang`() {
    // The add-to-app case: Dart can outlive the activity, and pigeon's per-call
    // scope is bound to no lifecycle, so a caller would otherwise wait forever.
    val result =
      runBlocking {
        IduraVerifyPlugin().login(
          NativeLoginRequest(
            acrValues = "urn:grn:authn:mock",
            scopes = emptyList(),
            loginHints = emptyList(),
          ),
        )
      }

    assertIs<NativeNotConfigured>(result)
    assertEquals(NotConfiguredCode.NO_ACTIVITY, result.code)
  }

  @Test
  fun `a warm-up with no activity attached is not an error`() {
    // Nothing to assert but the absence of a throw: warmUp reports nothing by
    // design, and a caller that raced the activity must not see a failure for it.
    runBlocking { IduraVerifyPlugin().warmUp() }
  }

  // The rest of the plugin is lifecycle wiring over Activity, ActivityPluginBinding
  // and Dispatchers.Main, none of which exist in a JVM unit test. It is covered by
  // running the example: the detach-mid-flow path in particular needs a cached
  // engine outliving its activity, which no unit test can stage.
}
