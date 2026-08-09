# Supabase/Gotrue and audio/notification plugins parse JSON via reflection-free
# codecs, but keep model-ish classes defensively since R8 can be aggressive.
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# flutter_local_notifications schedules via reflection on this receiver.
-keep class com.dexterous.** { *; }
