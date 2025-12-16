// ignore_for_file: avoid_print, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:wortis/class/CustomPageTransition.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/class/dataprovider.dart';
import 'package:wortis/class/form_service.dart';
import 'package:wortis/class/catalog_service.dart';
import 'package:wortis/class/icon_utils.dart';
import 'package:wortis/class/webviews.dart';
import 'package:wortis/pages/connexion/gestionCompte.dart';
import 'package:wortis/pages/homepage.dart';
import 'package:provider/provider.dart';
import 'package:wortis/pages/homepage_dias.dart';

class AllServicesPage extends StatefulWidget {
  const AllServicesPage({super.key});

  @override
  _AllServicesPageState createState() => _AllServicesPageState();
}

class _AllServicesPageState extends State<AllServicesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _returnToHomePage() {
    // CORRECTION: Utiliser NavigationManager au lieu de HomePageManager
    final homeType = NavigationManager.getCurrentHomePage();

    if (homeType == 'HomePageDias') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePageDias()),
        (route) => false,
      );
    } else {
      // CORRECTION: Créer un routeObserver par défaut si nécessaire
      final routeObserver = RouteObserver<PageRoute>();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => HomePage(routeObserver: routeObserver)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => _returnToHomePage(),
        ),
        title: const Text(
          'Tous les services',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF006699),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // Utilisation de Consumer pour écouter les changements du Provider
        child: Consumer<AppDataProvider>(
          builder: (context, appDataProvider, child) {
            return ListView.builder(
              itemCount: appDataProvider.services.length,
              itemBuilder: (context, index) {
                final service = appDataProvider.services[index];
                final serviceName = service['name'];
                final serviceIcon = service['icon'];
                return buildServiceCard(serviceIcon, serviceName, (name) {
                  navigateToFormPage(context, name);
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget buildServiceCard(
      String iconName, String label, void Function(String) onTapService) {
    final appDataProvider =
        Provider.of<AppDataProvider>(context, listen: false);
    final service = appDataProvider.services.firstWhere(
      (s) => s['name'] == label,
      orElse: () => {'status': true},
    );
    final bool isActive = service['status'] ?? true;
    final cardOpacity = isActive ? 1.0 : 0.5;
    final bool hasLogo =
        service['logo'] != null && service['logo'].toString().isNotEmpty;

    return Opacity(
      opacity: cardOpacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: ListTile(
          onTap: isActive ? () => onTapService(label) : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          leading: Container(
            width: 52, // Taille fixe pour garantir la cohérence
            height: 52,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF006699).withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF006699).withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: hasLogo
                ? Image.network(
                    Uri.encodeFull(service['logo']),
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;

                      // Animation de pulsation subtile pendant le chargement
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.6, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOut,
                        builder: (context, value, _) {
                          return Opacity(
                            opacity: 0.7,
                            child: Icon(
                              IconUtils.getIconData(iconName),
                              size: 28 * value, // Effet subtil de pulsation
                              color: isActive
                                  ? const Color(0xFF006699).withOpacity(value)
                                  : Colors.grey.withOpacity(value),
                            ),
                          );
                        },
                        // Répéter l'animation
                        // ignore: unnecessary_null_comparison
                        onEnd: () {},
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback à l'icône en cas d'erreur de chargement du logo
                      return Icon(
                        IconUtils.getIconData(iconName),
                        size: 28,
                        color: isActive ? const Color(0xFF006699) : Colors.grey,
                      );
                    },
                  )
                : Icon(
                    IconUtils.getIconData(iconName),
                    size: 28,
                    color: isActive ? const Color(0xFF006699) : Colors.grey,
                  ),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isActive ? const Color(0xFF2C3E50) : Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          trailing: isActive
              ? const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF006699),
                )
              : null,
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  void navigateToFormPage(BuildContext context, String serviceName) async {
    // Récupérer le service complet depuis le provider
    final appDataProvider =
        Provider.of<AppDataProvider>(context, listen: false);
    final service = appDataProvider.services.firstWhere(
      (s) => s['name'] == serviceName,
      orElse: () => {'Type_Service': '', 'link_view': ''},
    );

    // Debug: afficher les données du service
    print('🔍 [AllServices] Service: $serviceName');
    print('🔍 [AllServices] Type_Service: "${service['Type_Service']}"');
    print('🔍 [AllServices] Service complet: $service');

    if (!mounted || !context.mounted) return;

    try {
      if (service['Type_Service'] == "WebView") {
        print('➡️ [AllServices] Navigation vers WebView');
        print(service['link_view']); // Pour voir l'URL
        if (mounted && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceWebView(
                url: service['link_view'] ?? '',
              ),
            ),
          );
        }
      } else if (service['Type_Service'] == "Catalog") {
        print('➡️ [AllServices] Navigation vers CatalogService');
        if (mounted && context.mounted) {
          await SessionManager.checkSessionAndNavigate(
            context: context,
            authenticatedRoute: ServicePageTransition(
              page: CatalogService(serviceName: serviceName),
            ),
            unauthenticatedRoute: const AuthentificationPage(),
          );
        }
      } else {
        print('➡️ [AllServices] Navigation vers FormService (default)');
        if (mounted && context.mounted) {
          await SessionManager.checkSessionAndNavigate(
            context: context,
            authenticatedRoute: ServicePageTransition(
              page: FormService(serviceName: serviceName),
            ),
            unauthenticatedRoute: const AuthentificationPage(),
          );
        }
      }
    } catch (e) {
      print('❌ [AllServices] Erreur navigation: $e');
    }
  }
}
