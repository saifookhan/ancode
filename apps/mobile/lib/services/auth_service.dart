import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

class AuthState {
  AuthState({this.profile, this.isLoading = true, this.error});

  final Profile? profile;
  final bool isLoading;
  final String? error;
}

class AuthService extends ChangeNotifier {
  AuthService() {
    _init();
  }

  AuthState _state = AuthState();
  AuthState get state => _state;

  bool get isLoggedIn {
    final client = _client;
    if (client == null) return false;
    return client.auth.currentUser != null;
  }
  Profile? get profile => _state.profile;

  Future<void> refreshProfile() => _loadProfile();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfile() async {
    final client = _client;
    if (client == null) {
      _state = AuthState(
        profile: null,
        isLoading: false,
        error: 'Servizio non configurato',
      );
      notifyListeners();
      return;
    }
    final user = client.auth.currentUser;
    if (user == null) {
      _state = AuthState(profile: null, isLoading: false);
      notifyListeners();
      return;
    }
    try {
      final res = await client
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (res != null) {
        _state = AuthState(
          profile: Profile.fromJson(res),
          isLoading: false,
        );
      } else {
        _state = AuthState(profile: null, isLoading: false);
      }
    } catch (e) {
      _state = AuthState(profile: null, isLoading: false, error: e.toString());
    }
    notifyListeners();
  }

  void _init() {
    _loadProfile();
    _client?.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.userUpdated) {
        _loadProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _state = AuthState(profile: null, isLoading: false);
        notifyListeners();
      }
    });
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }
}
