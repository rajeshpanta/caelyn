# Caelyn 1.3 — App Review notes and App Privacy changes

Paste-ready text for App Store Connect. Nothing here has been applied — the API key
`UJ7WBMA5H5` has upload rights only and returns 403 on metadata.

## App Review notes (paste into "Notes" for the 1.3 submission)

> Caelyn 1.3 adds an optional account and optional private iCloud sync.
>
> **The account is optional and gates nothing.** Sign in with Apple is offered only
> in Settings → Account & iCloud. There is no sign-in wall, nothing in onboarding,
> and every feature — including all cycle history — works fully signed out. Reviewers
> do not need to sign in to exercise the app.
>
> **Sign in with Apple is used for identity and personalization only.** Caelyn
> requests the name scope and nothing else; it does not request email. The only
> credential retained is Apple's anonymous per-app user identifier, stored in the
> device Keychain. Apple's name is treated as a suggestion: the app immediately asks
> "What should Caelyn call you?" with that name prefilled, and the value the user
> confirms is what is used.
>
> **No Sign in with Apple tokens are held, so there are none to revoke.** Caelyn
> never reads `identityToken` or `authorizationCode`, so no refresh or access token
> is ever issued to it and there is no user session with Apple to invalidate. The
> app operates no server, so it cannot hold the private key a client secret would
> require. Delete Caelyn account removes every trace the app holds, and the screen
> tells the user where to remove Caelyn from their Apple Account, which is the only
> revocation that exists for an app in this position.
>
> **Cycle history is deliberately not deleted by account deletion.** Deleting an
> account removes the account from the developer's records; Caelyn has no developer
> records, no server, and no copy of anything. The user's history lives on their
> device and, if they enable sync, in their own private CloudKit database that we
> cannot read. It is not associated with the account either — it exists identically
> for someone who never signs in. Destroying years of reproductive-health history
> because an Apple ID was unlinked would be a harm, not compliance.
>
> **Deletion is reachable in-app, three ways, each clearly scoped:**
> - Settings → Account & iCloud → Delete Caelyn account (identity only; says plainly
>   what it does not delete)
> - Settings → Account & iCloud → Delete my iCloud copy (cloud copy only; device
>   untouched). Remains available after sync is switched off, because switching sync
>   off does not remove a copy already made.
> - Settings → Privacy → Delete all data (asks: this iPhone, or this iPhone and iCloud)
>
> **Subscriptions.** Caelyn Pro is an auto-renewable subscription billed by Apple.
> The account-deletion confirmation states that deleting the account does not cancel
> it, and offers `AppStore.showManageSubscriptions` before continuing. Deletion is
> never blocked on cancelling.
>
> **iCloud sync uses the user's own private CloudKit database.** It is off by
> default, opt-in, and no record of any kind is written to a public database.

## App Privacy — no changes required

**Verdict: leave the declaration as "Data Not Collected."**

Apple's definition is the whole test:

> "Collect" refers to transmitting data off the device in a way that allows you
> and/or your third-party partners to access it for a period longer than what is
> necessary to service the transmitted request in real time.

The question is not "does data leave the phone" — it is "does it leave in a way the
developer can read." Caelyn fails that test on every count, and the source is the
evidence: no `URLSession`, no `URLRequest`, no networking of any kind, and zero
third-party packages. There is no endpoint for data to arrive at.

| Data type | Declare? | Why |
|---|---|---|
| Identifiers → User ID | **No** | Apple's identifier is written to the local Keychain and never transmitted. |
| Contact Info → Name | **No** | Typed by the user; stored on device and in her own iCloud. Developer cannot read it. |
| Contact Info → Email | **No** | Never requested. 1.3 asks for `[.fullName]` only. |
| Health & Fitness | **No** | Same reasoning as Name: the private CloudKit database is Apple storage under the user's own account. |

**Why over-declaring would be the worse error.** Declaring health data as collected
and linked to identity would print "Health data linked to you" on the product page of
a privacy-first period tracker — a statement that is both untrue and directly
damaging. An inaccurate label is a problem in *both* directions, and the accurate
answer here is the one already published.

## Account deletion questionnaire

Answer that account deletion is offered in-app, and describe all three routes above,
stating explicitly that deleting the account does not delete health data — that being
a deliberate safety property rather than an omission.
