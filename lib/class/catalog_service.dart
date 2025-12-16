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

  Color get colorValue => Color(int.parse(color.substring(1, 7), radix: 16) + 0xFF000000);
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

class _CatalogServiceState extends State<CatalogService> with SingleTickerProviderStateMixin {
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

  // Couleurs
  static const primaryColor = Color(0xFF006699);
  static const secondaryColor = Color(0xFF0088CC);

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
      // Pour le test, charger depuis le fichier JSON local
      // En production, remplacer par un appel API
      final String jsonString = await DefaultAssetBundle.of(context)
          .loadString('catalog_service_test.json');

      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      setState(() {
        catalogData = data;

        // Parser les catégories
        categories = (data['categories'] as List)
            .map((c) => Category.fromJson(c as Map<String, dynamic>))
            .toList();

        // Parser les produits
        allProducts = (data['products'] as List)
            .map((p) => Product.fromJson(p as Map<String, dynamic>))
            .toList();

        filteredProducts = allProducts;

        // Parser les options de livraison
        deliveryOptions = (data['delivery_options'] as List)
            .map((d) => DeliveryOption.fromJson(d as Map<String, dynamic>))
            .toList();

        isLoading = false;

        // Initialiser TabController
        _tabController = TabController(length: categories.length + 1, vsync: this);
        _tabController.addListener(_handleTabChange);
      });
    } catch (e) {
      print('Erreur chargement catalogue: $e');
      setState(() {
        isLoading = false;
      });
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
        final matchesCategory = selectedCategory == null || product.category == selectedCategory;
        final matchesSearch = searchQuery.isEmpty ||
            product.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            product.description.toLowerCase().contains(searchQuery.toLowerCase());

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
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mon Panier',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$cartItemCount ${cartItemCount > 1 ? 'articles' : 'article'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 24),

              // Liste des produits
              Expanded(
                child: cart.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Votre panier est vide',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.product.image != null
                  ? Image.network(
                      item.product.image!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Icon(Icons.shopping_bag),
                    ),
            ),

            const SizedBox(width: 12),

            // Info produit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.product.discountedPrice.toStringAsFixed(0)} ${catalogData!['currency']} / ${item.product.unit}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Quantité
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: primaryColor,
                  onPressed: () => _removeFromCart(item.product.id),
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: primaryColor,
                  onPressed: () => _addToCart(item.product),
                ),
              ],
            ),

            // Total
            Text(
              '${item.total.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartFooter() {
    final deliveryFee = catalogData!['delivery_fee'] as num;
    final total = cartTotal + deliveryFee.toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sous-total'),
              Text('${cartTotal.toStringAsFixed(0)} ${catalogData!['currency']}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Livraison'),
              Text('${deliveryFee.toStringAsFixed(0)} ${catalogData!['currency']}'),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${total.toStringAsFixed(0)} ${catalogData!['currency']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _goToCheckout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Commander',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      appBar: AppBar(
        title: Text(catalogData!['title'] as String),
        backgroundColor: primaryColor,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _showCart,
              ),
              if (cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '$cartItemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Barre de recherche
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
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

              // Tabs catégories
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  const Tab(text: 'Tout'),
                  ...categories.map((cat) => Tab(text: cat.name)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(
          categories.length + 1,
          (index) => _buildProductGrid(),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Aucun produit trouvé',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(filteredProducts[index]);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final isInCart = cart.containsKey(product.id);
    final quantity = isInCart ? cart[product.id]!.quantity : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image avec badge promo
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: product.image != null
                    ? Image.network(
                        product.image!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, size: 50),
                        ),
                      )
                    : Container(
                        height: 120,
                        color: Colors.grey[200],
                        child: const Icon(Icons.shopping_bag, size: 50),
                      ),
              ),
              if (product.discount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '-${product.discount.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Info produit
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (product.discount > 0)
                    Text(
                      '${product.price.toStringAsFixed(0)} ${catalogData!['currency']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    '${product.discountedPrice.toStringAsFixed(0)} ${catalogData!['currency']}',
                    style: const TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '/${product.unit}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),

                  // Bouton ajouter
                  SizedBox(
                    width: double.infinity,
                    child: isInCart
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _removeFromCart(product.id),
                                ),
                                Text(
                                  '$quantity',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _addToCart(product),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _addToCart(product),
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text('Ajouter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
        ],
      ),
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
  DeliveryOption? selectedDelivery;
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  static const primaryColor = Color(0xFF006699);

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
    if (!_formKey.currentState!.validate()) return;

    // Afficher loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Préparer les données de commande
      final orderData = {
        'items': widget.cart.entries.map((entry) {
          return {
            'product_id': entry.key,
            'quantity': entry.value.quantity,
            'price': entry.value.product.discountedPrice,
          };
        }).toList(),
        'delivery_option': selectedDelivery!.id,
        'delivery_address': _addressController.text,
        'phone': _phoneController.text,
        'notes': _notesController.text,
        'subtotal': subtotal,
        'delivery_fee': selectedDelivery!.fee,
        'total': total,
      };

      // Appel API (remplacer par votre vraie API)
      final response = await http.post(
        Uri.parse(widget.catalogData['api_checkout'] as String),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await SessionManager.getToken()}',
        },
        body: jsonEncode(orderData),
      );

      Navigator.pop(context); // Fermer loading

      if (response.statusCode == 200) {
        // Succès
        _showSuccessDialog();
      } else {
        // Erreur
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la commande'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Fermer loading
      print('Erreur commande: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            const Text(
              'Commande confirmée !',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Livraison estimée: ${selectedDelivery!.estimatedTime}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fermer dialog
              Navigator.pop(context); // Retour au catalogue
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finaliser la commande'),
        backgroundColor: primaryColor,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Options de livraison
            const Text(
              'Mode de livraison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...widget.deliveryOptions.map((option) {
              return RadioListTile<DeliveryOption>(
                title: Text(option.name),
                subtitle: Text('${option.description} • ${option.fee.toStringAsFixed(0)} ${widget.catalogData['currency']}'),
                value: option,
                groupValue: selectedDelivery,
                onChanged: (value) {
                  setState(() {
                    selectedDelivery = value;
                  });
                },
              );
            }),

            const Divider(height: 32),

            // Informations de livraison
            const Text(
              'Informations de livraison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
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
              decoration: const InputDecoration(
                labelText: 'Adresse de livraison',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
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
              decoration: const InputDecoration(
                labelText: 'Notes (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),

            const Divider(height: 32),

            // Résumé
            const Text(
              'Résumé de la commande',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

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
                Text('${subtotal.toStringAsFixed(0)} ${widget.catalogData['currency']}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Livraison'),
                Text('${selectedDelivery?.fee.toStringAsFixed(0)} ${widget.catalogData['currency']}'),
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
              child: ElevatedButton(
                onPressed: _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirmer la commande',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
