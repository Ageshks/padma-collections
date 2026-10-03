#!/usr/bin/env python3
"""Regenerate firestore.indexes.json from the queries the app actually issues.

Keeping the index list in code (rather than by hand in JSON) means a new query
shows up as a diff here instead of a production error:

    FAILED_PRECONDITION: The query requires an index. ...

Run from the repository root:

    python3 tool/generate_indexes.py

Then deploy with:

    firebase deploy --only firestore:indexes
"""

import json
import os

ASC, DESC = "ASCENDING", "DESCENDING"


def index(collection_group, *fields):
    """Builds one composite index.

    Args:
        collection_group: Collection the query runs against.
        *fields: Alternating ``(field_path, order)`` tuples, in the same order
            the query constrains them.
    """
    return {
        "collectionGroup": collection_group,
        "queryScope": "COLLECTION",
        "fields": [{"fieldPath": f, "order": o} for f, o in fields],
    }


# The live query set, grouped by collection.
#
# Products: the catalogue grid filters on isActive and then sorts; category
# pages add categoryId; the three curated rails (new arrivals, fast moving,
# featured) each add their own boolean plus the sort key. A single-field index
# on isActive is implicit and is not listed here.
PRODUCT_INDEXES = [
    index("products", ("isActive", ASC), ("createdAt", DESC)),  # default: newest
    index("products", ("isActive", ASC), ("price", ASC)),  # cheapest first
    index("products", ("isActive", ASC), ("price", DESC)),  # most expensive first
    index("products", ("isActive", ASC), ("soldCount", DESC)),  # popular
    index(
        "products",
        ("categoryId", ASC),
        ("isActive", ASC),
        ("createdAt", DESC),
    ),  # category pages
    index(
        "products",
        ("categoryId", ASC),
        ("isActive", ASC),
        ("price", ASC),
    ),  # category pages, sorted by price
    index(
        "products",
        ("isActive", ASC),
        ("isNewArrival", DESC),
        ("createdAt", DESC),
    ),  # new-arrivals rail
    index(
        "products",
        ("isActive", ASC),
        ("isFastMoving", DESC),
        ("soldCount", DESC),
    ),  # fast-moving rail
    index(
        "products",
        ("isActive", ASC),
        ("isFeatured", DESC),
        ("createdAt", DESC),
    ),  # featured rail
]

# Orders: a customer's list, plus the admin's status filter in both directions
# (newest-first for triage, oldest-first for "oldest pending request").
ORDER_INDEXES = [
    index("orders", ("userId", ASC), ("createdAt", DESC)),  # my orders
    index("orders", ("status", ASC), ("createdAt", DESC)),  # admin, newest first
    index("orders", ("status", ASC), ("createdAt", ASC)),  # admin, oldest first
]

# Notifications: a customer's feed, and its unread-only view.
NOTIFICATION_INDEXES = [
    index("notifications", ("userId", ASC), ("createdAt", DESC)),
    index("notifications", ("userId", ASC), ("isRead", ASC), ("createdAt", DESC)),
]

# Customer management filters by role and sorts newest-first.
USER_INDEXES = [index("users", ("role", ASC), ("createdAt", DESC))]

# Banners and categories: both filter on isActive and order by sortOrder.
#
# These two were missed on the first pass and only surfaced at runtime as
# FAILED_PRECONDITION from the running app — which is the whole reason the
# index list is generated from the query set rather than kept in JSON.
CATALOGUE_SIDEBAR_INDEXES = [
    index("banners", ("isActive", ASC), ("sortOrder", ASC)),
    index("categories", ("isActive", ASC), ("sortOrder", ASC)),
]

INDEXES = (
    PRODUCT_INDEXES
    + CATALOGUE_SIDEBAR_INDEXES
    + ORDER_INDEXES
    + NOTIFICATION_INDEXES
    + USER_INDEXES
)

OUTPUT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "firestore.indexes.json",
)


def main():
    payload = {"indexes": INDEXES, "fieldOverrides": []}
    with open(OUTPUT_PATH, "w") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")
    print(f"Wrote {len(INDEXES)} indexes to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
