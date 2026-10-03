#!/usr/bin/env python3
"""End-to-end check that an admin credential can actually sign in.

Provisioning a user is not the same as that user being able to log in, so this
replays exactly what the app does on the Admin Sign In screen:

  1. `accounts:signInWithPassword` with the public API key
  2. decode the returned ID token and check who it belongs to
  3. read `users/{uid}` **with that ID token** through the Firestore REST API

Step 3 is the important one: it proves the security rules let this specific
signed-in user read the document that grants admin rights, using the same
credentials the phone would send. A profile that exists but is unreadable would
look fine in the console and fail in the app.

Usage:
    python3 tool/verify_admin_login.py <email> <password>
"""

import base64
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

PROJECT_ID = "padma-cb65f"
API_KEY = "AIzaSyBmxsaCpxHt4jBwI_6EerzprFZl-g1qHDk"
FIRESTORE = (
    f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}"
    "/databases/(default)/documents"
)


def http(method, url, body=None, headers=None):
    """Performs one request, returning (status, parsed_body)."""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, method=method, headers=headers or {}
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


def decode_claims(id_token):
    """Returns the payload of a JWT without verifying its signature.

    Verification is Firebase's job on the device; here the signature is not the
    question being asked, the identity is.
    """
    payload = id_token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    email, password = sys.argv[1], sys.argv[2]

    print(f"1. Signing in as {email} ...")
    status, body = http(
        "POST",
        "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
        f"?key={urllib.parse.quote(API_KEY)}",
        {"email": email, "password": password, "returnSecureToken": True},
        # Without this header the API cannot parse the body and answers
        # MISSING_EMAIL regardless of what was actually sent.
        {"Content-Type": "application/json"},
    )
    if status != 200:
        print(f"   FAILED ({status}): {body.get('error', {}).get('message')}")
        return 1

    uid = body["localId"]
    id_token = body["idToken"]
    print(f"   OK — uid {uid}")

    claims = decode_claims(id_token)
    print("\n2. Identity token")
    print(f"   email        : {claims.get('email')}")
    print(f"   sub == uid   : {claims.get('sub') == uid}")
    print(f"   email_verified: {claims.get('email_verified')}")

    print("\n3. Reading the profile as this signed-in user ...")
    status, profile = http(
        "GET", f"{FIRESTORE}/users/{uid}", headers={"Authorization": f"Bearer {id_token}"}
    )
    if status != 200:
        print(f"   FAILED ({status}): {profile}")
        print("   The rules denied this read — the admin app would not load.")
        return 1

    fields = profile.get("fields", {})
    role = fields.get("role", {}).get("stringValue")
    print(f"   OK — role is {role!r}")

    if role != "admin":
        print("\n   WARNING: this account is not an admin.")
        return 1

    # 4. Prove the role actually unlocks admin-only reads, rather than just
    #    existing. A profile with the right string but no effect is the failure
    #    mode worth catching here.
    print("\n4. Checking admin capabilities (via the security rules) ...")
    auth = {"Authorization": f"Bearer {id_token}"}

    checks = [
        ("list all users", "GET", f"{FIRESTORE}/users?pageSize=1", None),
        ("read the catalogue", "GET", f"{FIRESTORE}/products?pageSize=1", None),
        ("read all orders", "GET", f"{FIRESTORE}/orders?pageSize=1", None),
        ("read store settings", "GET", f"{FIRESTORE}/settings/app", None),
    ]

    failures = 0
    for label, method, url, payload in checks:
        status, _ = http(method, url, payload, auth)
        ok = status == 200
        failures += 0 if ok else 1
        print(f"   {'OK  ' if ok else 'FAIL'}  {label} ({status})")

    if failures:
        print(f"\n   {failures} admin read(s) were denied by the rules.")
        return 1

    print("\n   All admin reads allowed. The admin app will load.")
    print("   Log in at /admin/login with the credentials above.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
