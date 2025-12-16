// ignore_for_file: unused_field, unused_element, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/class/dataprovider.dart';
import 'package:wortis/class/download_recu_service.dart' as receipt_service;
import 'package:wortis/class/download_recu_service.dart';
import 'package:wortis/pages/connexion/gestionCompte.dart';
import 'package:wortis/pages/homepage.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wortis/pages/homepage_dias.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TransactionHistoryPage extends StatefulWidget {
  final String? sourcePageType; // 'homepage' ou 'homepage_dias'

  const TransactionHistoryPage({super.key, this.sourcePageType});

  @override
  _TransactionHistoryPageState createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage>
    with TickerProviderStateMixin {
  // Variables pour les transactions
  String _selectedFilter = 'Tout';
  final String _sortBy = 'date';
  bool _sortAscending = false;
  int _visibleTransactions = 10;
  final String statusSuccess = 'SUCCESSFUL';

  // États de chargement par section
  bool _isLoadingStats = true;
  bool _isLoadingChart = true;
  bool _isLoadingList = true;

  // Variables pour onglet famlink
  bool _isLoadingSubscriptions = true;
  bool _isLoadingFamlinkTransactions = true;
  List<dynamic> _subscriptions = [];
  List<dynamic> _famlinkTransactions = [];

  // Variables de scroll
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = true;
  double _scrollProgress = 0.0;

  // TabController
  late TabController _tabController;
  int _initialTabIndex = 0;

  @override
  void initState() {
    super.initState();

    // Déterminer l'onglet initial basé sur la page source
    _initialTabIndex = _getInitialTabIndex();

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _initialTabIndex,
    );

    // Initialisation avec gestion d'erreur
    _initializePageData();

    _scrollController.addListener(() {
      if (!mounted) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      setState(() {
        _scrollProgress = maxScroll > 0 ? currentScroll / maxScroll : 0;
        _showScrollIndicator = currentScroll < maxScroll - 100;
      });
    });
  }

  int _getInitialTabIndex() {
    if (widget.sourcePageType == 'homepage_dias') {
      return 1; // Onglet "Abonnements et transactions famlink"
    }
    return 0; // Onglet "Historique des Transactions" par défaut
  }

  Future<void> _initializePageData() async {
    try {
      await _checkAuth();
      await Future.wait([
        _loadDataProgressively(),
        _loadFamlinkData(),
      ]).timeout(const Duration(seconds: 60));
    } catch (e) {
      print('❌ [InitializePageData] Erreur lors de l\'initialisation: $e');

      // S'assurer que tous les loading states sont remis à false
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          _isLoadingChart = false;
          _isLoadingList = false;
          _isLoadingSubscriptions = false;
          _isLoadingFamlinkTransactions = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Appel direct à l'API pour récupérer les abonnements
  Future<void> _loadSubscriptions() async {
    try {
      final userId = await SessionManager.getToken();

      if (userId == null) {
        print('🚫 [Subscriptions] User Token non trouvé');
        setState(() {
          _subscriptions = [];
          _isLoadingSubscriptions = false;
        });
        return;
      }

      print('📡 [Subscriptions] Chargement pour userId: $userId');

      final response = await http.get(
        Uri.parse(
            'https://api.live.wortis.cg/famlink/api/subscriptions/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      print('📋 [Subscriptions] Statut réponse: ${response.statusCode}');
      print('📄 [Subscriptions] Body complet: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('✅ [Subscriptions] Données parseés: $jsonData');

        List<dynamic> subscriptionsList = [];

        // Gérer les différentes structures possibles
        if (jsonData is Map && jsonData.containsKey('subscriptions')) {
          // Structure: {"subscriptions": [...]}
          subscriptionsList = jsonData['subscriptions'] as List? ?? [];
          print(
              '📦 [Subscriptions] Structure avec clé subscriptions: ${subscriptionsList.length} items');
        } else if (jsonData is List) {
          // Structure: [...]
          subscriptionsList = jsonData;
          print(
              '📦 [Subscriptions] Structure liste directe: ${subscriptionsList.length} items');
        } else if (jsonData is Map) {
          // Structure: {...} (un seul objet)
          subscriptionsList = [jsonData];
          print('📦 [Subscriptions] Structure objet unique: 1 item');
        }

        print(
            '🔍 [Subscriptions] Subscriptions trouvées: ${subscriptionsList.length}');
        for (int i = 0; i < subscriptionsList.length; i++) {
          final sub = subscriptionsList[i];
          print(
              '   - $i: status=${sub['status']}, service=${sub['service']?['name']}, plan=${sub['plan_name']}');
        }

        setState(() {
          _subscriptions = subscriptionsList;
          _isLoadingSubscriptions = false;
        });
      } else {
        print('❌ [Subscriptions] Erreur HTTP: ${response.statusCode}');
        setState(() {
          _subscriptions = [];
          _isLoadingSubscriptions = false;
        });
      }
    } catch (e) {
      print('❌ [Subscriptions] Erreur: $e');
      setState(() {
        _subscriptions = [];
        _isLoadingSubscriptions = false;
      });
    }
  }

  // Appel direct à l'API pour récupérer les transactions famlink
  Future<void> _loadFamlinkTransactions() async {
    try {
      final userId = await SessionManager.getToken();

      if (userId == null) {
        print('🚫 [FamlinkTransactions] User Token non trouvé');
        setState(() {
          _famlinkTransactions = [];
          _isLoadingFamlinkTransactions = false;
        });
        return;
      }

      print('📡 [FamlinkTransactions] Chargement pour userId: $userId');

      final response = await http.get(
        Uri.parse(
            'https://api.live.wortis.cg/famlink/api/$userId/transactions'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      print('📋 [FamlinkTransactions] Statut réponse: ${response.statusCode}');
      print('📄 [FamlinkTransactions] Body complet: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('✅ [FamlinkTransactions] Données parseés: $jsonData');

        List<dynamic> transactionsList = [];

        // Gérer la structure avec pagination et transactions
        if (jsonData is Map && jsonData.containsKey('transactions')) {
          // Structure: {"pagination": {...}, "transactions": [...]}
          transactionsList = jsonData['transactions'] as List? ?? [];
          print(
              '📦 [FamlinkTransactions] Structure avec clé transactions: ${transactionsList.length} items');

          // Logs de pagination si disponible
          if (jsonData.containsKey('pagination')) {
            final pagination = jsonData['pagination'];
            print(
                '📄 [FamlinkTransactions] Pagination: page ${pagination['page']}/${pagination['pages']}, total: ${pagination['total']}');
          }
        } else if (jsonData is List) {
          // Structure: [...]
          transactionsList = jsonData;
          print(
              '📦 [FamlinkTransactions] Structure liste directe: ${transactionsList.length} items');
        } else if (jsonData is Map) {
          // Structure: {...} (un seul objet)
          transactionsList = [jsonData];
          print('📦 [FamlinkTransactions] Structure objet unique: 1 item');
        }

        print(
            '🔍 [FamlinkTransactions] Transactions trouvées: ${transactionsList.length}');
        for (int i = 0; i < transactionsList.length; i++) {
          final trans = transactionsList[i];
          print(
              '   - $i: status=${trans['status']}, amount=${trans['amount']} ${trans['currency']}, transCbID=${trans['transCbID']}');
        }

        setState(() {
          _famlinkTransactions = transactionsList;
          _isLoadingFamlinkTransactions = false;
        });
      } else {
        print('❌ [FamlinkTransactions] Erreur HTTP: ${response.statusCode}');
        setState(() {
          _famlinkTransactions = [];
          _isLoadingFamlinkTransactions = false;
        });
      }
    } catch (e) {
      print('❌ [FamlinkTransactions] Erreur: $e');
      setState(() {
        _famlinkTransactions = [];
        _isLoadingFamlinkTransactions = false;
      });
    }
  }

  Future<void> _loadFamlinkData() async {
    print('🔄 [FamlinkData] Début du chargement...');

    try {
      await Future.wait([
        _loadSubscriptions(),
        _loadFamlinkTransactions(),
      ]).timeout(const Duration(seconds: 30));

      print('✅ [FamlinkData] Chargement terminé avec succès');
    } catch (e) {
      print('❌ [FamlinkData] Erreur générale: $e');

      // S'assurer que les états de chargement sont mis à false en cas d'erreur
      if (mounted) {
        setState(() {
          _isLoadingSubscriptions = false;
          _isLoadingFamlinkTransactions = false;
          _subscriptions = [];
          _famlinkTransactions = [];
        });
      }
    }
  }

  int _getColumnCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 2;
  }

  void _returnToHomePage() {
    final homeType = NavigationManager.getCurrentHomePage();

    if (homeType == 'HomePageDias') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePageDias()),
        (route) => false,
      );
    } else {
      final routeObserver = RouteObserver<PageRoute>();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => HomePage(routeObserver: routeObserver)),
        (route) => false,
      );
    }
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historique',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 18 : 22,
            ),
          ),
          if (!isSmallScreen)
            Text(
              'Gérez vos transactions et abonnements',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      backgroundColor: const Color(0xFF006699),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: _returnToHomePage,
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Historique des Transactions'),
          Tab(text: 'Abonnements Famlink'),
        ],
      ),
    );
  }

  // Méthodes existantes pour l'onglet historique des transactions
  Future<void> _loadDataProgressively() async {
    if (!mounted) return;

    if (mounted) setState(() => _isLoadingStats = true);
    await Provider.of<AppDataProvider>(context, listen: false)
        .loadTransactionsIfNeeded();
    if (mounted) setState(() => _isLoadingStats = false);

    if (mounted) setState(() => _isLoadingChart = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _isLoadingChart = false);

    if (mounted) setState(() => _isLoadingList = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _isLoadingList = false);
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    print('🔄 [RefreshData] Début du rafraîchissement...');

    if (mounted) {
      setState(() {
        _isLoadingStats = true;
        _isLoadingChart = true;
        _isLoadingList = true;
        _isLoadingSubscriptions = true;
        _isLoadingFamlinkTransactions = true;
      });
    }

    try {
      await Future.wait([
        _loadDataProgressively(),
        _loadFamlinkData(),
      ]).timeout(const Duration(seconds: 45));

      print('✅ [RefreshData] Rafraîchissement terminé avec succès');
    } catch (e) {
      print('❌ [RefreshData] Erreur générale: $e');

      // S'assurer que tous les états de chargement sont remis à false
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          _isLoadingChart = false;
          _isLoadingList = false;
          _isLoadingSubscriptions = false;
          _isLoadingFamlinkTransactions = false;
        });
      }
    }
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;

    final token = await SessionManager.getToken();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthentificationPage()),
        (route) => false,
      );
      return;
    }
  }

  // Getters pour les statistiques
  int get _totalTransactions =>
      Provider.of<AppDataProvider>(context, listen: false).transactions.length;

  int get _successfulTransactions =>
      Provider.of<AppDataProvider>(context, listen: false)
          .transactions
          .where((t) => t.status == statusSuccess)
          .length;

  int get _failedTransactions =>
      Provider.of<AppDataProvider>(context, listen: false)
          .transactions
          .where((t) => t.status == 'FAILED')
          .length;

  int get _momoTransactions =>
      Provider.of<AppDataProvider>(context, listen: false)
          .transactions
          .where((t) => t.typeTransaction == 'momo')
          .length;

  int get _cardTransactions =>
      Provider.of<AppDataProvider>(context, listen: false)
          .transactions
          .where((t) => t.typeTransaction == 'carte')
          .length;

  double get _totalSpent => Provider.of<AppDataProvider>(context, listen: false)
      .transactions
      .where((t) => t.status == 'SUCCESSFUL')
      .fold(0, (sum, t) => sum + t.getAmount());

  List<Transaction> get _filteredAndSortedTransactions {
    final provider = Provider.of<AppDataProvider>(context, listen: false);
    List<Transaction> result = List.from(provider.transactions);

    // Filtrage
    if (_selectedFilter != 'Tout') {
      if (_selectedFilter == 'momo') {
        result = result.where((t) => t.typeTransaction == 'momo').toList();
      } else if (_selectedFilter == 'carte') {
        result = result.where((t) => t.typeTransaction == 'carte').toList();
      } else if (_selectedFilter == statusSuccess) {
        result = result.where((t) => t.status == 'SUCCESSFUL').toList();
      } else if (_selectedFilter == 'FAILED') {
        result = result.where((t) => t.status == 'FAILED').toList();
      }
    }

    // Tri
    result.sort((a, b) {
      if (_sortBy == 'date') {
        return _sortAscending
            ? a.createdAt.compareTo(b.createdAt)
            : b.createdAt.compareTo(a.createdAt);
      } else {
        return _sortAscending
            ? a.getAmount().compareTo(b.getAmount())
            : b.getAmount().compareTo(a.getAmount());
      }
    });

    return result;
  }

  // Widget de chargement
  Widget _buildLoadingSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Container(
          margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
          padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF006699).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.7,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF006699),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 30 : 40),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: isSmallScreen ? 40 : 50,
                    height: isSmallScreen ? 40 : 50,
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF006699)),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 20 : 30),
                  Text(
                    'Chargement en cours...',
                    style: TextStyle(
                      color: const Color(0xFF006699),
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 10),
                  Text(
                    'Veuillez patienter...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isSmallScreen ? 13 : 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 30 : 40),
            ],
          ),
        );
      },
    );
  }

  // Widget pour afficher les statistiques
  Widget _buildResponsiveStatistics() {
    final formatCurrency = NumberFormat.currency(
      symbol: '',
      decimalDigits: 0,
      locale: 'fr_FR',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = _getColumnCount(context);
        final cardAspectRatio = constraints.maxWidth > 600 ? 1.5 : 1.3;
        final isSmallScreen = constraints.maxWidth < 600;

        return Container(
          margin: EdgeInsets.fromLTRB(16, 0, 16, isSmallScreen ? 8 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      color: const Color(0xFF006699),
                      size: isSmallScreen ? 20 : 24,
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Text(
                      'Aperçu des transactions',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
              GridView.count(
                crossAxisCount: columnCount,
                childAspectRatio: cardAspectRatio,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: isSmallScreen ? 12 : 16,
                crossAxisSpacing: isSmallScreen ? 12 : 16,
                children: [
                  _buildStatCard(
                    icon: Icons.receipt_long_rounded,
                    title: 'Total',
                    value: '$_totalTransactions',
                    color: const Color(0xFF006699),
                    isSmallScreen: isSmallScreen,
                  ),
                  _buildStatCard(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Réussies',
                    value: '$_successfulTransactions',
                    color: Colors.green,
                    isSmallScreen: isSmallScreen,
                  ),
                  _buildStatCard(
                    icon: Icons.error_outline_rounded,
                    title: 'Échouées',
                    value: '$_failedTransactions',
                    color: Colors.red,
                    isSmallScreen: isSmallScreen,
                  ),
                  _buildStatCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Total dépensé',
                    value: '${formatCurrency.format(_totalSpent)} FCFA',
                    color: const Color(0xFF006699),
                    isSmallScreen: isSmallScreen,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour le graphique en secteurs
  Widget _buildResponsivePieChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Container(
          margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.pie_chart_rounded,
                    color: const Color(0xFF006699),
                    size: isSmallScreen ? 20 : 24,
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Text(
                    'Répartition par type',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
              SizedBox(
                height: isSmallScreen ? 200 : 250,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              color: const Color(0xFF006699),
                              value: _momoTransactions.toDouble(),
                              title: '$_momoTransactions',
                              radius: isSmallScreen ? 50 : 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              color: Colors.orange,
                              value: _cardTransactions.toDouble(),
                              title: '$_cardTransactions',
                              radius: isSmallScreen ? 50 : 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: isSmallScreen ? 30 : 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem(
                            color: const Color(0xFF006699),
                            label: 'Mobile Money',
                            count: _momoTransactions,
                            isSmallScreen: isSmallScreen,
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          _buildLegendItem(
                            color: Colors.orange,
                            label: 'Carte bancaire',
                            count: _cardTransactions,
                            isSmallScreen: isSmallScreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required int count,
    required bool isSmallScreen,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: isSmallScreen ? 6 : 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget pour afficher les transactions
  Widget _buildTransactionsList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final filteredTransactions = _filteredAndSortedTransactions;
        final isSmallScreen = constraints.maxWidth < 600;

        return Container(
          margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                child: Column(
                  children: [
                    // En-tête et filtres
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              color: const Color(0xFF006699),
                              size: isSmallScreen ? 20 : 24,
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            Text(
                              'Historique',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF006699).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${filteredTransactions.length} Paiements',
                            style: const TextStyle(
                              color: Color(0xFF006699),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    // Filtres
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                isExpanded: true,
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                items: [
                                  'Tout',
                                  'momo',
                                  'carte',
                                  statusSuccess,
                                  'FAILED'
                                ].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value == statusSuccess
                                          ? 'Réussies'
                                          : value == 'FAILED'
                                              ? 'Échouées'
                                              : value == 'momo'
                                                  ? 'Mobile Money'
                                                  : value == 'carte'
                                                      ? 'Carte bancaire'
                                                      : value,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedFilter = newValue!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _sortAscending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: const Color(0xFF006699),
                            ),
                            onPressed: () {
                              setState(() {
                                _sortAscending = !_sortAscending;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Liste des transactions
              if (filteredTransactions.isEmpty)
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 40 : 60),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: isSmallScreen ? 48 : 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      Text(
                        'Aucune transaction trouvée',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      Text(
                        'Effectuez votre première transaction pour voir l\'historique ici.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredTransactions.length > _visibleTransactions
                      ? _visibleTransactions + 1
                      : filteredTransactions.length,
                  itemBuilder: (context, index) {
                    if (index == _visibleTransactions &&
                        filteredTransactions.length > _visibleTransactions) {
                      return _buildLoadMoreButton(isSmallScreen);
                    }
                    if (index < filteredTransactions.length) {
                      return _buildTransactionItem(
                          filteredTransactions[index], isSmallScreen);
                    }
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionItem(Transaction transaction, bool isSmallScreen) {
    final isSuccessful = transaction.status == 'SUCCESSFUL';
    final transactionDate = DateTime.parse(transaction.createdAt);
    final isCard = transaction.typeTransaction == 'carte';

    // ✅ MODIFICATION: Suppression désactivée - Widget Dismissible remplacé par Card
    return Card(
        margin: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 16,
          vertical: 8,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0.5,
        child: InkWell(
          onTap: () => _showTransactionDetails(transaction, isSmallScreen),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icône adaptée au type
                      Container(
                        width: isSmallScreen ? 40 : 48,
                        height: isSmallScreen ? 40 : 48,
                        decoration: BoxDecoration(
                          color: isCard
                              ? Colors.orange.withOpacity(0.1)
                              : const Color(0xFF006699).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isCard
                              ? Icons.credit_card_rounded
                              : Icons.phone_android_rounded,
                          color:
                              isCard ? Colors.orange : const Color(0xFF006699),
                          size: isSmallScreen ? 20 : 24,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.beneficiaire?.isNotEmpty == true
                                  ? transaction.beneficiaire!
                                  : 'Transaction ${transaction.clientTransID}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isSmallScreen ? 14 : 15,
                                color: const Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd/MM/yyyy à HH:mm')
                                  .format(transactionDate),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isSmallScreen ? 12 : 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSuccessful
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isSuccessful ? 'Réussie' : 'Échouée',
                                    style: TextStyle(
                                      color: isSuccessful
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCard
                                        ? Colors.orange.withOpacity(0.1)
                                        : const Color(0xFF006699)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isCard ? 'Carte' : 'MoMo',
                                    style: TextStyle(
                                      color: isCard
                                          ? Colors.orange
                                          : const Color(0xFF006699),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(transaction.getAmount())} FCFA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSuccessful ? Colors.green : Colors.red,
                        fontSize: isSmallScreen ? 14 : 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isSuccessful)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006699).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () => _downloadReceipt(transaction),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.download_rounded,
                                size: 14,
                                color: const Color(0xFF006699),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reçu',
                                style: TextStyle(
                                  color: const Color(0xFF006699),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildLoadMoreButton(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _visibleTransactions += 10),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Voir plus'),
        style: ElevatedButton.styleFrom(
          foregroundColor: const Color(0xFF006699),
          backgroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF006699), width: 1),
          ),
        ),
      ),
    );
  }

  // Widgets pour l'onglet Famlink

  // Widget pour les abonnements actifs
  Widget _buildActiveSubscriptions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final activeSubscriptions =
            _subscriptions.where((sub) => sub['status'] == 'active').toList();

        print(
            '🔍 [_buildActiveSubscriptions] Total subscriptions: ${_subscriptions.length}');
        print(
            '🔍 [_buildActiveSubscriptions] Active subscriptions: ${activeSubscriptions.length}');
        for (int i = 0; i < _subscriptions.length; i++) {
          final sub = _subscriptions[i];
          print(
              '   - Subscription $i: status="${sub['status']}", active=${sub['status'] == 'active'}');
        }

        return Container(
          margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.subscriptions_rounded,
                      color: const Color(0xFF006699),
                      size: isSmallScreen ? 20 : 24,
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Text(
                      'Mes services actifs (${activeSubscriptions.length})',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                if (activeSubscriptions.isEmpty)
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 40 : 60),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: isSmallScreen ? 48 : 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        Text(
                          'Aucun service actif',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        Text(
                          'Vous n\'avez pas encore de service actif.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (_subscriptions.isNotEmpty) ...[
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          Text(
                            'Debug: ${_subscriptions.length} subscription(s) trouvée(s) mais aucune active',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeSubscriptions.length,
                    itemBuilder: (context, index) {
                      print(
                          '🎨 [_buildActiveSubscriptions] Building card for subscription $index');
                      return _buildSubscriptionCard(
                          activeSubscriptions[index], isSmallScreen);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget pour les services en attente de paiement
  Widget _buildPendingSubscriptions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final pendingSubscriptions = _subscriptions
            .where((sub) =>
                    sub['status'] ==
                    'success' // Status 'success' = en attente de paiement selon vos instructions
                )
            .toList();

        print(
            '🔍 [_buildPendingSubscriptions] Pending subscriptions: ${pendingSubscriptions.length}');

        if (pendingSubscriptions.isEmpty) {
          return const SizedBox
              .shrink(); // Ne pas afficher la section si pas de services en attente
        }

        return Container(
          margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.pending_actions_rounded,
                      color: Colors.orange,
                      size: isSmallScreen ? 20 : 24,
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Text(
                      'Services en attente de paiement (${pendingSubscriptions.length})',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Text(
                  'Ces services nécessitent un paiement pour être activés.',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingSubscriptions.length,
                  itemBuilder: (context, index) {
                    return _buildPendingSubscriptionCard(
                        pendingSubscriptions[index], isSmallScreen);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionCard(dynamic subscription, bool isSmallScreen) {
    print(
        '🎨 [_buildSubscriptionCard] Building card for subscription: ${subscription['_subscriptions']}');

    final serviceName = subscription['service']?['name'] ?? 'Service';
    final planName = subscription['plan_name'] ?? 'Plan';
    final monthlyAmount = subscription['monthly_amount'] ?? 0;
    final nextBilling = subscription['next_billing_date'];
    final logoUrl = subscription['service']?['logo_url'];
    final serviceIcon = subscription['service']?['icon'] ?? '📡';

    print('🔍 [_buildSubscriptionCard] serviceName: $serviceName');
    print('🔍 [_buildSubscriptionCard] planName: $planName');
    print('🔍 [_buildSubscriptionCard] monthlyAmount: $monthlyAmount');
    print('🔍 [_buildSubscriptionCard] logoUrl: $logoUrl');

    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Logo ou icône du service
                Container(
                  width: isSmallScreen ? 40 : 48,
                  height: isSmallScreen ? 40 : 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF006699).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: logoUrl != null && logoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            logoUrl,
                            width: isSmallScreen ? 40 : 48,
                            height: isSmallScreen ? 40 : 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('❌ [Image] Erreur chargement logo: $error');
                              return Center(
                                child: Text(
                                  serviceIcon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            serviceIcon,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14 : 16,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        planName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Actif',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            // Détails de l'abonnement
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Montant mensuel',
                    '${monthlyAmount.toStringAsFixed(2)} €',
                    isSmallScreen,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    'Prochaine facturation',
                    _formatDate(nextBilling),
                    isSmallScreen,
                  ),
                ),
              ],
            ),
            if (subscription['start_date'] != null) ...[
              SizedBox(height: isSmallScreen ? 12 : 16),
              _buildDetailItem(
                'Date d\'activation',
                _formatDate(subscription['start_date']),
                isSmallScreen,
              ),
            ],
            if (subscription['installation_info']?['address'] != null) ...[
              SizedBox(height: isSmallScreen ? 12 : 16),
              _buildDetailItem(
                'Adresse',
                subscription['installation_info']['address'],
                isSmallScreen,
              ),
            ],
            SizedBox(height: isSmallScreen ? 16 : 20),
            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _manageService(subscription),
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Gérer'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF006699),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _suspendService(subscription['_subscriptions']),
                    icon: const Icon(Icons.pause, size: 16),
                    label: const Text('Suspendre'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSubscriptionCard(
      dynamic subscription, bool isSmallScreen) {
    print(
        '🎨 [_buildPendingSubscriptionCard] Building pending card for subscription: ${subscription['_subscriptions']}');

    final serviceName = subscription['service']?['name'] ?? 'Service';
    final planName = subscription['plan_name'] ?? 'Plan';
    final monthlyAmount = subscription['monthly_amount'] ?? 0;
    final logoUrl = subscription['service']?['logo_url'];
    final serviceIcon = subscription['service']?['icon'] ?? '📡';

    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Logo ou icône du service
                  Container(
                    width: isSmallScreen ? 40 : 48,
                    height: isSmallScreen ? 40 : 48,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: logoUrl != null && logoUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              logoUrl,
                              width: isSmallScreen ? 40 : 48,
                              height: isSmallScreen ? 40 : 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    serviceIcon,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Text(
                              serviceIcon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 14 : 16,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          planName,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'En attente',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              // Montant mensuel
              _buildDetailItem(
                'Montant mensuel',
                '${monthlyAmount.toStringAsFixed(2)} €',
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              // Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _managePendingService(subscription),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Gérer le paiement'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: isSmallScreen ? 11 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Widget pour l'historique des transactions famlink
  Widget _buildFamlinkTransactionsList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Container(
          margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: const Color(0xFF006699),
                      size: isSmallScreen ? 20 : 24,
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Text(
                      'Historique des transactions',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                if (_famlinkTransactions.isEmpty)
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 40 : 60),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: isSmallScreen ? 48 : 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        Text(
                          'Aucune transaction trouvée',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        Text(
                          'Les transactions de vos abonnements apparaîtront ici.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Colors.grey[50],
                      ),
                      columns: const [
                        DataColumn(label: Text('Numéro')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Montant')),
                        DataColumn(label: Text('Statut')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: _famlinkTransactions.map<DataRow>((transaction) {
                        return DataRow(
                          cells: [
                            DataCell(Text(transaction['transCbID'] ?? 'N/A')),
                            DataCell(
                                Text(_formatDate(transaction['created_at']))),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  transaction['description'] ?? 'N/A',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(Text(
                                '${transaction['amount']?.toStringAsFixed(2) ?? '0.00'} ${transaction['currency'] ?? 'EUR'}')),
                            DataCell(_buildStatusBadge(transaction['status'])),
                            DataCell(
                              TextButton.icon(
                                onPressed: () => _downloadInvoice(
                                    transaction['_transactions']),
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('Télécharger'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF006699),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String? status) {
    final isSuccessful = status == 'completed';
    final statusText = isSuccessful
        ? 'Réussie'
        : (status == 'failed' ? 'Échouée' : status ?? 'Inconnu');
    final statusColor = isSuccessful
        ? Colors.green
        : (status == 'failed' ? Colors.red : Colors.orange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Méthodes utilitaires
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  // Actions pour les transactions (onglet historique)
  void _showTransactionDetails(Transaction transaction, bool isSmallScreen) {
    final isCard = transaction.typeTransaction == 'carte';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: isCard
                ? _buildCardTransactionDetails(transaction, isSmallScreen)
                : _buildMomoTransactionDetails(transaction, isSmallScreen),
          ),
        ),
      ),
    );
  }

  Widget _buildCardTransactionDetails(
      Transaction transaction, bool isSmallScreen) {
    final transactionDate = DateTime.parse(transaction.createdAt);
    final isSuccessful = transaction.status == 'SUCCESSFUL';
    final montantEur = transaction.tauxConversion != null
        ? transaction.getAmount() / transaction.tauxConversion!
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF28a745).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.credit_card,
                    color: Color(0xFF28a745),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'DÉTAILS TRANSACTION',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF28a745),
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDetailRow('Reference Transaction', transaction.clientTransID),
        if (transaction.typePaiement != null)
          _buildDetailRow('Type', transaction.typePaiement!),
        const Divider(height: 32),
        _buildDetailRow(
            '💰 Montant', '${transaction.getFormattedAmount()} XAF'),
        if (transaction.tauxConversion != null) ...[
          _buildDetailRow(
              '💱 Équivalent EUR',
              NumberFormat.currency(
                      symbol: '€', decimalDigits: 2, locale: 'fr_FR')
                  .format(montantEur)),
          _buildDetailRow('📊 Taux conversion',
              '${transaction.tauxConversion} XAF = 1 EUR'),
        ],
        const Divider(height: 32),
        _buildDetailRow('📅 Date',
            DateFormat('dd/MM/yyyy à HH:mm').format(transactionDate)),
        if (transaction.beneficiaire != null)
          _buildDetailRow('📞 Bénéficiaire', transaction.beneficiaire!),
        _buildDetailRow('✅ Statut', isSuccessful ? 'Réussi' : 'Échoué'),
        const SizedBox(height: 30),
        if (isSuccessful)
          Center(
            child: ElevatedButton.icon(
              onPressed: () => ReceiptDownloadService.downloadReceipt(
                context,
                transaction.liens,
                transaction.clientTransID,
              ),
              icon: const Icon(Icons.download),
              label: const Text('Télécharger le reçu'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF28a745),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMomoTransactionDetails(
      Transaction transaction, bool isSmallScreen) {
    final transactionDate = DateTime.parse(transaction.createdAt);
    final isSuccessful = transaction.status == 'SUCCESSFUL';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006699).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.smartphone,
                    color: Color(0xFF006699),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'DÉTAILS TRANSACTION',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF006699),
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDetailRow('Reference de transaction', transaction.clientTransID),
        const Divider(height: 32),
        _buildDetailRow(
            '💰 Montant', '${transaction.getFormattedAmount()} XAF'),
        const Divider(height: 32),
        _buildDetailRow('📅 Date',
            DateFormat('dd/MM/yyyy à HH:mm').format(transactionDate)),
        if (transaction.beneficiaire != null)
          _buildDetailRow('📞 Bénéficiaire', transaction.beneficiaire!),
        _buildDetailRow('✅ Statut', isSuccessful ? 'Réussi' : 'Échoué'),
        const SizedBox(height: 30),
        if (isSuccessful)
          Center(
            child: ElevatedButton.icon(
              onPressed: () => ReceiptDownloadService.downloadReceipt(
                context,
                transaction.liens,
                transaction.clientTransID,
              ),
              icon: const Icon(Icons.download),
              label: const Text('Télécharger le reçu'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF006699),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _downloadReceipt(Transaction transaction) async {
    await receipt_service.ReceiptDownloadService.downloadReceipt(
        context, transaction.liens, transaction.clientTransID);
  }

  // Actions pour les subscriptions
  void _manageService(dynamic subscription) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF006699),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: subscription['service']?['logo_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                subscription['service']['logo_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.subscriptions,
                                      color: Colors.white);
                                },
                              ),
                            )
                          : const Icon(Icons.subscriptions,
                              color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gestion de l\'abonnement',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            subscription['service']?['name'] ?? 'Service',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Contenu
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Informations de base
                      _buildSectionHeader('Informations générales'),
                      _buildInfoRow(
                          'Service', subscription['service']?['name'] ?? 'N/A'),
                      _buildInfoRow('Plan', subscription['plan_name'] ?? 'N/A'),
                      _buildInfoRow(
                          'Statut', _getStatusLabel(subscription['status'])),
                      _buildInfoRow('ID Abonnement',
                          subscription['_subscriptions'] ?? 'N/A'),

                      const SizedBox(height: 20),

                      // Informations financières
                      _buildSectionHeader('Informations financières'),
                      _buildInfoRow('Montant mensuel',
                          '${subscription['monthly_amount']?.toStringAsFixed(2) ?? '0.00'} €'),
                      _buildInfoRow('Frais d\'installation',
                          '${subscription['installation_fee']?.toStringAsFixed(2) ?? '0.00'} €'),
                      _buildInfoRow('Prochaine facturation',
                          _formatDate(subscription['next_billing_date'])),
                      _buildInfoRow(
                          'Paiement complété',
                          subscription['payment_completed'] == true
                              ? 'Oui'
                              : 'Non'),

                      const SizedBox(height: 20),

                      // Dates importantes
                      _buildSectionHeader('Dates importantes'),
                      _buildInfoRow('Date de création',
                          _formatDate(subscription['created_at'])),
                      _buildInfoRow('Date d\'activation',
                          _formatDate(subscription['start_date'])),
                      _buildInfoRow('Dernière mise à jour',
                          _formatDate(subscription['updated_at'])),

                      if (subscription['installation_info'] != null) ...[
                        const SizedBox(height: 20),
                        _buildSectionHeader('Informations d\'installation'),
                        ...subscription['installation_info']
                            .entries
                            .map<Widget>((entry) {
                          return _buildInfoRow(
                            _formatFieldName(entry.key),
                            entry.value?.toString() ?? 'N/A',
                          );
                        }).toList(),
                      ],

                      const SizedBox(height: 30),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _suspendService(subscription['_subscriptions']);
                              },
                              icon: const Icon(Icons.pause),
                              label: const Text('Suspendre'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                // Action pour modifier l'abonnement
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Modification en cours de développement')),
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Modifier'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006699),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF006699),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFieldName(String fieldName) {
    switch (fieldName) {
      case 'existing_installation':
        return 'Installation existante';
      case 'subscription_number':
        return 'Numéro d\'abonnement';
      case 'address':
        return 'Adresse';
      default:
        return fieldName
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'active':
        return 'Actif';
      case 'suspended':
        return 'Suspendu';
      case 'cancelled':
        return 'Annulé';
      case 'pending':
        return 'En attente';
      default:
        return status ?? 'Inconnu';
    }
  }

  void _managePendingService(dynamic subscription) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: subscription['service']?['logo_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                subscription['service']['logo_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.pending_actions,
                                      color: Colors.white);
                                },
                              ),
                            )
                          : const Icon(Icons.pending_actions,
                              color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service en attente de paiement',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            subscription['service']?['name'] ?? 'Service',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Contenu
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message d'information
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ce service a été créé mais nécessite un paiement pour être activé.',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Informations de base
                      _buildSectionHeader('Informations du service'),
                      _buildInfoRow(
                          'Service', subscription['service']?['name'] ?? 'N/A'),
                      _buildInfoRow('Plan', subscription['plan_name'] ?? 'N/A'),
                      _buildInfoRow('Statut', 'En attente de paiement'),
                      _buildInfoRow('ID Abonnement',
                          subscription['_subscriptions'] ?? 'N/A'),

                      const SizedBox(height: 20),

                      // Informations financières
                      _buildSectionHeader('Montant à payer'),
                      _buildInfoRow('Montant mensuel',
                          '${subscription['monthly_amount']?.toStringAsFixed(2) ?? '0.00'} €'),
                      _buildInfoRow('Frais d\'installation',
                          '${subscription['installation_fee']?.toStringAsFixed(2) ?? '0.00'} €'),

                      const SizedBox(height: 20),

                      // Dates
                      _buildSectionHeader('Informations temporelles'),
                      _buildInfoRow('Date de création',
                          _formatDate(subscription['created_at'])),
                      _buildInfoRow('Dernière mise à jour',
                          _formatDate(subscription['updated_at'])),

                      if (subscription['installation_info'] != null) ...[
                        const SizedBox(height: 20),
                        _buildSectionHeader('Informations d\'installation'),
                        ...subscription['installation_info']
                            .entries
                            .map<Widget>((entry) {
                          return _buildInfoRow(
                            _formatFieldName(entry.key),
                            entry.value?.toString() ?? 'N/A',
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _cancelPendingSubscription(
                              subscription['_subscriptions']);
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('Annuler'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _proceedToPayment(subscription);
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('Payer maintenant'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Actions pour les services en attente de paiement
  Future<void> _proceedToPayment(dynamic subscription) async {
    try {
      final userToken = await SessionManager.getToken();

      if (userToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token utilisateur manquant'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Construire l'URL pour wortis.fr/famlink_apk avec les paramètres nécessaires
      final serviceName = subscription['service']?['name'] ?? 'Service';
      final planName = subscription['plan_name'] ?? 'Plan';
      final serviceId = subscription['service_id'] ?? '';
      final planId = subscription['plan_id'] ?? '';
      final subscriptionId = subscription['_subscriptions'] ?? '';
      final monthlyAmount = subscription['monthly_amount'] ?? 0;
      final installationFee = subscription['installation_fee'] ?? 0;

      // Paramètres pour aller directement à la page de paiement
      final Map<String, String> params = {
        'token': userToken,
        'service': Uri.encodeComponent(serviceName),
        'service_id': serviceId,
        'plan_id': planId,
        'plan_name': Uri.encodeComponent(planName),
        'subscription_id': subscriptionId,
        'monthly_amount': monthlyAmount.toString(),
        'installation_fee': installationFee.toString(),
        'direct_payment':
            'true', // Paramètre pour indiquer qu'on va directement au paiement
        'source': 'mobile_app_pending',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      // Construire l'URL complète
      final baseUrl = 'https://wortis.fr/famlink_apk';
      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final fullUrl = '$baseUrl?$queryString';

      print('🌐 [Payment] Redirection vers: $fullUrl');
      print('📋 [Payment] Paramètres: $params');

      // Ouvrir dans une WebView (comme dans homepage_dias.dart)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebView(
            url: fullUrl,
            subscriptionData: subscription,
          ),
        ),
      );
    } catch (e) {
      print('❌ [Payment] Erreur: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'ouverture du paiement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelPendingSubscription(String subscriptionId) async {
    // Confirmation avant annulation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler l\'abonnement'),
        content: const Text(
            'Êtes-vous sûr de vouloir annuler cet abonnement ?\n\n'
            'Cette action est irréversible et l\'abonnement sera définitivement supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non, garder'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final userId = await SessionManager.getToken();

        if (userId == null) {
          throw Exception('User Token manquant');
        }

        final response = await http.post(
          Uri.parse(
              'https://api.live.wortis.cg/famlink/api/subscriptions/$subscriptionId/cancel/$userId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Abonnement annulé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          // Recharger les abonnements
          _loadSubscriptions();
        } else {
          throw Exception(
              'Erreur lors de l\'annulation: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ [Cancel] Erreur: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'annulation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _suspendService(String subscriptionId) async {
    // Confirmation avant suspension
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspendre le service'),
        content: const Text('Êtes-vous sûr de vouloir suspendre ce service ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Suspendre'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final userId = await SessionManager.getToken();

        final response = await http.post(
          Uri.parse(
              'https://api.live.wortis.cg/famlink/api/subscriptions/$subscriptionId/cancel/$userId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service suspendu avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadSubscriptions(); // Recharger les abonnements
        } else {
          throw Exception('Erreur lors de la suspension');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadInvoice(String transactionId) {
    // Implémentation pour télécharger la facture - placeholder pour maintenant
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Téléchargement de la facture: $transactionId')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppDataProvider>(
      builder: (context, provider, child) {
        final filteredTransactions = _filteredAndSortedTransactions;
        final isSmallScreen = MediaQuery.of(context).size.width < 600;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: _buildResponsiveAppBar(context),
          body: RefreshIndicator(
            color: const Color(0xFF006699),
            onRefresh: _refreshData,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Onglet 1: Historique des Transactions
                SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        if (_isLoadingStats)
                          _buildLoadingSection()
                        else
                          _buildResponsiveStatistics(),
                        if (_isLoadingChart)
                          _buildLoadingSection()
                        else
                          _buildResponsivePieChart(),
                        if (_isLoadingList)
                          _buildLoadingSection()
                        else
                          _buildTransactionsList(),
                      ],
                    ),
                  ),
                ),
                // Onglet 2: Abonnements et transactions famlink
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        if (_isLoadingSubscriptions)
                          _buildLoadingSection()
                        else
                          _buildActiveSubscriptions(),

                        // Section des services en attente de paiement
                        if (_isLoadingSubscriptions)
                          const SizedBox.shrink()
                        else
                          _buildPendingSubscriptions(),

                        if (_isLoadingFamlinkTransactions)
                          _buildLoadingSection()
                        else
                          _buildFamlinkTransactionsList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// WebView pour le paiement
class PaymentWebView extends StatefulWidget {
  final String url;
  final dynamic subscriptionData;

  const PaymentWebView({
    super.key,
    required this.url,
    required this.subscriptionData,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.orange.withOpacity(0.1),
        child: Column(
          children: [
            // Barre d'information
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paiement pour ${widget.subscriptionData['service']?['name'] ?? 'Service'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Plan: ${widget.subscriptionData['plan_name'] ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // WebView ou message de chargement
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.orange),
                        SizedBox(height: 20),
                        Text(
                          'Chargement de la page de paiement...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Vous allez être redirigé vers la page de paiement sécurisée.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
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
