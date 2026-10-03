#!/usr/bin/env python3
"""Uploads the catalogue seed to Firestore and provisions the first admin.

Why this exists: `firestore.rules` refuses to let a user promote themselves, and
refuses to let anyone create a second admin. That is exactly the right rule, but
it means the *very first* admin can never be created from inside the app. This
script performs that one privileged write using the developer's own credentials,
then the normal rules take over.

It is idempotent — existing documents are left alone unless `--force` is given.

Usage:
    python3 tool/seed_firestore.py                 # seed + provision admin
    python3 tool/seed_firestore.py --force         # overwrite existing docs
    python3 tool/seed_firestore.py --provision-only

Prerequisites:
    tool/seed_data.json is present in this directory. It is checked in and is
    the canonical definition of the seed catalogue; this script only reads it.
    The admin already exists in Firebase Auth (email/password).
"""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

PROJECT_ID = "padma-cb65f"
CONFIGSTORE = os.path.expanduser("~/.config/configstore/firebase-tools.json")
SEED_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "tool",
    "seed_data.json",
)
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents"

# The admin account created in Firebase Auth. Provisioning only writes the
# Firestore *profile* document for it; the credential itself lives in Auth.
ADMIN_EMAIL = "admin@padmacollection.com"


def access_token():
    """Returns a usable access token for the Firestore REST API."""
    with open(CONFIGSTORE) as handle:
        configstore = json.load(handle)

    tokens = configstore["tokens"]
    cached = tokens.get("access_token")
    expires_at_ms = tokens.get("expires_at", 0)

    if cached and expires_at_ms / 1000 - 60 > time.time():
        return cached

    body = urllib.parse.urlencode(
        {
            "client_id": configstore["user"]["azp"],
            "refresh_token": tokens["refresh_token"],
            "grant_type": "refresh_token",
        }
    ).encode()
    request = urllib.request.Request(
        "https://oauth2.googleapis.com/token", data=body
    )
    with urllib.request.urlopen(request) as response:
        return json.load(response)["access_token"]


def request(method, url, token, payload=None):
    """Calls the Firestore REST API, returning (status, parsed_body)."""
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
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


def firestore_value(value):
    """Converts a JSON value into Firestore's typed field representation.

    Resolves the `{"__dateTime": ...}` wrapper used by tool/seed_data.json:
    it becomes a real Firestore timestamp. Without this, every `createdAt` would
    be stored as a string and `orderBy('createdAt')` would fail at runtime with
    a type error.
    """
    if isinstance(value, dict):
        if set(value.keys()) == {"__dateTime"}:
            return {"timestampValue": _timestamp(value["__dateTime"])}
        return {
            "mapValue": {"fields": {k: firestore_value(v) for k, v in value.items()}}
        }
    if isinstance(value, list):
        return {"arrayValue": {"values": [firestore_value(v) for v in value]}}
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, (int, float)):
        return {"doubleValue": value}
    if isinstance(value, str):
        return {"stringValue": value}
    if value is None:
        return {"nullValue": None}
    raise TypeError(f"Unsupported seed value: {value!r}")


def _timestamp(raw):
    """Normalises an ISO-8601 string into something Firestore accepts.

    Firestore rejects a timestamp with no timezone designator. Dart's
    `toIso8601String()` omits the suffix for a *local* DateTime, so a seed
    generated on a machine in a non-UTC zone would otherwise fail every write.
    """
    text = str(raw).strip()
    if text.endswith("Z") or text[-6:] in ("+00:00",) or text[-6] in "+-":
        return text
    return f"{text}Z"


def document_path(collection, doc_id):
    """Builds the REST URL for one document."""
    return f"{BASE}/{collection}/{urllib.parse.quote(doc_id, safe='')}"


def normalise_images(doc):
    """Converts legacy string image URLs to Cloudinary metadata objects.

    The seed predates the Cloudinary migration and stores bare URLs:

        "images": ["https://…", "https://…"]

    The app reads both, but writing the nested shape means a freshly seeded
    catalogue looks exactly like one created through the admin app. The first
    image becomes the primary, matching what the admin form does.

    A bare URL becomes an *external* image: no publicId, because nothing was
    uploaded to Cloudinary. It renders from the stored secureUrl and offers no
    re-upload or delete actions until the owner replaces it through the admin.

    This only reshapes the document; it uploads nothing.
    """
    images = doc.get("images")
    if not isinstance(images, list):
        return doc

    normalised = []
    for index, entry in enumerate(images):
        if isinstance(entry, str):
            normalised.append(
                {
                    "publicId": "",
                    "secureUrl": entry,
                    "resourceType": "image",
                    "isPrimary": index == 0,
                    "sortOrder": index,
                }
            )
        elif isinstance(entry, dict):
            normalised.append(entry)

    if normalised:
        doc["images"] = normalised
    return doc


def seed_collection(token, collection, documents, force):
    """Writes every document in a collection. Returns (created, skipped)."""
    created = skipped = 0
    for raw_doc in documents:
        doc = normalise_images(raw_doc)
        doc_id = (
            doc.get("productId") or doc.get("categoryId") or doc.get("bannerId")
        )
        if not doc_id:
            print(f"  ! {collection}: a document has no id; skipped")
            continue

        url = document_path(collection, doc_id)
        if not force:
            status, _ = request("GET", url, token)
            if status == 200:
                skipped += 1
                continue

        payload = {
            "fields": {
                k: firestore_value(v) for k, v in doc.items() if v is not None
            }
        }
        status, body = request("PATCH", url, token, payload)
        if status in (200, 201):
            created += 1
        else:
            print(f"  ! {collection}/{doc_id} failed ({status}): {body}")
    return created, skipped


def provision_admin(token, force, admin_uid=None):
    """Creates users/{uid} with role: 'admin' for the admin Auth account.

    [admin_uid] short-circuits the lookup for anyone who already knows the UID.
    Otherwise the UID is resolved from the admin's email, so this keeps working
    after the account is recreated.
    """
    uid = admin_uid

    if not uid:
        # `accounts:lookup` matches on UID and needs a user's ID token, so it is
        # the wrong endpoint here. `accounts:query` is the admin variant and
        # accepts an email, which is what we actually have.
        status, body = request(
            "POST",
            f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT_ID}/accounts:query",
            token,
            {"email": [ADMIN_EMAIL]},
        )

        if status == 200:
            records = body.get("records") or body.get("users") or []
            if records:
                uid = records[0].get("localId") or records[0].get("userId")

    if not uid:
        print(
            f"! Could not resolve '{ADMIN_EMAIL}' in Firebase Auth.\n"
            "  Find the UID with:\n"
            f"    firebase auth:export --project {PROJECT_ID} /tmp/auth.json\n"
            "  then re-run with:\n"
            "    python3 tool/seed_firestore.py --admin-uid <UID>"
        )
        return None

    url = document_path("users", uid)
    if not force:
        status, _ = request("GET", url, token)
        if status == 200:
            print(f"Admin profile already exists for {uid} (skipped)")
            return uid

    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    payload = {
        "fields": {
            "uid": firestore_value(uid),
            "name": firestore_value("Padma Admin"),
            "email": firestore_value(ADMIN_EMAIL),
            "phone": firestore_value(""),
            "profileImage": firestore_value(""),
            # The entire security model hinges on this exact string.
            "role": firestore_value("admin"),
            "isActive": firestore_value(True),
            "createdAt": firestore_value(now),
            "updatedAt": firestore_value(now),
        }
    }
    status, body = request("PATCH", url, token, payload)
    if status in (200, 201):
        print(f"Provisioned admin profile: users/{uid}")
        return uid

    print(f"! Admin provisioning failed ({status}): {body}")
    return None


def main():
    force = "--force" in sys.argv
    provision_only = "--provision-only" in sys.argv
    admin_uid = None
    if "--admin-uid" in sys.argv:
        admin_uid = sys.argv[sys.argv.index("--admin-uid") + 1]

    token = access_token()
    print(f"Project: {PROJECT_ID}\n")

    if not provision_only:
        if not os.path.exists(SEED_PATH):
            print(
                f"! {SEED_PATH} not found.\n"
                "  It ships with the repo; restore it from version control if missing."
            )
            return 1

        with open(SEED_PATH) as handle:
            seed = json.load(handle)

        for collection in ("categories", "products", "banners"):
            created, skipped = seed_collection(
                token, collection, seed.get(collection, []), force
            )
            print(
                f"{collection}: {created} created, {skipped} already present"
            )

        for doc_id, values in seed.get("settings", {}).items():
            url = document_path("settings", doc_id)
            if not force:
                status, _ = request("GET", url, token)
                if status == 200:
                    print(f"settings/{doc_id}: already present")
                    continue
            payload = {"fields": {k: firestore_value(v) for k, v in values.items()}}
            status, body = request("PATCH", url, token, payload)
            print(
                f"settings/{doc_id}: {'created' if status in (200, 201) else body}"
            )
        print()

    uid = provision_admin(token, force, admin_uid)
    if uid is None:
        return 1

    print("\nDone. The store is live.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

