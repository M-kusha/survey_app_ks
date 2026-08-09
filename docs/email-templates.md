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

If you didn't create an EchoMeet account, you can ignore this — the address will
not be used.

— EchoMeet
```

## Email address change

**Subject**

```
Your EchoMeet sign-in address is changing
```

**Body**

```
Hello %DISPLAY_NAME%,

The address used to sign in to your EchoMeet account is being changed to
%EMAIL%. Confirm it here:

%LINK%

If you did not ask for this, do not click the link — contact your company
administrator straight away, because somebody may have access to your account.

— EchoMeet
```

This one is sent to the **old** address, which is what makes it the most
security-relevant of the three: it is the last message that reaches the real
owner if an account has been taken over.
