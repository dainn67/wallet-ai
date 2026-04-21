import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImageViewer extends StatelessWidget {
  final Uint8List bytes;

  const ImageViewer({super.key, required this.bytes});

  static Route<void> route(Uint8List bytes) {
    return MaterialPageRoute<void>(
      builder: (_) => ImageViewer(bytes: bytes),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 4.0,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
