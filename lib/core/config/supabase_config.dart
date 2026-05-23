class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '192.168.103:8000',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
  );

  // TODO: Replace the placeholder values with self-hosted Supabase credentials.
  static String get initializationUrl {
    final bool hasHttpScheme = RegExp(
      r'^https?://',
      caseSensitive: false,
    ).hasMatch(url);

    if (hasHttpScheme) {
      return url;
    }

    return 'http://$url';
  }
}
