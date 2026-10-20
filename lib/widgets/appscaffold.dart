// lib/widgets/app_scaffold.dart

import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  const AppScaffold({
    super.key,
    required this.body,
    required this.title,
    this.actions,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: actions,
      ),
      body: Column(
        children: [
          Expanded(child: body),
          const VersionFooter(), // 🔥 OTOMATİK EKLER!
        ],
      ),
    );
  }
}
