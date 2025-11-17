import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';
import 'main_menu_page.dart';
import 'dados_animal.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final Color azulFundo = const Color(0xFFBBD0FF);
  final Color azulEscuro = const Color(0xFF1B2B5B);

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      // Se não tiver usuário logado
      return Scaffold(
        backgroundColor: azulFundo,
        body: const SafeArea(
          child: Center(
            child: Text(
              'Nenhum usuário autenticado.\nFaça login para ver seu perfil.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1B2B5B),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    final uid = _user!.uid;

    return Scaffold(
      backgroundColor: azulFundo,
      body: SafeArea(
        child: Column(
          children: [
            // ===== TOPO COM MENU =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _iconTop(
                      context,
                      icon: Icons.menu_rounded,
                      label: 'Menu',
                      isActive: false,
                      pageBuilder: () => const MainMenuPage(),
                    ),
                    _iconTop(
                      context,
                      icon: Icons.pets_rounded,
                      label: 'Animais',
                      isActive: false,
                      pageBuilder: () => const HomePage(),
                    ),
                    _iconTop(
                      context,
                      icon: Icons.person_outline_rounded,
                      label: 'Perfil',
                      isActive: true, // estamos na página de perfil
                      pageBuilder: () => const PerfilPage(),
                    ),
                  ],
                ),
              ),
            ),

            // ===== CONTEÚDO =====
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabeçalho
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 32, color: Color(0xFF1B2B5B)),
                        const SizedBox(width: 8),
                        Text(
                          'Seu perfil',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: azulEscuro,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Veja seus dados e o histórico de animais cadastrados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ===== CARD DADOS DO USUÁRIO =====
                    _buildCard(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('CadastroUsers')
                            .doc(uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return const Text(
                              'Erro ao carregar dados do usuário.',
                              style: TextStyle(color: Colors.redAccent),
                            );
                          }

                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const Text(
                              'Dados de perfil não encontrados.',
                              style: TextStyle(
                                color: Color(0xFF1B2B5B),
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }

                          final data =
                              snapshot.data!.data() as Map<String, dynamic>? ??
                                  {};

                          final nome = (data['Nome'] ?? '').toString();
                          final email = (data['E-mail'] ?? _user!.email ?? '')
                              .toString();
                          final telefone = (data['Telefone'] ?? '').toString();
                          final cidade = (data['Cidade'] ?? '').toString();
                          final uf = (data['UF'] ?? '').toString();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seus dados',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: azulEscuro,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _infoRow('Nome', nome.isEmpty ? '-' : nome),
                              _infoRow('E-mail', email.isEmpty ? '-' : email),
                              _infoRow(
                                'Telefone',
                                telefone.isEmpty ? '-' : telefone,
                              ),
                              _infoRow(
                                'Cidade/UF',
                                (cidade.isEmpty && uf.isEmpty)
                                    ? '-'
                                    : '$cidade${uf.isEmpty ? '' : ' - $uf'}',
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== CARD HISTÓRICO DE ANIMAIS =====
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seus animais cadastrados',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: azulEscuro,
                            ),
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('animals')
                                .where('userId', isEqualTo: uid)
                                .snapshots(), // só animais do usuário logado
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (snapshot.hasError) {
                                return const Text(
                                  'Erro ao carregar histórico.',
                                  style: TextStyle(color: Colors.redAccent),
                                );
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return const Text(
                                  'Você ainda não cadastrou nenhum animal.',
                                  style: TextStyle(
                                    color: Color(0xFF1B2B5B),
                                    fontSize: 14,
                                  ),
                                );
                              }

                              // Ordena em memória pelo campo data_registro (mais novo primeiro)
                              final docs = snapshot.data!.docs.toList();
                              docs.sort((a, b) {
                                final ta = (a['data_registro']
                                            as Timestamp?)
                                        ?.toDate() ??
                                    DateTime(1900);
                                final tb = (b['data_registro']
                                            as Timestamp?)
                                        ?.toDate() ??
                                    DateTime(1900);
                                return tb.compareTo(ta);
                              });

                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: docs.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 12),
                                itemBuilder: (context, index) {
                                  final doc = docs[index];
                                  final animal = doc.data()
                                      as Map<String, dynamic>;

                                  final nome =
                                      (animal['nome'] ?? 'Sem nome').toString();
                                  final raca =
                                      (animal['raca'] ?? 'Raça não informada')
                                          .toString();
                                  final status = (animal['status'] ?? 'NORMAL')
                                      .toString()
                                      .toUpperCase();

                                  // 👉 Agora o item inteiro é clicável (abre detalhes)
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AnimalDetailsPage(
                                            animalId: doc.id,
                                            animalData: animal,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.pets_rounded,
                                            color: Color(0xFF1B2B5B),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  nome,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  raca,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        _getStatusColor(status),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          // ===== BOTÕES EDITAR / EXCLUIR =====
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Excluir',
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 20,
                                                  color: Colors.redAccent,
                                                ),
                                                onPressed: () =>
                                                    _confirmDelete(
                                                  context,
                                                  doc.id,
                                                  nome,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== CONFIRMAÇÃO DE EXCLUSÃO =====
  Future<void> _confirmDelete(
    BuildContext context,
    String docId,
    String nome,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir animal'),
        content: Text(
          'Tem certeza que deseja excluir o cadastro de "$nome"? '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await FirebaseFirestore.instance
            .collection('animals')
            .doc(docId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Animal excluído com sucesso.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e')),
          );
        }
      }
    }
  }

  // ===== Widget do card padrão =====
  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
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

  // ===== Linha de informação (rótulo + valor) =====
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF1B2B5B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== ÍCONES DO TOPO =====
  Widget _iconTop(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required Widget Function() pageBuilder,
  }) {
    final Color activeColor = const Color(0xFF1B2B5B);

    return GestureDetector(
      onTap: isActive
          ? null
          : () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => pageBuilder()),
              );
            },
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color: isActive ? activeColor : activeColor.withOpacity(0.7),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? activeColor : activeColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ===== COR DO STATUS DO ANIMAL =====
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DESAPARECIDO':
        return Colors.redAccent;
      case 'ENCONTRADO':
        return Colors.green;
      default:
        return const Color(0xFF1B2B5B);
    }
  }
}
