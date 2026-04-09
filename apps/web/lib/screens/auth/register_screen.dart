import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  SupabaseClient? get _authClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _surnameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _error = null;
      _isLoading = true;
    });
    final client = _authClient;
    if (client == null) {
      setState(() {
        _isLoading = false;
        _error = 'Authentication service is not ready. Please reload and try again.';
      });
      return;
    }
    try {
      final authRes = await client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'name': _nameController.text.trim(),
          'surname': _surnameController.text.trim(),
        },
      );
      final newUser = authRes.user;
      if (newUser != null) {
        try {
          await client.from('profiles').upsert({
            'user_id': newUser.id,
            'email': _emailController.text.trim(),
            'name': '${_nameController.text.trim()} ${_surnameController.text.trim()}'.trim(),
          }, onConflict: 'user_id');
        } catch (_) {
          // Trigger-based setups may already create this row.
        }
      }
      if (!mounted) return;
      await Provider.of<AuthService>(context, listen: false).refreshProfile();
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      final message = e.toString();
      if (mounted) {
        setState(
          () => _error = message.contains('LateInitializationError')
              ? 'Authentication service is not ready. Please reload and try again.'
              : message,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _fieldLabel(String text, double size) => Text(
        text,
        style: TextStyle(
          color: const Color(0xFF2E3440),
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      );

  InputDecoration _fieldDecoration({
    required String hint,
    required Color borderColor,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA8A8B2)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lavanda, width: 1.4),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildAuthDrawer(double screenWidth) {
    final drawerWidth = (screenWidth * 0.82).clamp(300.0, 380.0);
    return Drawer(
      width: drawerWidth,
      shape: const RoundedRectangleBorder(),
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Image.asset('assets/logo_mark.png', width: 54, height: 54, fit: BoxFit.contain),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, size: 32, color: Color(0xFF4D5662)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE6E6E6)),
            const SizedBox(height: 30),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 34),
              child: Text('FAQ', style: TextStyle(color: Color(0xFF4D5662), fontSize: 24, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 30),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 34),
              child: Text('Useage Ideas', style: TextStyle(color: Color(0xFF4D5662), fontSize: 24, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 34),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: SizedBox(
                height: 70,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    Navigator.of(context).maybePop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mutedText = const Color(0xFF8C8C9A);
    final cardBorder = const Color(0xFFE4E4E8);
    final fieldBorder = const Color(0xFFD9D9DE);
    final signInPurple = const Color(0xFF9A80E8);
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 390;
    final wide = screenWidth >= 900;
    final contentWidth = wide ? 760.0 : 640.0;
    final bodySize = compact ? 15.0 : 20.0;
    final labelSize = compact ? 16.0 : 18.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.biancoOttico,
      endDrawer: _buildAuthDrawer(screenWidth),
      appBar: AppBar(
        backgroundColor: AppColors.biancoOttico,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset('assets/logo_mark.png', width: 34, height: 34, fit: BoxFit.contain),
        ),
        leadingWidth: 58,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.menu_rounded, size: 32),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    ),
                    Text('Return to login', style: TextStyle(color: mutedText, fontSize: bodySize)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Create a new account',
                  style: TextStyle(color: Colors.black87, fontSize: compact ? 30 : 38, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a new account to access the system',
                  style: TextStyle(color: mutedText, fontSize: bodySize),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _fieldLabel('Name*', labelSize),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: _fieldDecoration(hint: 'Enter your name', borderColor: fieldBorder),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Surname*', labelSize),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _surnameController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: _fieldDecoration(hint: 'Enter your surname', borderColor: fieldBorder),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Email *', labelSize),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.black87),
                        keyboardType: TextInputType.emailAddress,
                        decoration: _fieldDecoration(hint: 'Enter your email', borderColor: fieldBorder),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Password *', labelSize),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.black87),
                        obscureText: _obscurePassword,
                        decoration: _fieldDecoration(
                          hint: 'Enter your password',
                          borderColor: fieldBorder,
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: mutedText),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Retype password *', labelSize),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPasswordController,
                        style: const TextStyle(color: Colors.black87),
                        obscureText: _obscureConfirmPassword,
                        decoration: _fieldDecoration(
                          hint: 'Confirm your password',
                          borderColor: fieldBorder,
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: mutedText),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 62,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: signInPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
