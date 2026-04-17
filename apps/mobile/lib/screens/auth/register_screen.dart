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
          'plan': 'free',
        },
      );
      final newUser = authRes.user;
      if (newUser != null) {
        try {
          await client.from('profiles').upsert({
            'user_id': newUser.id,
            'email': _emailController.text.trim(),
            'name': '${_nameController.text.trim()} ${_surnameController.text.trim()}'.trim(),
            'plan': 'free',
          }, onConflict: 'user_id');
        } catch (_) {}
        try {
          await client.from('subscriptions').upsert({
            'user_id': newUser.id,
            'plan': 'free',
            'status': 'canceled',
          }, onConflict: 'user_id');
        } catch (_) {}
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
        style: AppTypography.bodyRegular(color: const Color(0xFF2E3440), fontSize: size),
      );

  InputDecoration _fieldDecoration({
    required String hint,
    required Color borderColor,
    required double hintSize,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyRegular(color: const Color(0xFFA8A8B2), fontSize: hintSize),
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

  @override
  Widget build(BuildContext context) {
    final mutedText = const Color(0xFF8C8C9A);
    final cardBorder = const Color(0xFFE4E4E8);
    final fieldBorder = const Color(0xFFD9D9DE);
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 390;
    final wide = screenWidth >= 900;
    final contentWidth = wide ? 760.0 : 640.0;
    final bodySize = compact ? 15.0 : 20.0;
    final labelSize = compact ? 16.0 : 18.0;

    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      appBar: AppBar(
        backgroundColor: AppColors.biancoOttico,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset('assets/logo_mark.png', width: 34, height: 34, fit: BoxFit.contain),
        ),
        leadingWidth: 58,
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
                    Text(
                      'Return to login',
                      style: AppTypography.bodyRegular(color: mutedText, fontSize: bodySize),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Create a new account',
                  textAlign: TextAlign.center,
                  style: AppTypography.titleExtraBold(
                    color: Colors.black87,
                    fontSize: compact ? 30 : 38,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a new account to access the system',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyRegular(color: mutedText, fontSize: bodySize),
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
                        textCapitalization: TextCapitalization.words,
                        keyboardType: TextInputType.name,
                        inputFormatters: const [CapitalizeFirstLetterFormatter()],
                        style: AppTypography.bodyRegular(color: Colors.black87, fontSize: bodySize),
                        decoration: _fieldDecoration(
                          hint: 'Enter your name',
                          borderColor: fieldBorder,
                          hintSize: bodySize,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Surname*', labelSize),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _surnameController,
                        textCapitalization: TextCapitalization.words,
                        keyboardType: TextInputType.name,
                        inputFormatters: const [CapitalizeFirstLetterFormatter()],
                        style: AppTypography.bodyRegular(color: Colors.black87, fontSize: bodySize),
                        decoration: _fieldDecoration(
                          hint: 'Enter your surname',
                          borderColor: fieldBorder,
                          hintSize: bodySize,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Email *', labelSize),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _emailController,
                        style: AppTypography.bodyRegular(color: Colors.black87, fontSize: bodySize),
                        keyboardType: TextInputType.emailAddress,
                        decoration: _fieldDecoration(
                          hint: 'Enter your email',
                          borderColor: fieldBorder,
                          hintSize: bodySize,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Password *', labelSize),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        style: AppTypography.bodyRegular(color: Colors.black87, fontSize: bodySize),
                        obscureText: _obscurePassword,
                        decoration: _fieldDecoration(
                          hint: 'Enter your password',
                          borderColor: fieldBorder,
                          hintSize: bodySize,
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
                        style: AppTypography.bodyRegular(color: Colors.black87, fontSize: bodySize),
                        obscureText: _obscureConfirmPassword,
                        decoration: _fieldDecoration(
                          hint: 'Confirm your password',
                          borderColor: fieldBorder,
                          hintSize: bodySize,
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
                      LimeRailPillButton(
                        onPressed: _isLoading ? null : _submit,
                        loading: _isLoading,
                        label: 'Register',
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
