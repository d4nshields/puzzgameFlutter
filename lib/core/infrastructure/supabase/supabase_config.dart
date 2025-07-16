import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://vgvgcfgayqbifsqixerh.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZndmdjZmdheXFiaWZzcWl4ZXJoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI1NDgwODcsImV4cCI6MjA2ODEyNDA4N30.mebuyX9VjkgeDLdveAJgE49TzLr_jVYVVH6ZKkU2SXU';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}
