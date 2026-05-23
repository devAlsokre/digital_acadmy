import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<SupabaseService> supabaseServiceProvider =
    Provider<SupabaseService>((ref) {
  return const SupabaseService();
});

class SupabaseService {
  const SupabaseService();

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;

  Session? get currentSession => client.auth.currentSession;
}
