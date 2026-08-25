package eu.idura.verify.flutter

import eu.idura.verify.eid.EID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import eu.idura.verify.Prompt as SdkPrompt

/**
 * Asserts against the real SDK types rather than a copy of their shape.
 *
 * `EID` exposes `acrValues`, `scopes`, `loginHints` and `action` as `private` or
 * `internal`, so reading them from this module takes reflection. That is the point
 * of doing it this way round: the alternative is asserting on what `toEid` was
 * handed, which would prove nothing about what the SDK ends up with. If a field is
 * renamed upstream these tests fail loudly instead of quietly passing.
 */
private fun EID<*>.field(name: String): Any? =
  EID::class.java.getDeclaredField(name).let {
    it.isAccessible = true
    it.get(this)
  }

private val EID<*>.acrValue: String
  get() =
    @Suppress("UNCHECKED_CAST")
    (field("acrValues") as List<String>).joinToString(":")

private val EID<*>.scopes: Set<String>
  get() =
    @Suppress("UNCHECKED_CAST")
    field("scopes") as Set<String>

private val EID<*>.loginHints: Set<String>
  get() =
    @Suppress("UNCHECKED_CAST")
    field("loginHints") as Set<String>

private fun request(
  acrValues: String = "urn:grn:authn:mock",
  scopes: List<String> = emptyList(),
  loginHints: List<String> = emptyList(),
) = NativeLoginRequest(acrValues = acrValues, scopes = scopes, loginHints = loginHints)

internal class EidMappingTest {
  @Test
  fun `passes the colon joined acr value through untouched`() {
    val eid = request(acrValues = "urn:grn:authn:dk:mitid:substantial").toEid()

    assertEquals("urn:grn:authn:dk:mitid:substantial", eid.acrValue)
  }

  @Test
  fun `carries every scope and hint across, in order`() {
    val eid =
      request(
        scopes = listOf("ssn", "address"),
        loginHints = listOf("sub:1234564444", "action:sign"),
      ).toEid()

    assertEquals(listOf("ssn", "address"), eid.scopes.toList())
    assertEquals(listOf("sub:1234564444", "action:sign"), eid.loginHints.toList())
  }

  @Test
  fun `keeps a hint whose value contains a space intact`() {
    // The reason the wire format is a list rather than the space-joined string
    // @criipto/verify-expo uses: a base64 message hint can contain anything.
    val eid = request(loginHints = listOf("message:U2lnbiBoZXJl", "title:QSB0aXRsZQ==")).toEid()

    assertEquals(listOf("message:U2lnbiBoZXJl", "title:QSB0aXRsZQ=="), eid.loginHints.toList())
  }

  @Test
  fun `leaves the action unset so the SDK cannot append a second action hint`() {
    // Dart already encoded it as a login hint. IduraVerify.login adds an
    // `action:` hint of its own for any eID that carries one, so a non-null
    // action here would send it twice.
    val eid = request(loginHints = listOf("action:sign")).toEid()

    assertNull(eid.field("action"))
  }

  @Test
  fun `maps every prompt onto the SDK's own`() {
    assertEquals(SdkPrompt.Login, Prompt.LOGIN.toSdk())
    assertEquals(SdkPrompt.None, Prompt.NONE.toSdk())
    assertEquals(SdkPrompt.Consent, Prompt.CONSENT.toSdk())
    assertEquals(SdkPrompt.ConsentRevoke, Prompt.CONSENT_REVOKE.toSdk())
  }

  @Test
  fun `has a prompt case for every one the SDK offers`() {
    // The `when` in toSdk is exhaustive, so a new *pigeon* prompt breaks the
    // build. Nothing catches a new *SDK* prompt, which would silently be
    // unreachable from Flutter. This does.
    assertEquals(
      SdkPrompt.entries.size,
      Prompt.entries.size,
      "eu.idura.verify.Prompt has cases the pigeon schema does not. Add them to " +
        "pigeons/messages.dart, regenerate, and extend Prompt.toSdk.",
    )
  }
}
