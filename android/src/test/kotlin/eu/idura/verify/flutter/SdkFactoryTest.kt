package eu.idura.verify.flutter

import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

private val valid =
  mapOf(
    META_DOMAIN to "samples.criipto.id",
    META_CLIENT_ID to "urn:my:application:identifier:123",
  )

private fun read(metaData: Map<String, String?>) = readConfiguration { metaData[it] }

internal class SdkFactoryTest {
  @Test
  fun `reads both values from the manifest`() {
    assertEquals(
      Configuration(
        domain = "samples.criipto.id",
        clientId = "urn:my:application:identifier:123",
      ),
      read(valid),
    )
  }

  @Test
  fun `names the Gradle placeholder when the domain is missing`() {
    // Not the <meta-data> element: the app never writes that, it only sets the
    // placeholder our own manifest declares. Pointing at the manifest would send
    // someone to a file they are not supposed to edit.
    val e = assertFailsWith<NotConfiguredSignal> { read(valid - META_DOMAIN) }

    assertEquals(NotConfiguredCode.MISSING_DOMAIN, e.code)
    assertContains(e.message!!, "manifestPlaceholders[\"iduraDomain\"]")
    assertContains(e.message!!, "android/app/build.gradle.kts")
  }

  @Test
  fun `names the Gradle placeholder when the client id is missing`() {
    val e = assertFailsWith<NotConfiguredSignal> { read(valid - META_CLIENT_ID) }

    assertEquals(NotConfiguredCode.MISSING_CLIENT_ID, e.code)
    assertContains(e.message!!, "manifestPlaceholders[\"iduraClientId\"]")
    assertContains(e.message!!, "android/app/build.gradle.kts")
  }

  @Test
  fun `treats a blank value as missing`() {
    // The branch that actually fires in the field. An absent placeholder fails the
    // build, but an empty one merges without complaint — verified by building the
    // example with manifestPlaceholders["iduraDomain"] = "" — and the SDK would
    // happily build "https:///android/callback" out of it.
    assertEquals(
      NotConfiguredCode.MISSING_DOMAIN,
      assertFailsWith<NotConfiguredSignal> { read(valid + (META_DOMAIN to "  ")) }.code,
    )
    assertEquals(
      NotConfiguredCode.MISSING_CLIENT_ID,
      assertFailsWith<NotConfiguredSignal> { read(valid + (META_CLIENT_ID to "")) }.code,
    )
  }

  @Test
  fun `passes a malformed domain through to the SDK rather than judging it`() {
    // Domain shape is the SDK's rule, enforced by requireBareHost as the first
    // statement of its constructor since 2.0.6 and stricter than anything here —
    // it also rejects upper case, which matters because the domain is compared
    // verbatim against the ID token's `iss`. Duplicating it would mean the laxer
    // copy answering first with a worse message.
    for (domain in listOf(
      "https://samples.criipto.id",
      "samples.criipto.id/",
      "samples.criipto.id:443",
      "Samples.Criipto.ID",
      "localhost",
    )) {
      assertEquals(domain, read(valid + (META_DOMAIN to domain)).domain, domain)
    }
  }

  @Test
  fun `accepts a client id containing a colon`() {
    // Only the domain is host-shaped. Idura client ids are commonly URNs.
    assertEquals(
      "urn:my:application:identifier:123",
      read(valid).clientId,
    )
  }

  // constructSdk's remaining branches need a real Activity, PackageManager or SDK
  // instance, so they are device-covered: HOST_ACTIVITY_NOT_LIFECYCLE_OWNER by hosting
  // the engine in an activity written from scratch, INVALID_DOMAIN and
  // DUPLICATE_INSTANCE by the throws they translate. The device equivalent of the
  // missing-value branches is an *empty* placeholder, not a dropped one, which fails
  // the build.
}
