# ProGuard / R8 rules for Padma Collections.
#
# Flutter's own engine rules ship with the Gradle plugin, so only app-specific
# concerns need to be listed here.

# --- Google Sign-In ---------------------------------------------------------
# The plugin resolves its provider classes reflectively, so R8 cannot see the
# references and would strip them, causing sign-in to fail only in release.
-keep class com.google.android.gms.common.api.ApiAvailability { *; }
-keep class com.google.android.gms.auth.api.identity.* { *; }
-keep class com.google.firebase.auth.** { *; }
-keepattributes Signature, InnerClasses, EnclosingMethod, Exceptions

# --- Crash reporting --------------------------------------------------------
# Crashlytics reads these attributes when symbolising a stack trace.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# --- Firestore models -------------------------------------------------------
# Documents are deserialised by field name, so the generic signatures must be
# preserved for the collection mapper to resolve types at runtime.
-keepattributes Signature
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- Kotlin coroutines ------------------------------------------------------
-dontwarn kotlinx.coroutines.**
