import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';
import 'core/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  GoRouter? router;

  @override
  void initState() {
    super.initState();
    app.bootstrap().then((_) {
      if (mounted) setState(() => router = buildRouter());
    }).catchError((_) {
      if (mounted) setState(() => router = buildRouter());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (router == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return SellerApp(router: router!);
  }
}
