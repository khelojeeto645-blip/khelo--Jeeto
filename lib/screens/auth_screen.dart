import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  String? _error;
  String? _info;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _referCtrl = TextEditingController();

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!email.endsWith('@gmail.com')) {
      setState(() {
        _error = 'Please enter your @gmail.com ID above first.';
        _info = null;
      });
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _error = null;
        _info = 'Password reset link sent to $email! Check your Gmail inbox.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _info = null;
        _error = e.message ?? 'Could not send reset email.';
      });
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text;
    if (!email.endsWith('@gmail.com') || pass.length < 6) {
      setState(() {
        _info = null;
        _error = 'Please enter a valid @gmail.com ID and password (min 6 chars).';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
        final uid = cred.user!.uid;
        final name = _nameCtrl.text.trim().isEmpty ? email.split('@')[0] : _nameCtrl.text.trim();
        final myCode = 'KJ-${name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase().padRight(4, 'X').substring(0, 4)}99';

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'coins': 0,
          'myReferCode': myCode,
          'referralClaimed': false,
          'adsWatchedToday': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Authentication failed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text('KHELO & JEETO', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const Text('Play Games & Earn Rewards', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Login')),
                  ButtonSegment(value: false, label: Text('Register')),
                ],
                selected: {_isLogin},
                onSelectionChanged: (v) => setState(() {
                  _isLogin = v.first;
                  _error = null;
                  _info = null;
                }),
              ),
              const SizedBox(height: 20),
              if (!_isLogin) ...[
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
              ],
              TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Gmail ID', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _forgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),
              if (!_isLogin) ...[
                const SizedBox(height: 12),
                TextField(controller: _referCtrl, decoration: const InputDecoration(labelText: 'Referral Code (Optional)', border: OutlineInputBorder())),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              if (_info != null) ...[
                const SizedBox(height: 8),
                Text(_info!, style: const TextStyle(color: Color(0xFF059669), fontSize: 13, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isLogin ? 'Sign In' : 'Register & Start Playing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
