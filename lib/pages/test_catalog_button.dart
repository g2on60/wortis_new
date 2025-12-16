// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:wortis/class/catalog_service.dart';

/// Widget temporaire pour tester le CatalogService
/// À utiliser uniquement en développement
class TestCatalogButton extends StatelessWidget {
  const TestCatalogButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CatalogService(
              serviceName: 'boutique_alimentaire',
            ),
          ),
        );
      },
      label: const Text('Test Catalog'),
      icon: const Icon(Icons.shopping_cart),
      backgroundColor: Colors.orange,
    );
  }
}
