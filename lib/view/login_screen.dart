import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/base/view/base_view.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> signIn() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: pass.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> signUp() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.text.trim(), password: pass.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseView(
      viewModel: "",
      onPageBuilder: (BuildContext context, String value) {
        return Scaffold(
          appBar: AppBar(title: const Text('Giriş')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                ),
                TextField(
                  controller: pass,
                  decoration: const InputDecoration(labelText: 'Şifre'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                if (loading)
                  const CircularProgressIndicator()
                else
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(onPressed: signIn, child: const Text('Giriş yap')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(onPressed: signUp, child: const Text('Kayıt ol')),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
      onModelReady: (WidgetRef model) {},
    );
  }

  AppBar get appBar => AppBar(title: const Text("Mobil Uygulama"));
}
