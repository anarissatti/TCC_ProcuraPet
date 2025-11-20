import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'login_page.dart';
import 'cadastro_page.dart';
import 'home_page.dart';
import 'index_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/cadastro', builder: (_, __) => const CadastroPage()),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      GoRoute(path: '/index', builder: (_, __) => const IndexPage()),
    ],
  );
});
