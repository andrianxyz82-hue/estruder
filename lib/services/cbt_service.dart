import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CbtService {
  static const String _cbtUrlKey = 'cbt_url';
  static const String _defaultUrl = 'https://google.com'; // Default for testing
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get CBT URL - Use SharedPreferences first for reliability
  Future<String> getCbtUrl() async {
    // Try local storage first (more reliable)
    final prefs = await SharedPreferences.getInstance();
    final localUrl = prefs.getString(_cbtUrlKey);
    
    if (localUrl != null && localUrl.isNotEmpty) {
      print('✅ CBT URL loaded from local storage: $localUrl');
      return localUrl;
    }

    // Try Supabase as fallback
    try {
      final response = await _supabase
          .from('system_settings')
          .select('value')
          .eq('key', 'cbt_url')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final url = response['value'] as String;
        // Cache it locally
        await _saveLocally(url);
        print('✅ CBT URL loaded from Supabase: $url');
        return url;
      }
    } catch (e) {
      print('Error fetching CBT URL from Supabase: $e');
    }

    // Return default if nothing found
    print('⚠️ Using default CBT URL: $_defaultUrl');
    return _defaultUrl;
  }

  // Save CBT URL - Save to SharedPreferences first, then try Supabase
  Future<void> saveCbtUrl(String url) async {
    // Save locally first (always works)
    await _saveLocally(url);
    print('✅ CBT URL saved to local storage: $url');

    // Try to save to Supabase (optional)
    try {
      await _supabase.from('system_settings').upsert({
        'key': 'cbt_url',
        'value': url,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'key');
      print('✅ CBT URL saved to Supabase: $url');
    } catch (e) {
      print('Error saving CBT URL to Supabase: $e');
      // Not critical - local storage is enough for testing
    }
  }

  Future<void> _saveLocally(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cbtUrlKey, url);
  }
}
