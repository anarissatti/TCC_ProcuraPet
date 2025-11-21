import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // Para PictureRecorder

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart'; // Para RenderRepaintBoundary
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart'; // ✅ Novo e correto import
import 'package:path_provider/path_provider.dart'; // Necessário

// --- DEFINIÇÃO DE CORES (Padronizadas com a tela de inspiração) ---
const Color kPrimaryDarkBlue = Color(0xFF1B2B5B);
const Color kAccentPink = Color(0xFFE56E94);
const Color kLightBackgroundBlue = Color(0xFFBBD0FF);
const Color kBorderColor = Color(0xFF90CAF9); // Cor de borda de input

// *******************************************************************
// URL BASE DO SEU FIREBASE HOSTING (CONFIRMADA: tcc-procurapet)
// Esta constante define a página web que o QR Code irá codificar.
// O ID do Pet será automaticamente anexado como: ?id=ID_UNICO
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

  // Lógica inalterada
  Future<String?> _savePetDataToFirestore(Map<String, dynamic> petData) async {
    try {
      final db = FirebaseFirestore.instance;
      final docRef = await db.collection('pets_qr_data').add(petData);
      return docRef.id;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar dados. ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // Lógica inalterada
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
      // Adicionamos uma mensagem de sucesso discreta após gerar o QR Code
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ QR Code gerado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
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

  // Lógica inalterada (apenas a verificação do resultado foi adaptada para ImageGallerySaverPlus)
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
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/procurapet_qr_${_currentPetId}.png';
      final file = await File(filePath).create();
      await file.writeAsBytes(pngBytes);

      // 3. Salva a imagem na galeria usando **ImageGallerySaverPlus.saveFile**
      final result = await ImageGallerySaverPlus.saveFile(
        filePath,
        name: "procurapet_qr_${_currentPetId}",
      );

      // 4. Verifica o resultado
      if (result != null && result['isSuccess'] == true) {
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

      await file.delete();
    } catch (e) {
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

  // ===== InputDecoration no mesmo estilo da LoginPage =====
  InputDecoration _inputDecoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: kPrimaryDarkBlue,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: Colors.black.withOpacity(.6),
        fontWeight: FontWeight.w500,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: kAccentPink,
          width: 2,
        ), // Cor do botão no focus
      ),
    );
  }

  // Widget _buildInputField (REESTILIZADO)
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

  // ===== Bolha decorativa (Igual à tela de inspiração) =====
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackgroundBlue, // Fundo azul claro
      body: SafeArea(
        child: Stack(
          children: [
            // ===== BOLHAS DECORATIVAS (Estilo da tela de inspiração) =====
            Positioned(top: -40, right: -30, child: _bubble(130, opacity: .20)),
            Positioned(top: 40, right: 24, child: _bubble(70, opacity: .25)),
            Positioned(top: 90, left: 20, child: _bubble(58, opacity: .18)),
            Positioned(top: 140, left: -24, child: _bubble(96, opacity: .22)),

            // ===== CONTEÚDO PRINCIPAL =====
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabeçalho (Estilo da tela de inspiração)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 32,
                            color: kPrimaryDarkBlue,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Gerar Placa de\nIdentificação',
                            style: TextStyle(
                              fontSize: 24, // Levemente menor para caber
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              letterSpacing: 0.2,
                              color: kPrimaryDarkBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Preencha os dados de contato que serão\nexibidos caso seu pet seja encontrado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Card branco translúcido (Estilo da tela de inspiração)
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // TÍTULO: Informações do Pet
                            Text(
                              'Informações do Pet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: kAccentPink,
                              ),
                            ),
                            const Divider(color: Colors.black12, height: 18),
                            _buildInputField(
                              _petNameController,
                              'NOME DO PET',
                              'Ex: Rex',
                            ),

                            // TÍTULO: Informações do Tutor
                            Text(
                              'Informações do Tutor',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: kAccentPink,
                              ),
                            ),
                            const Divider(color: Colors.black12, height: 18),
                            _buildInputField(
                              _ownerNameController,
                              'NOME DO TUTOR',
                              'Ex: Ana Silva',
                            ),
                            _buildInputField(
                              _phoneController,
                              'TELEFONE DE CONTATO',
                              'Ex: (99) 99999-9999',
                              keyboardType: TextInputType.phone,
                            ),
                            _buildInputField(
                              _addressController,
                              'ENDEREÇO',
                              'Ex: Rua Principal, 123 - Bairro',
                              maxLines: 2,
                            ),
                            _buildInputField(
                              _conditionsController,
                              'CONDIÇÕES ESPECÍFICAS (Opcional)',
                              'Ex: Vacinado, toma remédio X, chipado.',
                              maxLines: 3,
                              isRequired: false,
                            ),
                            const SizedBox(height: 16),

                            // Botão Gerar QR Code (REESTILIZADO como FilledButton)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      kAccentPink, // Cor rosa/botão
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _generateQRCode,
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
                                      : 'Salvar Dados e\n Gerar QR Code',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ===== SEÇÃO QR CODE GERADO =====
                      if (_qrDataUrl.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'QR Code da Placa (ID: $_currentPetId)',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryDarkBlue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          // Card para o QR Code (Mantendo o estilo do card branco)
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kAccentPink, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: RepaintBoundary(
                              key: _qrKey, // Usa a chave global para a captura
                              child: QrImageView(
                                data: _qrDataUrl, // Usa a URL pública final
                                version: QrVersions.auto,
                                size: 250.0,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: kPrimaryDarkBlue,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: kPrimaryDarkBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // BOTÃO SALVAR QR CODE (Estilo secundário)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            // Usando OutlinedButton para ser o secundário
                            onPressed: _isLoading ? null : _saveQrCodeToGallery,
                            icon: const Icon(Icons.download, size: 24),
                            label: Text(
                              _isLoading
                                  ? 'Salvando...'
                                  : 'Salvar QR Code na Galeria',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimaryDarkBlue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(
                                color: kPrimaryDarkBlue,
                                width: 2,
                              ),
                              backgroundColor: Colors.white.withOpacity(0.9),
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
                      const SizedBox(height: 20), // Espaço no final
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
}
