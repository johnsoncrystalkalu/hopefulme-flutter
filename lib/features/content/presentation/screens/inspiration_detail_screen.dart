import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';

class InspirationDetailScreen extends StatefulWidget {
  const InspirationDetailScreen({
    required this.inspirationId,
    required this.repository,
    super.key,
  });

  final int inspirationId;
  final ContentRepository repository;

  @override
  State<InspirationDetailScreen> createState() =>
      _InspirationDetailScreenState();
}

class _InspirationDetailScreenState extends State<InspirationDetailScreen> {
  late Future<InspirationDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchInspiration(widget.inspirationId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.repository.fetchInspiration(widget.inspirationId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: const Text('Inspiration'),
      ),
      body: FutureBuilder<InspirationDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return AppStatusState.fromError(
              error: snapshot.error ?? 'Unable to load this inspiration.',
              actionLabel: 'Try again',
              onAction: _refresh,
            );
          }
          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('Unable to load inspiration.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: colors.brandGradient,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.senderName,
                      style: const TextStyle(
                        color: Color.fromRGBO(255, 255, 255, 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      detail.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      formatDetailedTimestamp(detail.createdAt),
                      style: const TextStyle(
                        color: Color.fromRGBO(255, 255, 255, 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
