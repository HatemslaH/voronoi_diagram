import 'dart:convert';

import '../models/voronoi_document.dart';

class VoronoiFileCodec {
  static const String fileExtension = 'vjson';
  static const String fileSuffix = '.vjson';

  const VoronoiFileCodec();

  String encode(VoronoiDocument document) {
    return const JsonEncoder.withIndent('  ').convert(document.toJson());
  }

  VoronoiDocument decode(String source, {String? filePath}) {
    if (filePath != null && !hasSupportedExtension(filePath)) {
      throw const FormatException('Only .vjson files can be imported.');
    }

    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Voronoi file must contain a JSON object.');
    }

    return VoronoiDocument.fromJson(decoded.cast<String, dynamic>());
  }

  bool hasSupportedExtension(String path) {
    return path.toLowerCase().endsWith(fileSuffix);
  }

  String normalizeExportPath(String path) {
    if (hasSupportedExtension(path)) {
      return path;
    }
    return '$path$fileSuffix';
  }
}
