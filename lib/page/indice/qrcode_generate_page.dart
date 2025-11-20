import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // Para PictureRecorder

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart'; // Para RenderRepaintBoundary
import 'package:image_gallery_saver/image_gallery_saver.dart'; // NECESSÁRIO
import 'package:path_provider/path_provider.dart'; // NECESSÁRIO

// *******************************************************************
// URL BASE DO SEU FIREBASE HOSTING (CONFIRMADA: tcc-procurapet)
// Esta constante define a página web que o QR Code irá abrir.
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

  final Color azulFundo = const Color(0xFFBBD0FF);
  final Color azulEscuro = const Color(0xFF1B2B5B);
  final Color corBotao = const Color(0xFFE56E94);

  @override
  void dispose() {
    _petNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  // Função para salvar os dados no Firestore e obter o ID único
  Future<String?> _savePetDataToFirestore(Map<String, dynamic> petData) async {
    try {
      final db = FirebaseFirestore.instance;

      // Salva na coleção 'pets_qr_data' (confirmada por você)
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
    // Verifica se os campos obrigatórios estão preenchidos
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _qrDataUrl = '';
      _currentPetId = '';
    });

    try {
      // Tenta obter o ID do usuário logado (usado para autorização de edição/exclusão)
      // Se não estiver usando autenticação, será null.
      final String? userId = FirebaseAuth.instance.currentUser?.uid;

      final petData = {
        'petName': _petNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        // Se as condições estiverem vazias, salva a string padrão.
        'conditions': _conditionsController.text.trim().isEmpty
            ? 'Nenhuma informação adicional.'
            : _conditionsController.text.trim(),
        'userId': userId, // Adiciona o ID do Tutor
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 1. Salva os dados no Firestore e obtém o ID (Chave de Resgate)
      final petId = await _savePetDataToFirestore(petData);

      if (petId == null) return;

      // 2. Constrói a URL final AUTOMATICAMENTE
      // Usa a URL base do Hosting e anexa o ID como parâmetro (?id=ID)
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

  // ***************************************************************
  // 💾 FUNÇÃO ADICIONADA: Salvar o QR Code na Galeria de Imagens
  // ***************************************************************
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
      _isLoading = true; // Reutilizamos o indicador de loading
    });

    try {
      // 1. Captura o widget QrImageView como imagem
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // Define a resolução da imagem, maior valor, maior qualidade
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // 2. Salva a imagem em um arquivo temporário
      // Embora o image_gallery_saver aceite bytes,
      // salvar em um arquivo temporário pode ser útil em alguns cenários.
      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/procurapet_qr_${_currentPetId}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      // 3. Salva a imagem na galeria
      final result = await ImageGallerySaver.saveFile(file.path);

      // O resultado é um Map, verifica se 'isSuccess' é true ou se contém um caminho
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
  // ***************************************************************
  // FIM DA FUNÇÃO ADICIONADA
  // ***************************************************************

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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: azulEscuro),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: azulEscuro),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: corBotao, width: 2),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Este campo é obrigatório';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: azulFundo,
      appBar: AppBar(
        title: const Text(
          'Gerar Placa de Identificação',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: azulEscuro,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              Text(
                'Dados do Pet para a Placa de Identificação',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: azulEscuro,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              const Text(
                'Os dados serão salvos no banco de dados e o QR Code gerado irá abrir a página de resgate no seu site: https://tcc-procurapet.web.app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // Campos do Pet
              Text(
                'Informações do Pet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: corBotao,
                ),
              ),
              const Divider(color: Colors.black12, height: 10),
              _buildInputField(_petNameController, 'Nome do Pet', 'Ex: Rex'),

              // Campos do Tutor
              Text(
                'Informações do Tutor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: corBotao,
                ),
              ),
              const Divider(color: Colors.black12, height: 10),
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

              const SizedBox(height: 30),

              // Botão Gerar QR Code
              ElevatedButton.icon(
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
                    : const Icon(Icons.qr_code_2_rounded, size: 28),
                label: Text(
                  _isLoading
                      ? 'Salvando e Gerando...'
                      : 'Salvar Dados e Gerar QR Code',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: corBotao,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
              ),

              if (_qrDataUrl.isNotEmpty) ...[
                const SizedBox(height: 40),
                Text(
                  'QR Code da Placa (ID: $_currentPetId)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: azulEscuro,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Center(
                  // RepaintBoundary é NECESSÁRIO para capturar o widget como imagem
                  child: RepaintBoundary(
                    key: _qrKey, // Usa a chave global para a captura
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: corBotao, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _qrDataUrl, // Usa a URL pública final
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: azulEscuro,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: azulEscuro,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ***************************************************************
                // BOTÃO ADICIONADO: Salvar QR Code
                // ***************************************************************
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveQrCodeToGallery,
                  icon: Icon(Icons.download, size: 24),
                  label: Text(
                    _isLoading ? 'Salvando...' : 'Salvar QR Code na Galeria',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: corBotao,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: corBotao, width: 2),
                    ),
                  ),
                ),

                // ***************************************************************
                // FIM DO BOTÃO ADICIONADO
                // ***************************************************************
                const SizedBox(height: 20),

                const Text(
                  'O QR Code foi gerado com sucesso! Imprima e insira na coleira do seu pet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.green),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
