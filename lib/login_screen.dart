import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State createState() => _LoginScreenState();
}

class _LoginScreenState extends State {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isFormFilled = false;
  bool _isLoading = false;

  // This subscription listens for the Supabase deep link callback
  late final StreamSubscription _authStateSubscription;

  // App Colors extracted from the design
  final Color primaryGreen = const Color(0xFF33D985);
  final Color linkBlue = const Color(0xFF1877F2);
  final Color borderColor = const Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_checkFormState);
    _passwordController.addListener(_checkFormState);

    // Listen for the deep link bringing the user back after Google Sign-In
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) {
          if (data.event == AuthChangeEvent.signedIn) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          }
        });
  }

  void _checkFormState() {
    final isValid =
        _usernameController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;
    if (isValid != _isFormFilled) {
      setState(() => _isFormFilled = isValid);
    }
  }

  // --- GOOGLE SIGN IN LOGIC ---
  Future _signInWithGoogle() async {
    try {
      // Triggers the OAuth flow on Supabase for desktop/web browsers
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.teknato://login-callback/',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in with Google: $e')),
      );
    }
  }

  Future _login() async {
    setState(() => _isLoading = true);

    try {
      final emailOrUsername = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // Supabase Auth sign-in
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailOrUsername,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _authStateSubscription
        .cancel(); // Cleans up the listener to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28.0,
                vertical: 40.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 80, // Accounts for padding
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Image.asset(
                        'assets/images/logo_icon.png',
                        height: 110,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      // Title
                      Text(
                        'Log in to TekNato',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: primaryGreen,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Input Fields
                      _buildInputField(
                        controller: _usernameController,
                        hintText: 'Username or email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _passwordController,
                        hintText: 'Password',
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),

                      // Forgot Password Link
                      GestureDetector(
                        onTap: () {
                          // Handle password reset
                        },
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: linkBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Divider with "Or"
                      _buildOrDivider(),
                      const SizedBox(height: 32),

                      // Google Login Button
                      _buildGoogleButton(),

                      const Spacer(),
                      const SizedBox(height: 40),

                      // Bottom Continue Button
                      _buildContinueButton(),
                      const SizedBox(height: 32),

                      // Sign Up Link
                      _buildSignUpText(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isFormFilled && !_isLoading ? _login : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          disabledBackgroundColor: primaryGreen.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Color(0xFF1877F2),
                  strokeWidth: 3,
                ),
              )
            : Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: linkBlue,
                ),
              ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryGreen, width: 2),
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade800, thickness: 0.8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Or',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade800, thickness: 0.8)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _signInWithGoogle,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        side: BorderSide(color: borderColor, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GoogleLogoWidget(),
          const SizedBox(width: 12),
          Text(
            'Continue with Google',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: linkBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpText() {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: linkBlue),
        children: [
          const TextSpan(text: 'New to TekNato? '),
          TextSpan(
            text: 'Sign Up',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupScreen()),
                );
              },
          ),
        ],
      ),
    );
  }
}

// Simple fallback vector painter for the Google "G" icon
class _GoogleLogoWidget extends StatelessWidget {
  const _GoogleLogoWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: CustomPaint(painter: _GoogleGLogoPainter()),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 7),
      3.14 * 1.15,
      3.14 * 0.55,
      false,
      paint,
    );
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 7),
      3.14 * 0.7,
      3.14 * 0.45,
      false,
      paint,
    );
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 7),
      3.14 * 0.15,
      3.14 * 0.55,
      false,
      paint,
    );
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 7),
      -0.2,
      0.65,
      false,
      paint,
    );

    final fillPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1, center.dy - 1.5, 8, 3.0),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
