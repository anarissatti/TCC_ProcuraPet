import 'package:flutter/material.dart';

class IndexPage extends StatelessWidget {
  const IndexPage ({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Procura-se um Pet',
      theme: ThemeData(
        // 🔵 Cor "semente" — mude aqui para trocar a paleta inteira do app
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 124, 158, 231)),
        useMaterial3: true,
        // 🎨 Estilização padrão de textos (você pode ajustar por tipo)
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontWeight: FontWeight.w800), // títulos grandes
          titleMedium: TextStyle(fontWeight: FontWeight.w700),  // botões / títulos médios
          bodyMedium: TextStyle(height: 1.35),                  // parágrafos
        ),
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; // atalhos para cores do tema

    return Scaffold(
      // 🟦 Cor de fundo da tela: altere aqui para usar a sua
      backgroundColor: const Color.fromARGB(255, 129, 153, 249), // um cinza-azulado bem claro
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // 🟣 TÍTULO — como estilizar
                // - style: define cor, tamanho, peso, altura entre linhas etc.
                // - textAlign: centraliza o texto
                Text(
                  'Procura-se\num Pet ✨',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 34,          // tamanho do título
                    fontWeight: FontWeight.w900, // peso (negrito forte)
                    color: Color(0xFF1B2B5B),    // cor do texto
                    height: 1.15,          // espaçamento entre as linhas
                    letterSpacing: 0.3,    // espaçamento entre letras
                  ),
                ),
                const SizedBox(height: 10),

                // 🟡 SUBTÍTULO — como estilizar
                // Dica: use uma cor cinza/azul suave e tamanho menor
                const Text(
                  'A procura do seu aumigo!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7A90), // cinza-azulado
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 28),

                // 🔷 BOTÃO DE LOGIN — estilize via styleFrom
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary, // cor do botão
                      foregroundColor: cs.onPrimary, // cor do texto/ícone
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'LOGIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 🔗 Link secundário — use TextButton para aparência "link"
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
                  ),
                  child: const Text('Create a new Account'),
                ),

                const SizedBox(height: 32),

                  Align(
                  alignment: Alignment.topCenter, // topo e centralizado
                  child: Image.asset(
                   'assets/imagens/logo.png',
                    height: 180,
                  ),
                  ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
