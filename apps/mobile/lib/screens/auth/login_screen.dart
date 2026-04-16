import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter both email and password.');
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
      await client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        await Provider.of<AuthService>(context, listen: false).refreshProfile();
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
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
              child: Text(
                'FAQ',
                style: TextStyle(color: Color(0xFF4D5662), fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 30),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 34),
              child: Text(
                'Useage Ideas',
                style: TextStyle(color: Color(0xFF4D5662), fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 34),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: SizedBox(
                height: 70,
                child: FilledButton(
                  onPressed: () {
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
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: SizedBox(
                height: 70,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Register', style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w600)),
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
    final titleColor = Colors.black;
    final mutedText = const Color(0xFF8C8C9A);
    final cardBorder = const Color(0xFFE4E4E8);
    final fieldBorder = const Color(0xFFD9D9DE);
    final signInPurple = const Color(0xFF9A80E8);
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 390;
    final wide = screenWidth >= 900;
    final contentWidth = wide ? 760.0 : 640.0;
    final titleSize = compact ? 42.0 : 56.0;
    final heroSize = compact ? 24.0 : 34.0;
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
            child: Center(
              child: Column(
                children: [
                  Text(
                    'ANCODE',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'L I N K*  Y O U R  L I N K',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: compact ? 2.4 : 3.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'L1NK* YOUR LINK',
                    style: TextStyle(
                      color: mutedText,
                      fontSize: heroSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'New here? ',
                        style: TextStyle(color: mutedText, fontSize: bodySize),
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                ),
                        child: Text(
                          'Create an account',
                          style: TextStyle(
                            color: signInPurple,
                            fontSize: bodySize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
                        Text(
                          'Email *',
                          style: TextStyle(
                            color: const Color(0xFF2E3440),
                            fontSize: labelSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.black87),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'name@email.com',
                            hintStyle: const TextStyle(color: Color(0xFFA8A8B2)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.lavanda, width: 1.4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Password *',
                          style: TextStyle(
                            color: const Color(0xFF2E3440),
                            fontSize: labelSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passwordController,
                          style: const TextStyle(color: Colors.black87),
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            hintStyle: const TextStyle(color: Color(0xFFA8A8B2)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.lavanda, width: 1.4),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: mutedText,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
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
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Sign in',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 20,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Forgot your password?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.9),
                            fontSize: labelSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Demo: admin@ancode.com / admin123 o user@example.com / user123',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black.withOpacity(0.75), fontSize: compact ? 13 : 15),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
