import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'cadastro_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _entrar() {
    if (_formKey.currentState!.validate()) {
      // TODO: autenticação real (ex.: Firebase Auth)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login efetuado (mock)!')),
      );
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // mesmo tom da página de cadastro
      backgroundColor: const Color(0xFFBBD0FF),
      body: SafeArea(
        child: Stack(
          children: [
            // ===== BOLHAS DECORATIVAS (mantidas) =====
            Positioned(top: -40, right: -30, child: _bubble(130, opacity: .20)),
            Positioned(top:  40, right:  24, child: _bubble( 70, opacity: .25)),
            Positioned(top:  90, left:   20, child: _bubble( 58, opacity: .18)),
            Positioned(top: 140, left:  -24, child: _bubble( 96, opacity: .22)),

            // ===== CONTEÚDO =====
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabeçalho com patinha + título (mesma linha do cadastro)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pets_rounded, size: 32, color: cs.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              letterSpacing: 0.2,
                              color: Color(0xFF1B2B5B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Faça login para continuar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Card branco translúcido (idêntico ao do cadastro)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // E-MAIL
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: _inputDecoration(
                                  label: 'E-MAIL',
                                  hint: 'Digite seu e-mail',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Informe seu e-mail';
                                  }
                                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
                                  if (!ok) return 'E-mail inválido';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // SENHA
                              TextFormField(
                                controller: _passCtrl,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                decoration: _inputDecoration(
                                  label: 'SENHA',
                                  hint: 'Digite sua senha',
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Informe sua senha';
                                  if (v.length < 6) return 'Mínimo de 6 caracteres';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 18),

                              // Botão ENTRAR (igual estilo do "Cadastrar")
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _entrar,
                                  child: const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Link para cadastro (mesmo padrão do cadastro -> "voltar ao login")
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CadastroPage()),
                          );
                        },
                        child: const Text('Não tem conta? Criar conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== InputDecoration idêntica à usada no cadastro_page =====
  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
      color: Colors.black.withOpacity(.6), // antes .85
      fontWeight: FontWeight.w500,         // antes w600
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCFD7EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCFD7EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF7C9EE7), width: 2),
      ),
      suffixIcon: suffixIcon,
    );
  }

  // ===== Bolha decorativa (mantida) =====
  Widget _bubble(double size, {double opacity = .2}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity + .05),
            Colors.white.withOpacity(opacity),
            Colors.transparent,
          ],
          stops: const [0.2, 0.55, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(opacity + .15),
          width: 1.2,
        ),
      ),
    );
  }
}
