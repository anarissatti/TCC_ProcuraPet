import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ajuste o caminho conforme sua estrutura de pastas
import 'package:tcc_procurapet/src/features/auth/presentation/pages/index_page.dart';

void main() {
  testWidgets('Renderiza IndexPage e encontra título e botão',
      (WidgetTester tester) async {
    // monta a tela dentro do ProviderScope e MaterialApp
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: IndexPage(),
        ),
      ),
    );

    // verifica se o título aparece
    expect(find.text('Procura-se\num Pet ✨'), findsOneWidget);

    // verifica se o subtítulo aparece
    expect(find.text('A procura do seu aumigo!'), findsOneWidget);

    // verifica se o botão de login aparece
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
