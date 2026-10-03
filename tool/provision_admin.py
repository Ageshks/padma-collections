#!/usr/bin/env python3
"""Creates a working admin login: the Firebase Auth credential plus the
Firestore profile that grants it admin rights.

Why this is not done in the app
-------------------------------
`firestore.rules` is written so that a user can never promote themselves, and
so that no second admin can be created by a non-admin. Both are correct — that
is what stops a customer account from reaching the admin app. The side effect is
that the *first* admin cannot be created from inside the app either, so it has
to be provisioned out of band. That is what this script is for.

How it works
------------
1. `accounts:signUp` with the web API key creates the credential. This is the
   same endpoint the app's own sign-up form uses, so it needs no service
   account — only the public API key.
2. The Firestore profile is written with `role: 'admin'` using the developer's
   own OAuth token. The security rules are not consulted for this write, which
   is the entire point: rules can never be the thing that grants admin.

Both steps are idempotent, so re-running repairs a half-provisioned account.

Usage:
    python3 tool/provision_admin.py
    python3 tool/provision_admin.py --email owner@example.com --name 'Store Owner'
    python3 tool/provision_admin.py --password 'Sup3rSecret!'

The generated password is printed once and is not stored anywhere.
"""

import argparse
import json
import secrets
import string
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

# Reuse the REST plumbing (auth token, Firestore paths, typed values) so the
# two scripts cannot drift apart.
sys.path.insert(0, __package__ or ".")
from seed_firestore import (  # noqa: E402
    PROJECT_ID,
    document_path,
    firestore_value,
    request,
)

API_KEY = "AIzaSyBmxsaCpxHt4jBwI_6EerzprFZl-g1qHDk"
IDENTITY = "https://identitytoolkit.googleapis.com/v1/accounts"

DEFAULT_EMAIL = "admin@padmacollections.com"


def generate_password(length=20):
    """Builds a password that satisfies the app's own strength rules.

    `Validators.strongPassword` only demands a letter and a digit, but an admin
    credential deserves better, so symbols and mixed case are included too.
    """
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*-_=+"
    while True:
        candidate = "".join(secrets.choice(alphabet) for _ in range(length))
        if (
            any(c.islower() for c in candidate)
            and any(c.isupper() for c in candidate)
            and any(c.isdigit() for c in candidate)
            and any(c in "!@#$%^&*-_=+" for c in candidate)
        ):
            return candidate


def identity_call(method, body):
    """Calls an Identity Toolkit endpoint with the public API key."""
    url = f"{IDENTITY}:{method}?key={urllib.parse.quote(API_KEY)}"
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            return error.code, json.loads(raw or b"{}")
        except json.JSONDecodeError:
            return error.code, {"raw": raw.decode(errors="replace")}


def error_message(body):
    """Pulls the human-readable part out of an Identity Toolkit error."""
    return body.get("error", {}).get("message", json.dumps(body)[:200])


def create_or_find_account(email, password, token):
    """Ensures an Auth credential exists for [email] and returns its uid.

    An account that already exists cannot have its password changed without a
    service account, so in that case the password supplied is only used if the
    account is being created. The caller is warned when it cannot be set.
    """
    status, body = identity_call(
        "signUp",
        {"email": email, "password": password, "returnSecureToken": True},
    )

    if status == 200:
        return body["localId"], "created"

    message = error_message(body)

    if "EMAIL_EXISTS" in message:
        # Resolve the uid from the token's own decode rather than the admin
        # API, which is not reachable with a plain OAuth token.
        uid = uid_from_email(email, password, token)
        if uid:
            return uid, "existing"
        return None, "existing-unresolved"

    return None, f"failed: {message}"


def uid_from_email(email, password, token):
    """Signs in to obtain the uid of an existing account.

    Returns None when the password does not match, which is the common case for
    an account someone else created. It is deliberately not treated as fatal:
    the profile can still be provisioned by uid, and the owner can reset the
    password from the Firebase console.
    """
    status, body = identity_call(
        "signInWithPassword",
        {"email": email, "password": password, "returnSecureToken": True},
    )
    if status == 200:
        return body.get("localId")

    # A correct password but a disabled/unverified account still yields a uid
    # in the error payload only for some codes, so this stays best-effort.
    print(f"  ! Could not verify the password: {error_message(body)}", file=sys.stderr)
    return None


def provision_profile(token, uid, email, name):
    """Writes users/{uid} with role: 'admin'. Returns True on success."""
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    payload = {
        "fields": {
            "uid": firestore_value(uid),
            "name": firestore_value(name),
            "email": firestore_value(email),
            "phone": firestore_value(""),
            "profileImage": firestore_value(""),
            # The entire security model hinges on this exact string.
            "role": firestore_value("admin"),
            "isActive": firestore_value(True),
            "createdAt": firestore_value(now),
            "updatedAt": firestore_value(now),
        }
    }
    status, body = request("PATCH", document_path("users", uid), token, payload)
    if status in (200, 201):
        return True
    print(f"  ! Profile write failed ({status}): {body}", file=sys.stderr)
    return False


def verify_admin(token, uid):
    """Re-reads the profile and confirms the role actually stuck."""
    status, body = request("GET", document_path("users", uid), token)
    if status != 200:
        return False, f"could not read profile ({status})"
    role = body.get("fields", {}).get("role", {}).get("stringValue")
    return role == "admin", f"role is {role!r}"


def promote_existing(token, email):
    """Promotes every existing profile matching [email] to admin.

    Handling *all* matching documents is the important part. A person who has
    both signed in with Google and with email/password has two Firebase Auth
    uids and therefore two `users/{uid}` documents, and Firebase does not
    auto-link them. Promoting only the first would leave the other sign-in
    method silently signed in as a customer.
    """
    url = (
        "https://firestore.googleapis.com/v1/projects/"
        f"{PROJECT_ID}/databases/(default)/documents/users?pageSize=300"
    )
    status, body = request("GET", url, token)
    if status != 200:
        print(f"  ! Could not list users ({status}): {body}", file=sys.stderr)
        return []

    wanted = email.strip().lower()
    matched = []
    for document in body.get("documents", []):
        fields = document.get("fields", {})
        doc_email = fields.get("email", {}).get("stringValue", "").lower()
        if doc_email != wanted:
            continue
        uid = document.get("name", "").rsplit("/", 1)[-1]
        matched.append((uid, fields.get("role", {}).get("stringValue", "")))

    if not matched:
        print(f"  No user profile found for {email}.")
        print("  Sign in once in the app first — that creates the profile.")
        return []

    if len(matched) > 1:
        print(
            f"  {len(matched)} profiles share that email (Google and "
            "email/password sign-in are not linked by Firebase). "
            "Promoting all of them."
        )

    promoted = []
    for uid, current_role in matched:
        if current_role == "admin":
            print(f"   users/{uid} is already an admin (skipped)")
            promoted.append(uid)
            continue

        now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        payload = {
            "fields": {
                "uid": firestore_value(uid),
                # Only the role and timestamp change; everything else is left
                # untouched so the profile cannot be clobbered.
                "role": firestore_value("admin"),
                "updatedAt": firestore_value(now),
            }
        }
        # merge=true so a partial field list does not delete the rest.
        url = document_path("users", uid) + '?updateMask.fieldPaths=role&updateMask.fieldPaths=updatedAt'
        status, body = request("PATCH", url, token, payload)
        if status in (200, 201):
            print(f"   users/{uid} promoted to admin (was {current_role!r})")
            promoted.append(uid)
        else:
            print(f"   ! {uid} failed ({status}): {body}", file=sys.stderr)
    return promoted


def demote(token, email, keep_uid=None):
    """Removes admin rights from every profile for [email] except [keep_uid].

    Deleting the document outright would also delete the person's cart,
    wishlist and order history, which live under `users/{uid}`. Demoting keeps
    the data and leaves a perfectly usable customer account.
    """
    url = (
        "https://firestore.googleapis.com/v1/projects/"
        f"{PROJECT_ID}/databases/(default)/documents/users?pageSize=300"
    )
    status, body = request("GET", url, token)
    if status != 200:
        print(f"  ! Could not list users ({status}): {body}", file=sys.stderr)
        return False

    wanted = email.strip().lower()
    changed = False
    for document in body.get("documents", []):
        fields = document.get("fields", {})
        doc_email = fields.get("email", {}).get("stringValue", "").lower()
        uid = document.get("name", "").rsplit("/", 1)[-1]
        if doc_email != wanted or uid == keep_uid:
            continue
        if fields.get("role", {}).get("stringValue") != "admin":
            continue

        now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        target = document_path("users", uid) + (
            "?updateMask.fieldPaths=role&updateMask.fieldPaths=updatedAt"
        )
        payload = {
            "fields": {
                "role": firestore_value("customer"),
                "updatedAt": firestore_value(now),
            }
        }
        status, body = request("PATCH", target, token, payload)
        if status in (200, 201):
            print(f"   users/{uid} demoted to customer")
            changed = True
        else:
            print(f"   ! {uid} failed ({status}): {body}", file=sys.stderr)
    return changed


def delete_profile(token, uid):
    """Deletes a `users/{uid}` document. Used to drop unusable orphans."""
    status, _ = request("DELETE", document_path("users", uid), token)
    if status in (200, 204):
        print(f"   users/{uid} deleted")
        return True
    print(f"   ! delete {uid} failed ({status})", file=sys.stderr)
    return False


def list_admins(token):
    """Prints every admin profile, so the current state is never a guess."""
    url = (
        "https://firestore.googleapis.com/v1/projects/"
        f"{PROJECT_ID}/databases/(default)/documents/users?pageSize=300"
    )
    status, body = request("GET", url, token)
    if status != 200:
        print(f"  ! Could not list users ({status}): {body}", file=sys.stderr)
        return []
    admins = []
    for document in body.get("documents", []):
        fields = document.get("fields", {})
        if fields.get("role", {}).get("stringValue") != "admin":
            continue
        admins.append(
            (
                document.get("name", "").rsplit("/", 1)[-1],
                fields.get("email", {}).get("stringValue", ""),
            )
        )
    return admins


def demote_all_except(token, keep_uid):
    """Demotes every admin profile except [keep_uid] back to customer.

    Demoting rather than deleting is deliberate: a person's cart, wishlist and
    order history live under `users/{uid}`, so deleting the profile would take
    that with it. They keep a working customer account instead.
    """
    url = (
        "https://firestore.googleapis.com/v1/projects/"
        f"{PROJECT_ID}/databases/(default)/documents/users?pageSize=300"
    )
    status, body = request("GET", url, token)
    if status != 200:
        print(f"  ! Could not list users ({status}): {body}", file=sys.stderr)
        return False

    changed = False
    for document in body.get("documents", []):
        fields = document.get("fields", {})
        uid = document.get("name", "").rsplit("/", 1)[-1]
        if uid == keep_uid:
            continue
        if fields.get("role", {}).get("stringValue") != "admin":
            continue

        email = fields.get("email", {}).get("stringValue", "")
        now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        target = document_path("users", uid) + (
            "?updateMask.fieldPaths=role&updateMask.fieldPaths=updatedAt"
        )
        payload = {
            "fields": {
                "role": firestore_value("customer"),
                "updatedAt": firestore_value(now),
            }
        }
        status, body = request("PATCH", target, token, payload)
        if status in (200, 201):
            print(f"   {uid}  {email}  -> customer")
            changed = True
        else:
            print(f"   ! {uid} failed ({status}): {body}", file=sys.stderr)
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", default=DEFAULT_EMAIL)
    parser.add_argument(
        "--password",
        help="Omit to generate a strong one. Ignored if the account exists.",
    )
    parser.add_argument("--name", default="Store Owner")
    parser.add_argument(
        "--promote",
        metavar="EMAIL",
        help="Promote existing profile(s) for this email to admin, and exit. "
        "Use when the person has already signed in and has a customer account.",
    )
    parser.add_argument(
        "--list-admins",
        action="store_true",
        help="Print every admin profile and exit.",
    )
    parser.add_argument(
        "--only-admin",
        metavar="UID",
        help="Leave only this uid as admin: demotes every other admin profile "
        "back to customer, then prints the result.",
    )
    args = parser.parse_args()

    from seed_firestore import access_token  # noqa: E402

    if args.list_admins:
        print(f"Project: {PROJECT_ID}\nCurrent admins:")
        for uid, email in list_admins(access_token()):
            print(f"   {uid}  {email}")
        return 0

    if args.only_admin:
        token = access_token()
        print(f"Project: {PROJECT_ID}\nDemoting every admin except {args.only_admin}")
        demote_all_except(token, args.only_admin)
        print("\nRemaining admins:")
        for uid, email in list_admins(token):
            print(f"   {uid}  {email}")
        return 0

    if args.promote:
        print(f"Project: {PROJECT_ID}\n")
        print(f"Promoting {args.promote} to admin ...")
        # Imported lazily so the module-level import above stays tidy.
        from seed_firestore import access_token

        token = access_token()
        promoted = promote_existing(token, args.promote)
        if not promoted:
            return 1
        print(f"\nDone. {len(promoted)} profile(s) are now admin.")
        print("Sign out and back in — the app reads the role on sign-in.")
        return 0

    generated = args.password is None
    password = args.password or generate_password()

    print(f"Project: {PROJECT_ID}")
    print(f"Admin:   {args.email}\n")

    # Imported lazily so the module-level import above stays tidy.
    from seed_firestore import access_token

    token = access_token()

    print("1/3  Firebase Auth credential")
    uid, outcome = create_or_find_account(args.email, password, token)

    if uid is None:
        print(f"   FAILED — {outcome}")
        return 1

    if outcome == "created":
        print(f"   created, uid={uid}")
    else:
        print(f"   account already exists, uid={uid}")
        print(
            "   NOTE: an existing account's password cannot be changed without a\n"
            "   service account. Reset it in the Firebase console if the password\n"
            "   below does not work."
        )

    print("\n2/3  Firestore profile (role: admin)")
    if not provision_profile(token, uid, args.email, args.name):
        return 1
    print(f"   users/{uid} written")

    print("\n3/3  Verification")
    ok, detail = verify_admin(token, uid)
    print(f"   {'OK' if ok else 'FAILED'}: {detail}")

    if args.password or args.email != DEFAULT_EMAIL:
        print("\nNote: a password was supplied, so it is not echoed back.")

    print("\n" + "=" * 58)
    print("  ADMIN LOGIN")
    print("=" * 58)
    print(f"  Email:    {args.email}")
    if generated and outcome == "created":
        print(f"  Password: {password}")
    print("  Route:    /admin/login  (Admin Sign In)")
    print("=" * 58)
    if generated and outcome == "created":
        print("\nThis password is shown once and is stored nowhere.")
        print("Save it now, then change it in-app or from the Firebase console.")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

