import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false; // Реєстрація
  bool _isLoginMode = false; // Вхід
  String? _errorText;

  void _goToCatalog() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final nickname = _nicknameController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || nickname.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Заповніть усі поля');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'nickname': nickname,
        'email': email,
        'isSubscribed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _goToCatalog();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = switch (e.code) {
          'email-already-in-use' => 'Цей email вже зареєстрований',
          'invalid-email' => 'Некоректний email',
          'weak-password' => 'Пароль занадто короткий (мін. 6 символів)',
          _ => 'Помилка: ${e.message}',
        };
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Заповніть email і пароль');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      _goToCatalog();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = switch (e.code) {
          'user-not-found' => 'Користувач не знайдений',
          'wrong-password' => 'Хибний пароль',
          'invalid-credential' => 'Хибний email або пароль',
          'invalid-email' => 'Некоректний email',
          _ => 'Помилка: ${e.message}',
        };
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isLoginMode ? 'Вхід' : 'Реєстрація',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              if (!_isLoginMode) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _nicknameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Нікнейм',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : (_isLoginMode ? _login : _register),
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  _isLoginMode ? 'Увійти' : 'Зареєструватись',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                    _errorText = null;
                  });
                },
                child: Text(
                  _isLoginMode
                      ? 'Немає акаунту? Зареєструватись'
                      : 'Вже є акаунт? Увійти',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _goToCatalog,
                child: const Text(
                  'Пропустити',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}