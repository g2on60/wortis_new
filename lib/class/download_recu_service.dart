import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart'; 
import 'package:wortis/class/class.dart';

class ReceiptDownloadService {
  static const String baseUrl = "https://api.live.wortis.cg";
  
  // ========== MÉTHODE PRINCIPALE D'INTÉGRATION ==========
  static Future<void> downloadReceipt(BuildContext context, String url, String transactionId) async {
    if (url.isEmpty) {
      CustomOverlay.showError(context, message: "URL du reçu non disponible");
      return;
    }

    try {
      print('🔗 [Receipt] Téléchargement reçu: $transactionId');
      
      // Étape 1: Essayer l'ouverture directe
      bool opened = await _tryDirectOpen(context, url);
      
      if (!opened) {
        // Étape 2: Proposer les options de téléchargement
        await _showDownloadOptions(context, url, transactionId);
      }
      
    } catch (e) {
      print('❌ [Receipt] Erreur générale: $e');
      CustomOverlay.showError(
        context, 
        message: "Erreur lors de l'accès au reçu",
      );
    }
  }

  // ========== TENTATIVE D'OUVERTURE DIRECTE ==========
  static Future<bool> _tryDirectOpen(BuildContext context, String url) async {
    try {
      final Uri uri = Uri.parse(url);
      
      // Modes dans l'ordre de préférence
      List<LaunchMode> modes = [
        LaunchMode.externalApplication,
        LaunchMode.inAppWebView,
        LaunchMode.platformDefault,
      ];
      
      for (LaunchMode mode in modes) {
        try {
          bool launched = await launchUrl(uri, mode: mode);
          if (launched) {
            CustomOverlay.showSuccess(
              context, 
              message: "Reçu ouvert avec succès",
            );
            return true;
          }
        } catch (e) {
          continue;
        }
      }
      
      return false;
      
    } catch (e) {
      print('❌ [Receipt] Erreur ouverture directe: $e');
      return false;
    }
  }

  // ========== OPTIONS DE TÉLÉCHARGEMENT ==========
  static Future<void> _showDownloadOptions(BuildContext context, String url, String transactionId) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
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
                    const Icon(Icons.receipt_long, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Reçu de transaction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Options
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Option 1: Télécharger et ouvrir
                    _buildOption(
                      context,
                      icon: Icons.download,
                      title: 'Télécharger le reçu',
                      subtitle: 'Sauvegarder sur cet appareil',
                      onTap: () {
                        Navigator.pop(context);
                        _downloadAndOpen(context, url, transactionId);
                      },
                    ),
                    
                    const Divider(height: 1),
                    
                    // Option 2: Aperçu WebView
                    _buildOption(
                      context,
                      icon: Icons.visibility,
                      title: 'Aperçu dans l\'app',
                      subtitle: 'Visualiser sans télécharger',
                      onTap: () {
                        Navigator.pop(context);
                        _openInWebView(context, url, transactionId);
                      },
                    ),
                    
                    const Divider(height: 1),
                    
                    // Option 3: Copier le lien
                    _buildOption(
                      context,
                      icon: Icons.link,
                      title: 'Copier le lien',
                      subtitle: 'Pour partager ou ouvrir plus tard',
                      onTap: () {
                        Navigator.pop(context);
                        _copyToClipboard(context, url);
                      },
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

  static Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF006699).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF006699)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  // ========== TÉLÉCHARGEMENT AVEC CUSTOMOVERLAY ==========
  static Future<void> _downloadAndOpen(BuildContext context, String url, String transactionId) async {
    try {
      // Vérifier les permissions Android
      if (Platform.isAndroid && !await _checkStoragePermissions(context)) {
        return;
      }

      // Afficher le loading avec CustomOverlay
      CustomOverlay.showLoading(
        context,
        message: "Téléchargement en cours...",
      );

      // Télécharger le fichier
      final file = await _downloadFile(url, transactionId);
      
      // Cacher le loading
      CustomOverlay.hide();

      if (file != null) {
        // Succès du téléchargement
        CustomOverlay.showSuccess(
          context,
          message: "Reçu téléchargé avec succès",
        );

        // Essayer d'ouvrir le fichier
        await _openLocalFile(context, file);
      } else {
        CustomOverlay.showError(
          context,
          message: "Échec du téléchargement"
        );
      }

    } catch (e) {
      CustomOverlay.hide();
      print('❌ [Receipt] Erreur téléchargement: $e');
      CustomOverlay.showError(
        context,
        message: "Erreur lors du téléchargement: ${e.toString()}"
      );
    }
  }

  static Future<bool> _checkStoragePermissions(BuildContext context) async {
    if (Platform.isAndroid) {
      bool hasPermission = false;
      
      // Vérifier les permissions existantes
      if (await Permission.storage.isGranted || 
          await Permission.manageExternalStorage.isGranted) {
        hasPermission = true;
      } else {
        // Demander les permissions
        Map<Permission, PermissionStatus> statuses = await [
          Permission.storage,
          Permission.manageExternalStorage,
        ].request();
        
        hasPermission = statuses.values.any((status) => status.isGranted);
      }

      if (!hasPermission) {
        CustomOverlay.showWarning(
          context,
          message: "Permission de stockage requise pour télécharger le reçu"
        );
        return false;
      }
    }
    return true;
  }

  static Future<File?> _downloadFile(String url, String transactionId) async {
    try {
      final Dio dio = Dio();
      
      // Obtenir le répertoire de téléchargement
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      if (directory == null) return null;
      
      // Nom de fichier avec ID de transaction
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'recu_${transactionId}_$timestamp.pdf';
      final filePath = '${directory.path}/$fileName';
      
      // Télécharger avec timeout et headers
      await dio.download(
        url,
        filePath,
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent': 'WortisApp/1.0',
            'Accept': 'application/pdf,application/octet-stream,*/*',
          },
        ),
      );
      
      final file = File(filePath);
      return file.existsSync() ? file : null;
      
    } catch (e) {
      print('❌ [Receipt] Erreur download: $e');
      return null;
    }
  }

  static Future<void> _openLocalFile(BuildContext context, File file) async {
    try {
      final result = await OpenFilex.open(file.path);
      
      if (result.type != ResultType.done) {
        // Si l'ouverture échoue, proposer le partage
        CustomOverlay.showInfo(
          context,
          message: "Reçu téléchargé. Fichier sauvegardé dans Downloads"
        );
      }
      
    } catch (e) {
      print('❌ [Receipt] Erreur ouverture fichier: $e');
      CustomOverlay.showInfo(
        context,
        message: "Reçu téléchargé avec succès"
      );
    }
  }

  // ========== WEBVIEW INTÉGRÉE ==========
  static void _openInWebView(BuildContext context, String url, String transactionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptWebViewPage(
          url: url,
          transactionId: transactionId,
        ),
      ),
    );
  }

  // ========== COPIER LE LIEN ==========
  static Future<void> _copyToClipboard(BuildContext context, String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      CustomOverlay.showSuccess(
        context,
        message: "Lien copié dans le presse-papiers"
      );
    } catch (e) {
      CustomOverlay.showError(
        context,
        message: "Impossible de copier le lien"
      );
    }
  }
}

// ========== PAGE WEBVIEW POUR APERÇU - VERSION CORRIGÉE ==========
class ReceiptWebViewPage extends StatefulWidget {
  final String url;
  final String transactionId;

  const ReceiptWebViewPage({
    super.key,
    required this.url,
    required this.transactionId,
  });

  @override
  State<ReceiptWebViewPage> createState() => _ReceiptWebViewPageState();
}

class _ReceiptWebViewPageState extends State<ReceiptWebViewPage> {
  bool isLoading = true;
  bool hasError = false;
  late final WebViewController _controller; // ✅ NOUVEAU: Contrôleur WebView moderne

  @override
  void initState() {
    super.initState();
    
    // ✅ NOUVEAU: Configuration moderne de WebView
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              isLoading = false;
              hasError = true;
            });
            print('❌ [WebView] Erreur: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Reçu de transaction'),
        backgroundColor: const Color(0xFF006699),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => ReceiptDownloadService._downloadAndOpen(
              context,
              widget.url,
              widget.transactionId,
            ),
            tooltip: 'Télécharger',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => ReceiptDownloadService._copyToClipboard(
              context,
              widget.url,
            ),
            tooltip: 'Partager',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ✅ NOUVEAU: WebView moderne
          WebViewWidget(controller: _controller),
          
          // Indicateur de chargement
          if (isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF006699)),
                    SizedBox(height: 16),
                    Text(
                      'Chargement du reçu...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF006699),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Message d'erreur
          if (hasError && !isLoading)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Impossible de charger le reçu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Essayez de le télécharger directement',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => ReceiptDownloadService._downloadAndOpen(
                            context,
                            widget.url,
                            widget.transactionId,
                          ),
                          icon: const Icon(Icons.download),
                          label: const Text('Télécharger'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006699),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              hasError = false;
                            });
                            _controller.reload();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF006699),
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
    );
  }
}