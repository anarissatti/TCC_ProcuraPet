  import 'package:flutter/material.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});
  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _formKey = GlobalKey<FormState>();
  final _nome  = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();

  @override
  void dispose() { _nome.dispose(); _email.dispose(); _senha.dispose(); super.dispose(); }

  void _enviar() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro enviado (mock)!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nome,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v==null || v.trim().length<3) ? 'Informe seu nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'E-mail'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v==null || !RegExp(r'.+@.+\\..+').hasMatch(v)) ? 'E-mail inválido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _senha,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (v) => (v==null || v.length<6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _enviar, child: const Text('Cadastrar')),
            ],
          ),
        ),
      ),
    );
  }
}
