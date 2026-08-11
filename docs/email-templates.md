# Email templates

Firebase Auth sends these itself. They are **not** in this repository's control —
they live in the Firebase console under **Authentication → Templates**, and the
text below has to be pasted in by hand. That is a deliberate limitation of the
platform, not an oversight: the sending is done by Google's infrastructure using
its own template store.

Set the **sender name** to `EchoMeet` and the **reply-to** to a real address
before changing anything else. The default is a no-reply on a
`firebaseapp.com` domain, which is the single biggest reason password-reset mail
lands in spam.

## What the placeholders mean

| Placeholder | Filled in with |
| --- | --- |
| `%LINK%` | The one-time action link. Required — the mail is useless without it. |
| `%EMAIL%` | The recipient's address. |
| `%NEW_EMAIL%` | The new sign-in address in the old-address security notice. |
| `%DISPLAY_NAME%` | Their name, if the account has one. |
| `%APP_NAME%` | The project's public-facing name. |

## Password reset

**Subject**

```
Reset your EchoMeet password
```

**Body**

```
Hello %DISPLAY_NAME%,

Someone asked to reset the password for the EchoMeet account registered to
%EMAIL%. If that was you, choose a new password here:

%LINK%

This link works once and expires in an hour.

If it wasn't you, you can ignore this message — your password has not been
changed and nobody has been given access to your account. If you keep receiving
these, change your password to be safe.

— EchoMeet
```

The last paragraph is doing real work and should not be trimmed. A reset mail
that only says "click here" gives somebody who did *not* request it no way to
tell whether they need to act, so the safe reading is always "I have been
hacked". Saying plainly that nothing has happened yet is the difference between
a routine mail and an alarming one.

## Email address verification

This template is sent to the **new** address by the app's
`verifyBeforeUpdateEmail` flow. Following its link verifies the new address and
makes it the account's primary sign-in address. It is separate from the
old-address revoke notice in the next section.

**Subject**

```
Confirm your email for EchoMeet
```

**Body**

```
Hello %DISPLAY_NAME%,

Confirm that %EMAIL% is your address so your colleagues can find you and you can
receive notifications about surveys and meetings:

%LINK%

If you did not create an EchoMeet account or request this address change, ignore
this message — no change occurs without the link.

— EchoMeet
```

## Email address change

**Subject**

```
Your EchoMeet sign-in address was changed
```

**Body**

```
Hello %DISPLAY_NAME%,

The address used to sign in to your EchoMeet account was changed to
%NEW_EMAIL%.

If you made this change, no action is needed.

If you did not make this change, use this security link immediately to restore
your previous sign-in address:

%LINK%

After restoring the address, change your password because somebody may have
access to your account.

— EchoMeet
```

This one is sent to the **old** address. It is a security/revert notice, not a
confirmation request: `%NEW_EMAIL%` identifies the replacement address and
`%LINK%` reverses an unauthorized change.
