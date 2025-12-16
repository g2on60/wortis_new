// lib/class/uploaded_file.dart

class UploadedFile {
  final String name;
  final String path;
  final int size;
  final String? mimeType;
  final String? base64;

  UploadedFile({
    required this.name,
    required this.path,
    required this.size,
    this.mimeType,
    this.base64,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'mimeType': mimeType,
      'base64': base64,
    };
  }

  @override
  String toString() {
    return 'UploadedFile(name: $name, size: $size bytes)';
  }
}
