import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class LibraryReaderScreen extends StatelessWidget {
  const LibraryReaderScreen({
    required this.title,
    required this.url,
    super.key,
  });

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SfPdfViewer.network(
        url,
        canShowPaginationDialog: false,
        pageSpacing: 12,
      ),
    );
  }
}
