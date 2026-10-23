# shared_preferences_android calls into Kotlin through JNI (jnigen);
# R8 cannot see those calls, so keep the plugin and JNI support classes.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$* { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.jvm.internal.** { *; }
-keep class kotlin.Unit { *; }
-keep class kotlinx.coroutines.** { *; }

# flutter_local_notifications serialises scheduled notifications with Gson.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
