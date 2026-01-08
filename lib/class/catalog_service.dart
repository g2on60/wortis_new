// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wortis/class/class.dart';

// ========== MODÈLES DE DONNÉES ==========

class Product {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final String unit;
  final String? image;
  final int stock;
  final double discount;
  final bool featured;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.unit,
    this.image,
    required this.stock,
    this.discount = 0,
    this.featured = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String,
      image: json['image'] as String?,
      stock: json['stock'] as int,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      featured: json['featured'] as bool? ?? false,
    );
  }

  double get discountedPrice => price * (1 - discount / 100);
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.discountedPrice * quantity;
}

class Category {
  final String id;
  final String name;
  final String icon;
  final String color;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
    );
  }

  Color get colorValue =>
      Color(int.parse(color.substring(1, 7), radix: 16) + 0xFF000000);
}

class DeliveryOption {
  final String id;
  final String name;
  final String description;
  final double fee;
  final String estimatedTime;

  DeliveryOption({
    required this.id,
    required this.name,
    required this.description,
    required this.fee,
    required this.estimatedTime,
  });

  factory DeliveryOption.fromJson(Map<String, dynamic> json) {
    return DeliveryOption(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      fee: (json['fee'] as num).toDouble(),
      estimatedTime: json['estimated_time'] as String,
    );
  }
}

// ========== SERVICE CATALOG ==========

class CatalogService extends StatefulWidget {
  final String serviceName;

  const CatalogService({super.key, required this.serviceName});

  @override
  State<CatalogService> createState() => _CatalogServiceState();
}

class _CatalogServiceState extends State<CatalogService>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? catalogData;
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  List<Category> categories = [];
  List<DeliveryOption> deliveryOptions = [];
  Map<String, CartItem> cart = {};

  String? selectedCategory;
  bool isLoading = true;
  String searchQuery = '';
  late TabController _tabController;

  // Couleurs (alignées avec le thème de l'application)
  static const primaryColor = Color(0xFF006699);
  static const secondaryColor = Color(0xFF004466);
  static const accentColor = Color(0xFF0088CC);

  @override
  void initState() {
    super.initState();
    _loadCatalogData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogData() async {
    try {
      print(
        '📦 [CatalogService] Chargement du catalogue: ${widget.serviceName}',
      );

      // Récupérer le code pays
      final String countryCode = await ZoneBenefManager.getZoneBenef() ?? 'CG';
      print('📦 [CatalogService] Code pays: $countryCode');

      // Préparer les données de requête
      final Map<String, dynamic> requestData = {
        'service': widget.serviceName,
        'country_code': countryCode,
      };

      // Charger depuis l'API avec le bon endpoint
      final response = await http.post(
        Uri.parse('https://api.live.wortis.cg/service_test'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      print('📦 [CatalogService] Status code: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Erreur chargement: ${response.statusCode}');
      }

      print(
        '📦 [CatalogService] Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...',
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      // Extraire la structure 'service' si elle existe
      final data = responseData.containsKey('service')
          ? responseData['service'] as Map<String, dynamic>
          : responseData;

      print('📦 [CatalogService] Data keys: ${data.keys.toList()}');
      print(
        '📦 [CatalogService] Categories count: ${data['categories']?.length ?? 0}',
      );
      print(
        '📦 [CatalogService] Products count: ${data['products']?.length ?? 0}',
      );

      setState(() {
        catalogData = data;

        // Parser les catégories
        try {
          categories = (data['categories'] as List)
              .map((c) => Category.fromJson(c as Map<String, dynamic>))
              .toList();
          print('✅ [CatalogService] Categories parsed: ${categories.length}');
        } catch (e) {
          print('❌ [CatalogService] Erreur parsing categories: $e');
          throw Exception('Erreur parsing categories: $e');
        }

        // Parser les produits
        try {
          allProducts = (data['products'] as List)
              .map((p) => Product.fromJson(p as Map<String, dynamic>))
              .toList();
          print('✅ [CatalogService] Products parsed: ${allProducts.length}');
        } catch (e) {
          print('❌ [CatalogService] Erreur parsing products: $e');
          throw Exception('Erreur parsing products: $e');
        }

        filteredProducts = allProducts;

        // Parser les options de livraison
        try {
          deliveryOptions = (data['delivery_options'] as List)
              .map((d) => DeliveryOption.fromJson(d as Map<String, dynamic>))
              .toList();
          print(
            '✅ [CatalogService] Delivery options parsed: ${deliveryOptions.length}',
          );
        } catch (e) {
          print('❌ [CatalogService] Erreur parsing delivery_options: $e');
          throw Exception('Erreur parsing delivery_options: $e');
        }

        isLoading = false;

        // Initialiser TabController
        _tabController = TabController(
          length: categories.length + 1,
          vsync: this,
        );
        _tabController.addListener(_handleTabChange);

        print('✅ [CatalogService] Catalogue chargé avec succès!');
      });
    } catch (e, stackTrace) {
      print('❌ [CatalogService] Erreur complète: $e');
      print('❌ [CatalogService] Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur chargement catalogue: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        if (_tabController.index == 0) {
          selectedCategory = null;
          _filterProducts();
        } else {
          selectedCategory = categories[_tabController.index - 1].id;
          _filterProducts();
        }
      });
    }
  }

  void _filterProducts() {
    setState(() {
      filteredProducts = allProducts.where((product) {
        final matchesCategory =
            selectedCategory == null || product.category == selectedCategory;
        final matchesSearch =
            searchQuery.isEmpty ||
            product.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            product.description.toLowerCase().contains(
              searchQuery.toLowerCase(),
            );

        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  void _addToCart(Product product) {
    setState(() {
      if (cart.containsKey(product.id)) {
        cart[product.id]!.quantity++;
      } else {
        cart[product.id] = CartItem(product: product, quantity: 1);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} ajouté au panier'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeFromCart(String productId) {
    setState(() {
      if (cart.containsKey(productId)) {
        if (cart[productId]!.quantity > 1) {
          cart[productId]!.quantity--;
        } else {
          cart.remove(productId);
        }
      }
    });
  }

  double get cartTotal {
    return cart.values.fold(0, (sum, item) => sum + item.total);
  }

  int get cartItemCount {
    return cart.values.fold(0, (sum, item) => sum + item.quantity);
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCartSheet(),
    );
  }

  Widget _buildCartSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle avec design moderne
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Header avec gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.1), Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shopping_bag, color: primaryColor, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Mon Panier',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
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
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$cartItemCount ${cartItemCount > 1 ? 'articles' : 'article'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Liste des produits
              Expanded(
                child: cart.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Votre panier est vide',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ajoutez des produits pour commencer',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          final item = cart.values.elementAt(index);
                          return _buildCartItem(item);
                        },
                      ),
              ),

              // Footer avec total et bouton
              if (cart.isNotEmpty) _buildCartFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartItem(CartItem item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final imageSize = isSmallScreen ? 60.0 : 70.0;
        final padding = isSmallScreen ? 10.0 : 14.0;
        final fontSize = isSmallScreen ? 14.0 : 15.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image avec style moderne
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.product.image != null
                      ? Image.network(
                          item.product.image!,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: imageSize,
                            height: imageSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.grey[200]!, Colors.grey[300]!],
                              ),
                            ),
                            child: Icon(
                              Icons.image,
                              color: Colors.grey[400],
                              size: imageSize * 0.5,
                            ),
                          ),
                        )
                      : Container(
                          width: imageSize,
                          height: imageSize,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(0.1),
                                primaryColor.withOpacity(0.2),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.shopping_bag,
                            color: primaryColor.withOpacity(0.5),
                            size: imageSize * 0.5,
                          ),
                        ),
                ),
              ),

              SizedBox(width: isSmallScreen ? 10 : 14),

              // Info produit
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize,
                        color: const Color(0xFF2D3436),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Text(
                      '${item.product.discountedPrice.toStringAsFixed(0)} ${catalogData!['currency']} / ${item.product.unit}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isSmallScreen ? 12 : 13,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Contrôles de quantité
                    Container(
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _removeFromCart(item.product.id),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.remove,
                                color: primaryColor,
                                size: 18,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _addToCart(item.product),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.add,
                                color: primaryColor,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: isSmallScreen ? 6 : 8),

              // Prix total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.total.toStringAsFixed(0),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 15 : 17,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    catalogData!['currency'],
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartFooter() {
    final deliveryFee = catalogData!['delivery_fee'] as num;
    final total = cartTotal + deliveryFee.toDouble();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Récapitulatif des prix
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sous-total',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      '${cartTotal.toStringAsFixed(0)} ${catalogData!['currency']}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Livraison',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${deliveryFee.toStringAsFixed(0)} ${catalogData!['currency']}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    Text(
                      '${total.toStringAsFixed(0)} ${catalogData!['currency']}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Bouton Commander avec gradient
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _goToCheckout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: primaryColor.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'Passer la commande',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToCheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          cart: cart,
          catalogData: catalogData!,
          deliveryOptions: deliveryOptions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.serviceName),
          backgroundColor: primaryColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (catalogData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.serviceName),
          backgroundColor: primaryColor,
        ),
        body: const Center(child: Text('Erreur de chargement du catalogue')),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, secondaryColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar personnalisée
              _buildCustomAppBar(),

              // Contenu principal
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Barre de recherche améliorée
                      _buildSearchBar(),

                      const SizedBox(height: 16),

                      // Tabs catégories améliorées
                      _buildCategoryTabs(),

                      const SizedBox(height: 16),

                      // Grille de produits
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: List.generate(
                            categories.length + 1,
                            (index) => _buildProductGrid(),
                          ),
                        ),
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

  // AppBar personnalisée avec gradient
  Widget _buildCustomAppBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tailles responsive
        final isSmallScreen = constraints.maxWidth < 600;
        final titleFontSize = isSmallScreen ? 18.0 : 22.0;
        final subtitleFontSize = isSmallScreen ? 12.0 : 14.0;
        final horizontalPadding = isSmallScreen ? 12.0 : 20.0;
        final spacing = isSmallScreen ? 8.0 : 16.0;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: Row(
            children: [
              // Bouton retour
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  iconSize: isSmallScreen ? 20 : 24,
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              SizedBox(width: spacing),

              // Titre
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalogData!['title'] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isSmallScreen ||
                        allProducts.length <
                            100) // Masquer sur petit écran si beaucoup de produits
                      Text(
                        '${allProducts.length} produit${allProducts.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: subtitleFontSize,
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(width: spacing),

              // Panier
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.shopping_cart,
                        color: Colors.white,
                      ),
                      iconSize: isSmallScreen ? 20 : 24,
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                      constraints: const BoxConstraints(),
                      onPressed: _showCart,
                    ),
                  ),
                  if (cartItemCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: BoxConstraints(
                          minWidth: isSmallScreen ? 18 : 20,
                          minHeight: isSmallScreen ? 18 : 20,
                        ),
                        child: Text(
                          cartItemCount > 99 ? '99+' : '$cartItemCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 9 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Barre de recherche améliorée
  Widget _buildSearchBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final horizontalPadding = isSmallScreen ? 12.0 : 20.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: isSmallScreen ? 14 : 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                  size: isSmallScreen ? 20 : 24,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[600],
                          size: isSmallScreen ? 20 : 24,
                        ),
                        onPressed: () {
                          setState(() {
                            searchQuery = '';
                            _filterProducts();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 20,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  _filterProducts();
                });
              },
            ),
          ),
        );
      },
    );
  }

  // Tabs catégories améliorées
  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 50,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: primaryColor,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        tabs: [
          Tab(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: const Text('Tout'),
            ),
          ),
          ...categories.map(
            (cat) => Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(cat.name),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 60,
                color: primaryColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun produit trouvé',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez une autre recherche',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcul responsive du nombre de colonnes
        int crossAxisCount;
        double childAspectRatio;

        if (constraints.maxWidth > 1200) {
          // Très grand écran (tablette landscape, desktop)
          crossAxisCount = 4;
          childAspectRatio = 0.85;
        } else if (constraints.maxWidth > 800) {
          // Tablette
          crossAxisCount = 3;
          childAspectRatio = 0.82;
        } else if (constraints.maxWidth > 600) {
          // Grand téléphone / petite tablette
          crossAxisCount = 2;
          childAspectRatio = 0.82;
        } else {
          // Petit téléphone
          crossAxisCount = 2;
          childAspectRatio = 0.78; // Ajusté pour minimiser l'espace vide en bas
        }

        return GridView.builder(
          padding: EdgeInsets.all(constraints.maxWidth > 600 ? 16 : 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: constraints.maxWidth > 600 ? 16 : 10,
            mainAxisSpacing: constraints.maxWidth > 600 ? 16 : 10,
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            return _buildProductCard(filteredProducts[index]);
          },
        );
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final isInCart = cart.containsKey(product.id);
    final quantity = isInCart ? cart[product.id]!.quantity : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Hauteur d'image responsive basée sur la largeur de la carte
        final imageHeight =
            constraints.maxWidth *
            0.50; // 50% de la largeur pour éviter overflow
        final iconSize =
            constraints.maxWidth * 0.25; // Taille de l'icône proportionnelle

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image avec badge promo
              Stack(
                children: [
                  GestureDetector(
                    onTap: product.image != null
                        ? () => _showImageDialog(product.image!, product.name)
                        : null,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: product.image != null
                          ? Image.network(
                              product.image!,
                              height: imageHeight,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                height: imageHeight,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.grey[200]!,
                                      Colors.grey[300]!,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.image,
                                  size: iconSize.clamp(30.0, 50.0),
                                  color: Colors.grey[400],
                                ),
                              ),
                            )
                          : Container(
                              height: imageHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    primaryColor.withOpacity(0.1),
                                    primaryColor.withOpacity(0.2),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.shopping_bag,
                                size: iconSize.clamp(30.0, 50.0),
                                color: primaryColor.withOpacity(0.5),
                              ),
                            ),
                    ),
                  ),
                  if (product.discount > 0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '-${product.discount.toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (product.featured)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Populaire',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Info produit
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF2D3436),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Prix
                    Row(
                      children: [
                        if (product.discount > 0) ...[
                          Text(
                            product.price.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 2),
                        ],
                        Flexible(
                          child: Text(
                            '${product.discountedPrice.toStringAsFixed(0)} ${catalogData!['currency']}',
                            style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'par ${product.unit}',
                      style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),

                    // Bouton ajouter
                    SizedBox(
                      width: double.infinity,
                      child: isInCart
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor.withOpacity(0.1),
                                    primaryColor.withOpacity(0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  InkWell(
                                    onTap: () => _removeFromCart(product.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.remove,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$quantity',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: primaryColor,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _addToCart(product),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () => _addToCart(product),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_shopping_cart, size: 13),
                                  SizedBox(width: 3),
                                  Text(
                                    'Ajouter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
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

  // Méthode pour afficher l'image en plein écran avec zoom
  void _showImageDialog(String imageUrl, String productName) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              // Image zoomable
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                      maxWidth: MediaQuery.of(context).size.width * 0.95,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nom du produit
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            productName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Image
                        Flexible(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          color: primaryColor,
                                        ),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    padding: const EdgeInsets.all(40),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 60,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Impossible de charger l\'image',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bouton fermer
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========== PAGE CHECKOUT ==========

class CheckoutPage extends StatefulWidget {
  final Map<String, CartItem> cart;
  final Map<String, dynamic> catalogData;
  final List<DeliveryOption> deliveryOptions;

  const CheckoutPage({
    super.key,
    required this.cart,
    required this.catalogData,
    required this.deliveryOptions,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  // Couleurs (alignées avec le thème de l'application)
  static const primaryColor = Color(0xFF006699);
  static const secondaryColor = Color(0xFF004466);
  static const accentColor = Color(0xFF0088CC);

  DeliveryOption? selectedDelivery;
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedDelivery = widget.deliveryOptions.first;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get subtotal {
    return widget.cart.values.fold(0, (sum, item) => sum + item.total);
  }

  double get total => subtotal + (selectedDelivery?.fee ?? 0);

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      print('⚠️  [CATALOG] Validation formulaire échouée');
      return;
    }

    print('\n${'=' * 60}');
    print('🚀 [CATALOG] DÉBUT SOUMISSION COMMANDE');
    print('=' * 60);

    // Afficher loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Récupérer le token et les infos utilisateur
      print('🔑 [CATALOG] Récupération du token...');
      final String? token = await SessionManager.getToken();
      if (token == null) {
        print('❌ [CATALOG] Token non disponible');
        throw Exception('Token non disponible');
      }
      print('✅ [CATALOG] Token récupéré: ${token.substring(0, 10)}...');

      // Récupérer les données utilisateur
      print('👤 [CATALOG] Récupération des infos utilisateur...');
      final userData = await UserService.getUserInfo(token);
      final String phoneNumber =
          userData.enregistrement['mobile']?.toString() ??
          _phoneController.text;
      final String userName =
          userData.enregistrement['username']?.toString() ??
          userData.enregistrement['nom']?.toString() ??
          '';

      print('   - Mobile: $phoneNumber');
      print('   - Nom: $userName');

      // Préparer les données de commande (format générique)
      print('📦 [CATALOG] Préparation de la commande...');
      final Map<String, dynamic> commande = {};

      // Construire l'objet commande avec product_id comme clé
      widget.cart.forEach((productId, cartItem) {
        commande[productId] = {
          'nom': cartItem.product.name,
          'prix': cartItem.product.discountedPrice,
          'quantite': cartItem.quantity,
          'description': cartItem.product.description,
        };
        print(
          '   - ${cartItem.product.name} x${cartItem.quantity} = ${cartItem.product.discountedPrice * cartItem.quantity} FCFA',
        );
      });

      print(
        '💰 [CATALOG] Montant total: $total FCFA (dont ${selectedDelivery!.fee} FCFA de livraison)',
      );

      final orderData = {
        'montant': total,
        'momo': phoneNumber,
        'name': userName.isNotEmpty ? userName : _phoneController.text,
        'mobile': _phoneController.text,
        'adresse': _addressController.text,
        'nom': userName.isNotEmpty ? userName : _phoneController.text,
        'commande': commande,
        'delivery_option': selectedDelivery!.id,
        'delivery_fee': selectedDelivery!.fee,
        'notes': _notesController.text,
      };
      print('\n📤 [CATALOG] Envoi de la commande...');
      print('\n📤 [CATALOG] Envoi de la commande...');
      print('   - URL: ${widget.catalogData['api_checkout']}');
      print('   - Nombre de produits: ${commande.length}');
      print('   - Données: ${jsonEncode(orderData)}');

      // Appel API
      final response = await http.post(
        Uri.parse(widget.catalogData['api_checkout'] as String),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(orderData),
      );

      Navigator.pop(context); // Fermer loading

      print('\n📥 [CATALOG] Réponse reçue:');
      print('   - Status Code: ${response.statusCode}');
      print('   - Headers: ${response.headers}');
      print('   - Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Succès
        final responseData = jsonDecode(response.body);
        final transId = responseData['transID'] ?? responseData['order_id'];

        print('\n${'=' * 60}');
        print('🎉 [CATALOG] COMMANDE RÉUSSIE');
        print('=' * 60);
        print('   - TransID: $transId');
        print('   - Order ID: ${responseData['order_id']}');
        print('   - Montant: ${responseData['montant_total']} FCFA');
        print('${'=' * 60}\n');

        _showSuccessDialog();
      } else {
        // Erreur
        print('\n❌ [CATALOG] Erreur HTTP ${response.statusCode}');

        String errorMsg = 'Erreur lors de la commande';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['error'] ?? errorData['msg'] ?? errorMsg;
          print('   - Message: $errorMsg');
          if (errorData['details'] != null) {
            print('   - Détails: ${errorData['details']}');
          }
        } catch (e) {
          print('   - Body brut: ${response.body}');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      Navigator.pop(context); // Fermer loading

      print('\n❌ [CATALOG] ERREUR EXCEPTION');
      print('   - Type: ${e.runtimeType}');
      print('   - Message: $e');
      print('   - StackTrace:');
      print(stackTrace.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: primaryColor,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Commande confirmée !',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Livraison estimée: ${selectedDelivery!.estimatedTime}',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Fermer dialog
                Navigator.pop(context); // Retour au catalogue
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, secondaryColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar personnalisée
              _buildCheckoutAppBar(),

              // Contenu du formulaire
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _buildCheckoutContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finaliser la commande',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Dernière étape avant la livraison',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutContent() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),

          // Options de livraison avec style moderne
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.1),
                  primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.local_shipping, color: primaryColor, size: 22),
                SizedBox(width: 10),
                Text(
                  'Mode de livraison',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...widget.deliveryOptions.map((option) {
            final isSelected = selectedDelivery == option;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withOpacity(0.1)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: RadioListTile<DeliveryOption>(
                title: Text(
                  option.name,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? primaryColor : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  '${option.description} • ${option.fee.toStringAsFixed(0)} ${widget.catalogData['currency']}',
                  style: TextStyle(
                    color: isSelected ? primaryColor : Colors.grey[600],
                  ),
                ),
                value: option,
                groupValue: selectedDelivery,
                activeColor: primaryColor,
                onChanged: (value) {
                  setState(() {
                    selectedDelivery = value;
                  });
                },
              ),
            );
          }),

          const SizedBox(height: 24),

          // Informations de livraison avec style moderne
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.1),
                  primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.location_on, color: primaryColor, size: 22),
                SizedBox(width: 10),
                Text(
                  'Informations de livraison',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Téléphone',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E7FF),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E7FF),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              prefixIcon: Icon(
                Icons.phone,
                color: primaryColor.withOpacity(0.7),
              ),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre numéro';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Adresse de livraison',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E7FF),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E7FF),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              prefixIcon: Icon(
                Icons.location_on,
                color: primaryColor.withOpacity(0.7),
              ),
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre adresse';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (optionnel)',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E7FF),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E7FF),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              prefixIcon: Icon(
                Icons.note,
                color: primaryColor.withOpacity(0.7),
              ),
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 24),

          // Résumé avec style moderne
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.1),
                  primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.receipt_long, color: primaryColor, size: 22),
                SizedBox(width: 10),
                Text(
                  'Résumé de la commande',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ...widget.cart.entries.map((entry) {
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('${item.product.name} x${item.quantity}'),
                  ),
                  Text(
                    '${item.total.toStringAsFixed(0)} ${widget.catalogData['currency']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),

          const Divider(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sous-total'),
              Text(
                '${subtotal.toStringAsFixed(0)} ${widget.catalogData['currency']}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Livraison'),
              Text(
                '${selectedDelivery?.fee.toStringAsFixed(0)} ${widget.catalogData['currency']}',
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${total.toStringAsFixed(0)} ${widget.catalogData['currency']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: primaryColor.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 22),
                  SizedBox(width: 12),
                  Text(
                    'Confirmer la commande',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
