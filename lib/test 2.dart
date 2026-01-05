import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class TestUploadPage extends StatefulWidget {
  const TestUploadPage({super.key});

  @override
  State<TestUploadPage> createState() => _TestUploadPageState();
}

class _TestUploadPageState extends State<TestUploadPage> {
  File? _selectedFile;
  String _status = "Aucun fichier sélectionné";
  bool _isLoading = false;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _status = "Fichier sélectionné: ${result.files.single.name}";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Erreur lors de la sélection: $e";
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      setState(() {
        _status = "Veuillez d'abord sélectionner un fichier";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = "Upload en cours...";
    });

    try {
      // Créer la requête multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.live.wortis.cg/academy/candidatures_apk'),
      );

      // Ajouter les champs texte
      request.fields['nom_prenom'] = 'Test User';
      request.fields['ville'] = 'Brazzaville';
      request.fields['niveau'] = 'Bac+3';
      request.fields['experience'] = 'Junior';
      request.fields['token'] = 'test_token_123';

      // Lire le fichier
      final fileBytes = await _selectedFile!.readAsBytes();

      // Détecter le MIME type
      final mimeType =
          lookupMimeType(_selectedFile!.path) ?? 'application/octet-stream';

      // Créer multipart pour CV
      final cvFile = http.MultipartFile.fromBytes(
        'cv', // ⚠️ Nom du champ (doit correspondre au backend)
        fileBytes,
        filename: 'test_cv.pdf',
        contentType: MediaType('application', 'pdf'),
      );
      request.files.add(cvFile);

      // Créer multipart pour lettre (même fichier pour le test)
      final lettreFile = http.MultipartFile.fromBytes(
        'lettre', // ⚠️ Nom du champ
        fileBytes,
        filename: 'test_lettre.pdf',
        contentType: MediaType('application', 'pdf'),
      );
      request.files.add(lettreFile);

      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _status = "✅ Upload réussi!\nRéponse: ${response.body}";
          _isLoading = false;
        });
      } else {
        setState(() {
          _status = "❌ Erreur ${response.statusCode}\n${response.body}";
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      setState(() {
        _status = "❌ Erreur: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Upload Fichier'),
        backgroundColor: const Color(0xFF006699),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test d\'upload vers le backend',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Bouton sélection
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Sélectionner un PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 20),

            // Bouton upload
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _uploadFile,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(
                  _isLoading ? 'Upload en cours...' : 'Envoyer le fichier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006699),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 30),

            // Zone de statut
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statut:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Sélectionnez un fichier PDF'),
                  Text('2. Cliquez sur "Envoyer le fichier"'),
                  Text('3. Regardez les logs dans la console'),
                  Text('4. Copiez TOUTE la sortie console'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pour l'utiliser, ajoutez simplement cette page dans votre navigation:
// Navigator.push(
//   context,
//   MaterialPageRoute(builder: (context) => const TestUploadPage()),
// );
