import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // Para PictureRecorder

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart'; // Para RenderRepaintBoundary
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart'; // NECESSÁRIO
import 'package:path_provider/path_provider.dart'; // NECESSÁRIO

// --- DEFINIÇÃO DE CORES DA PÁGINA EXEMPLO ---
const Color kPrimaryDarkBlue = Color(0xFF1A237E);
const Color kAccentLightBlue = Color(0xFF4FC3F7);
const Color kLightBlueBackground = Color(0xFFBBD0FF);
// Mantendo o seu tom para o botão/destaque, mas harmonizando
const Color kActionColor = Color(0xFFE56E94); // Era azulEscuro no original

// *******************************************************************
// URL BASE DO SEU FIREBASE HOSTING (CONFIRMADA: tcc-procurapet)
// Esta constante define a página web que o QR Code irá abrir.
// *******************************************************************
const String RESCUE_BASE_URL = 'https://tcc-procurapet.web.app/resgate.html';

class QRCodeGeneratorPage extends StatefulWidget {
  const QRCodeGeneratorPage({super.key});

  @override
  State<QRCodeGeneratorPage> createState() => _QRCodeGeneratorPageState();
}

class _QRCodeGeneratorPageState extends State<QRCodeGeneratorPage> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _qrKey =
      GlobalKey(); // CHAVE GLOBAL para capturar o widget QrImageView
  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();

  String _qrDataUrl = ''; // A URL final que o QR Code irá codificar
  String _currentPetId = ''; // O ID único gerado pelo Firestore
  bool _isLoading = false;

  @override
  void dispose() {
    _petNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  // --- FUNÇÕES DE LÓGICA ---

  // Função para salvar os dados no Firestore e obter o ID único
  Future<String?> _savePetDataToFirestore(Map<String, dynamic> petData) async {
    try {
      final db = FirebaseFirestore.instance;

      // Salva na coleção 'pets_qr_data'
      final docRef = await db.collection('pets_qr_data').add(petData);

      return docRef.id;
    } catch (e) {
      print('Erro ao salvar dados no Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao salvar dados. Verifique a inicialização do Firebase e as Regras de Segurança. ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // Função principal para gerar o QR Code
  Future<void> _generateQRCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _qrDataUrl = '';
      _currentPetId = '';
    });

    try {
      final String? userId = FirebaseAuth.instance.currentUser?.uid;

      final petData = {
        'petName': _petNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'conditions': _conditionsController.text.trim().isEmpty
            ? 'Nenhuma informação adicional.'
            : _conditionsController.text.trim(),
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final petId = await _savePetDataToFirestore(petData);

      if (petId == null) return;

      final String finalUrl = '$RESCUE_BASE_URL?id=$petId';

      setState(() {
        _currentPetId = petId;
        _qrDataUrl = finalUrl;
      });
    } catch (e) {
      print('Erro ao gerar QR Code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro interno ao processar QR Code.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🚨 FUNÇÃO ATUALIZADA PARA USAR ImageGallerySaverPlus.saveImage
  Future<void> _saveQrCodeToGallery() async {
    if (_qrDataUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, gere o QR Code primeiro.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Captura o widget QrImageView como imagem (PNG Bytes)
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // 2. Salva a imagem na galeria usando ImageGallerySaverPlus.saveImage
      // Isso é mais direto e preferido do que salvar em um arquivo temporário.
      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        name: 'procurapet_qr_${_currentPetId}', // Nome do arquivo
        quality: 100,
      );

      // O resultado de saveImage é um Map, verificamos 'isSuccess'
      final bool isSuccess = result?['isSuccess'] == true;

      if (isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ QR Code salvo na Galeria!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Não foi possível salvar na galeria. Verifique as permissões.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Erro ao salvar QR Code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar imagem: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- INPUT DECORATION NO ESTILO DA PÁGINA EXEMPLO ---
  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label.toUpperCase(), // Estilo da página de exemplo
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.black.withOpacity(.6),
        fontWeight: FontWeight.w500,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always, // Igual ao exemplo
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFCFD7EA),
        ), // Cor mais clara
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCFD7EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF7C9EE7),
          width: 2,
        ), // Azul suave no foco
      ),
      suffixIcon: suffixIcon,
    );
  }

  // --- CAMPO DE TEXTO NO ESTILO DA PÁGINA EXEMPLO ---
  Widget _buildInputField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: _inputDecoration(label: label, hint: hint),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Este campo é obrigatório';
          }
          return null;
        },
      ),
    );
  }

  // --- BOLHA DECORATIVA (REPLICADA DO EXEMPLO) ---
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

  // --- WIDGET BUILD REESTILIZADO ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBlueBackground, // Fundo azul claro
      body: SafeArea(
        child: Stack(
          children: [
            // ===== BOLHAS DECORATIVAS (COPIADAS DO EXEMPLO) =====
            Positioned(top: -40, right: -30, child: _bubble(130, opacity: .20)),
            Positioned(top: 40, right: 24, child: _bubble(70, opacity: .25)),
            Positioned(top: 90, left: 20, child: _bubble(58, opacity: .18)),
            Positioned(top: 140, left: -24, child: _bubble(96, opacity: .22)),

            // Botão de Voltar (No lugar do AppBar)
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: kPrimaryDarkBlue,
                ),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.5),
                ),
              ),
            ),

            // ===== CONTEÚDO PRINCIPAL =====
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabeçalho (similar ao do exemplo)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          size: 32,
                          color: kPrimaryDarkBlue,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Gerar Placa de Identificação',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                24, // Menor que o 28 do exemplo, cabe mais
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: 0.2,
                            color: kPrimaryDarkBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Preencha os dados para gerar a plaquinha com QR Code.\nOs dados serão salvos no seu banco de dados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Card branco translúcido (COMO NA PÁGINA EXEMPLO)
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // --- Títulos dentro do Card ---
                            Text(
                              'Informações do Pet',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: kPrimaryDarkBlue,
                                fontSize: 18,
                              ),
                            ),
                            const Divider(color: Color(0xFFCFD7EA), height: 18),

                            // Campos do Pet
                            _buildInputField(
                              _petNameController,
                              'Nome do Pet',
                              'Ex: Rex',
                            ),

                            const SizedBox(height: 14),

                            // Campos do Tutor
                            Text(
                              'Informações do Tutor',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: kPrimaryDarkBlue,
                              ),
                            ),
                            const Divider(color: Color(0xFFCFD7EA), height: 18),
                            _buildInputField(
                              _ownerNameController,
                              'Nome do Tutor',
                              'Ex: Ana Silva',
                            ),
                            _buildInputField(
                              _phoneController,
                              'Telefone de Contato',
                              'Ex: (99) 99999-9999',
                              keyboardType: TextInputType.phone,
                            ),
                            _buildInputField(
                              _addressController,
                              'Endereço',
                              'Ex: Rua Principal, 123 - Bairro',
                              maxLines: 2,
                            ),
                            _buildInputField(
                              _conditionsController,
                              'Condições Específicas (Opcional)',
                              'Ex: Vacinado, toma remédio X, chipado.',
                              maxLines: 3,
                              isRequired: false,
                            ),
                            const SizedBox(height: 14),

                            // Botão Gerar QR Code (FilledButton, estilo do exemplo)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isLoading ? null : _generateQRCode,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      kActionColor, // Cor de ação customizada
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 5,
                                ),
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.qr_code_2_rounded,
                                        size: 28,
                                      ),
                                label: Text(
                                  _isLoading
                                      ? 'Salvando e Gerando...'
                                      : 'Salvar Dados e Gerar QR Code',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800, // Mais bold
                                    letterSpacing: 0.3, // Mais espaçamento
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Se o QR Code foi gerado ---
                    if (_qrDataUrl.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      Text(
                        'QR Code da Placa (ID: $_currentPetId)',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kPrimaryDarkBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Card/Container do QR Code
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                              0.95,
                            ), // Mais opaco para visibilidade
                            borderRadius: BorderRadius.circular(
                              20,
                            ), // Mais arredondado
                            border: Border.all(
                              color: kActionColor.withOpacity(0.5),
                              width: 3,
                            ), // Borda sutil de destaque
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15, // Maior blur
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: RepaintBoundary(
                            key: _qrKey,
                            child: QrImageView(
                              data: _qrDataUrl,
                              version: QrVersions.auto,
                              size: 250.0,
                              backgroundColor: Colors.white,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: kPrimaryDarkBlue, // Cor do exemplo
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: kPrimaryDarkBlue, // Cor do exemplo
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botão Salvar QR Code (OutlineButton, estilo do exemplo)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _saveQrCodeToGallery,
                          icon: const Icon(Icons.download, size: 24),
                          label: Text(
                            _isLoading
                                ? 'Salvando...'
                                : 'Salvar QR Code na Galeria',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kActionColor, // Cor do texto/ícone
                            backgroundColor: Colors.white, // Fundo branco
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(
                              color: kActionColor,
                              width: 2,
                            ), // Borda colorida
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'O QR Code foi gerado com sucesso! Imprima e insira na coleira do seu pet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
