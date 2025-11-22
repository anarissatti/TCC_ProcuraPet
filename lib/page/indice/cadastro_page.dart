import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// === Firebase ===
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// === HTTP (IBGE) ===
import 'package:http/http.dart' as http;

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _foneCtrl   = TextEditingController();
  final _cidadeCtrl = TextEditingController();

  final _foneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'\d')},
    type: MaskAutoCompletionType.lazy,
  );

  bool _obscure = true;
  bool _loading = false;

  String? _uf; // estado selecionado (UF)

  /// Lista de UFs (pode vir da API também, mas é estável, então deixei fixa)
  final List<String> _ufs = const [
    "AC","AL","AM","AP","BA","CE","DF","ES","GO","MA","MG","MS","MT",
    "PA","PB","PE","PI","PR","RJ","RN","RO","RR","RS","SC","SE","SP","TO"
  ];

  /// Cache: UF -> lista de cidades
  final Map<String, List<String>> _cidadesPorUf = {};

  bool _carregandoCidades = false;
  String? _erroCidades;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _foneCtrl.dispose();
    _cidadeCtrl.dispose();
    super.dispose();
  }

  // ===== DIALOGO BONITINHO DE SUCESSO =====
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // só fecha no botão
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF34D399), // verdinho sucesso
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Conta criada com sucesso!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2B5B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Você já pode fazer login e aproveitar o Procura-se Pet 🐾',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // fecha o diálogo
                      Navigator.of(dialogContext).pop();

                      // opcional: limpar campos (nem precisa muito, pq vai voltar pra tela anterior)
                      _nomeCtrl.clear();
                      _emailCtrl.clear();
                      _passCtrl.clear();
                      _foneCtrl.clear();
                      _cidadeCtrl.clear();
                      _uf = null;

                      // volta para a tela anterior (login)
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Continuar',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== Carrega cidades da UF usando API IBGE =====
  Future<void> _carregarCidadesDaUf(String uf) async {
    // Se já tem cache, não busca de novo
    if (_cidadesPorUf.containsKey(uf)) {
      setState(() {
        _erroCidades = null;
      });
      return;
    }

    setState(() {
      _carregandoCidades = true;
      _erroCidades = null;
    });

    try {
      final uri = Uri.parse(
        'https://servicodados.ibge.gov.br/api/v1/localidades/estados/$uf/municipios',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      // Usa bodyBytes pra evitar problema de acentuação
      final List<dynamic> data = jsonDecode(utf8.decode(resp.bodyBytes));

      final cidades = data
          .map((m) => m['nome'].toString())
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      setState(() {
        _cidadesPorUf[uf] = cidades;
        _erroCidades = null;
      });
    } catch (e) {
      setState(() {
        _erroCidades = 'Falha ao carregar cidades de $uf. Tente novamente.';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao buscar cidades do IBGE: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _carregandoCidades = false;
        });
      }
    }
  }

  // ===== Cadastro: Auth + Firestore =====
  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_uf == null || _uf!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione seu estado (UF).')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final senha = _passCtrl.text;

      // 1) Cria usuário no Firebase Auth (email/senha)
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: senha, // não será salvo no Firestore
      );
      final uid = cred.user!.uid;

      // 2) Salva perfil no Firestore (docId = uid)
      await FirebaseFirestore.instance
          .collection('CadastroUsers')
          .doc(uid)
          .set({
        'Nome': _nomeCtrl.text.trim(),
        'E-mail': email,
        'Telefone': _foneFormatter.getUnmaskedText(), // só dígitos
        'Cidade': _cidadeCtrl.text.trim(),
        'UF': _uf!.trim().toUpperCase(),
        'criadoEm': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        // em vez de SnackBar no rodapé, mostra diálogo central
        _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('FirebaseAuthException: ${e.code} - ${e.message}');

      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Este e-mail já está em uso.';
          break;
        case 'invalid-email':
          msg = 'E-mail inválido.';
          break;
        case 'weak-password':
          msg = 'Senha fraca. Use 6+ caracteres.';
          break;
        case 'operation-not-allowed':
          msg = 'E-mail/senha desabilitados no projeto Firebase.';
          break;
        case 'network-request-failed':
          msg = 'Falha de rede. Verifique sua conexão com a internet.';
          break;
        default:
          msg = 'Erro ao cadastrar (${e.code}).';
          break;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      // ignore: avoid_print
      print('Erro genérico no cadastro: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cidadesDaUf = _cidadesPorUf[_uf] ?? const <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFFBBD0FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pets_rounded, size: 32, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Criar conta',
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
                    'Preencha seus dados para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withOpacity(0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _CardContainer(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // NOME COMPLETO
                          TextFormField(
                            controller: _nomeCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputDecoration(
                              label: 'NOME COMPLETO',
                              hint: 'Digite seu nome',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().length < 3) {
                                return 'Informe seu nome completo';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // EMAIL
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
                              final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                  .hasMatch(v);
                              if (!ok) return 'E-mail inválido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // SENHA
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: _inputDecoration(
                              label: 'SENHA',
                              hint: 'Mínimo de 6 caracteres',
                              suffixIcon: IconButton(
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Informe sua senha';
                              }
                              if (v.length < 6) {
                                return 'Mínimo de 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // ESTADO (UF)
                          DropdownButtonFormField<String>(
                            value: _uf,
                            decoration: _inputDecoration(
                              label: 'ESTADO (UF)',
                              hint: 'Selecione seu estado',
                            ),
                            items: _ufs
                                .map(
                                  (uf) => DropdownMenuItem(
                                    value: uf,
                                    child: Text(uf),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _uf = val;
                                _cidadeCtrl.clear();
                              });
                              if (val != null) {
                                _carregarCidadesDaUf(val);
                              }
                            },
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Selecione seu estado'
                                : null,
                          ),
                          const SizedBox(height: 8),

                          if (_carregandoCidades)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: 4.0, bottom: 6),
                                child: Text(
                                  'Carregando cidades...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            )
                          else if (_erroCidades != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(left: 4.0, bottom: 6),
                                child: Text(
                                  _erroCidades!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ),

                          // CIDADE (Autocomplete)
                          _CidadeAutocomplete(
                            controller: _cidadeCtrl,
                            label: 'CIDADE',
                            hint: 'Digite sua cidade',
                            getOpcoes: () => cidadesDaUf,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Informe sua cidade';
                              }
                              return null;
                            },
                            inputDecorationBuilder: _inputDecoration,
                          ),

                          const SizedBox(height: 14),

                          // TELEFONE
                          TextFormField(
                            controller: _foneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [_foneFormatter],
                            decoration: _inputDecoration(
                              label: 'TELEFONE',
                              hint: '(DDD) 00000-0000',
                            ),
                            validator: (v) {
                              final digits = _foneFormatter.getUnmaskedText();
                              if (digits.length < 10) {
                                return 'Telefone inválido';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 18),

                          // Botão CADASTRAR
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _loading ? null : _enviar,
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Cadastrar',
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
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Já tem conta? Fazer login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.black.withOpacity(.45),
        fontWeight: FontWeight.w500,
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
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}

class _CidadeAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final List<String> Function() getOpcoes;
  final String? Function(String?)? validator;
  final InputDecoration Function({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) inputDecorationBuilder;

  const _CidadeAutocomplete({
    required this.controller,
    required this.label,
    this.hint,
    required this.getOpcoes,
    this.validator,
    required this.inputDecorationBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: validator,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue text) {
                final query = text.text.trim().toLowerCase();
                if (query.isEmpty) return const Iterable<String>.empty();
                final base = getOpcoes();
                return base.where((c) => c.toLowerCase().contains(query));
              },
              fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
                textCtrl
                  ..text = controller.text
                  ..selection = controller.selection;
                textCtrl.addListener(() {
                  if (controller.text != textCtrl.text) {
                    controller.text = textCtrl.text;
                    controller.selection = textCtrl.selection;
                  }
                  state.didChange(textCtrl.text);
                });

                return TextField(
                  controller: textCtrl,
                  focusNode: focusNode,
                  decoration:
                      inputDecorationBuilder(label: label, hint: hint),
                  textCapitalization: TextCapitalization.words,
                );
              },
              onSelected: (v) {
                controller.text = v;
                state.didChange(v);
              },
              optionsViewBuilder: (ctx, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 220,
                        maxWidth: 420,
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final opt = options.elementAt(i);
                          return ListTile(
                            title: Text(opt),
                            onTap: () => onSelected(opt),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
