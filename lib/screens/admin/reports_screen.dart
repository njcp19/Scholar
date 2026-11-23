import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/widgets.dart';

/// FR-24 — Audit report of every disbursement batch.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _batches = [];
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _batches = await context.read<AppState>().wallet.getDisbursements();
      _error = null;
      _offline = false;
    } catch (e) {
      _error = 'Could not load reports. Please try again.';
      _offline = isOfflineLoadError(e);
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _hasLoaded = true;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _offline = false;
    });
    await _load();
  }

  double get _grandTotal => _batches.fold(
      0,
      (sum, b) =>
          sum +
          ((b['amount_per_scholar'] ?? 0) as num).toDouble() *
              ((b['recipient_count'] ?? 0) as num).toInt());

  bool get _canExport => !_loading && _error == null && _batches.isNotEmpty;

  List<_DisbursementBatch> get _reportBatches =>
      _batches.map(_DisbursementBatch.fromMap).toList(growable: false);

  Future<void> _openExportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExportReportSheet(
        batches: _reportBatches,
        grandTotal: _grandTotal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canExport = _canExport;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 26),
          child: _roundAction(
            icon: AppIcons.back,
            tooltip: 'Back',
            size: 42,
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        title: Text(
          'Disbursement Reports',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (canExport)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _roundAction(
                icon: AppIcons.download,
                tooltip: 'Export report',
                size: 44,
                onPressed: _openExportSheet,
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AppInitialLoadView(
              firstLoadPending: !_hasLoaded,
              skeleton: _loadingContent(),
              child: _error != null && _batches.isEmpty
                  ? _errorContent()
                  : _reportContent(canExport: canExport),
            ),
          ),
          if (canExport)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: PrimaryButton(
                  label: 'Export report',
                  icon: AppIcons.download,
                  minHeight: 56,
                  borderRadius: 18,
                  shadow: true,
                  onPressed: _openExportSheet,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required double size,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: context.colors.surface,
      shape: CircleBorder(
        side: BorderSide(color: context.colors.borderSoft),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: context.colors.brand, size: 21),
      ),
    );
  }

  Widget _loadingContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const SkeletonCard(
          radius: 28,
          padding: EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(width: 220, height: 14),
              SizedBox(height: 14),
              SkeletonLine(width: 210, height: 38),
              SizedBox(height: 10),
              SkeletonLine(width: 150, height: 14),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SkeletonLine(width: 100, height: 14),
        const SizedBox(height: 12),
        for (var index = 0; index < 3; index++) ...[
          const SkeletonCard(
            child: Column(
              children: [
                Row(
                  children: [
                    SkeletonCircle(diameter: 42),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine(width: 140, height: 14),
                          SizedBox(height: 8),
                          SkeletonLine(width: 98, height: 12),
                        ],
                      ),
                    ),
                    SkeletonLine(width: 82, height: 15),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _errorContent() {
    return RefreshIndicator(
      onRefresh: _retry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          ErrorCard(
            message: _offline
                ? 'Check your connection and try again. Your balance and payouts are not changed.'
                : 'Could not load reports.\n$_error',
            onRetry: _retry,
            prominent: true,
            offline: _offline,
          ),
        ],
      ),
    );
  }

  Widget _reportContent({required bool canExport}) {
    final reportBatches = _reportBatches;
    return RefreshIndicator(
      onRefresh: _retry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 8, 20, canExport ? 112 : 24),
        children: [
          if (_error != null) ...[
            ErrorCard(
              message: _offline
                  ? 'Check your connection and try again. Your balance and payouts are not changed.'
                  : 'Could not load reports.\n$_error',
              onRetry: _retry,
              offline: _offline,
            ),
            const SizedBox(height: 12),
          ],
          _summaryCard(),
          const SizedBox(height: 24),
          const SectionLabel('BATCHES'),
          const SizedBox(height: 12),
          if (_batches.isEmpty)
            const EmptyState(
              icon: AppIcons.fileText,
              title: 'No disbursements recorded yet.',
              message: 'Disbursement batches will appear here.',
            )
          else
            ...reportBatches.map(_batchCard),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final muted = context.colors.onHeader.withValues(alpha: .84);
    final countLabel =
        '${_batches.length} ${_batches.length == 1 ? 'batch' : 'batches'} recorded';
    return AppCard(
      radius: 28,
      padding: EdgeInsets.zero,
      shadow: true,
      clipBehavior: Clip.hardEdge,
      borderColor: Colors.transparent,
      borderWidth: 0,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [context.colors.header, context.colors.receiptHeroEnd],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TOTAL DISBURSED (ALL BATCHES)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 10),
            HeroAmountText(
              prefix: 'PHP ',
              amount: fmtPhp(_grandTotal),
              color: context.colors.onHeader,
              letterSpacing: -.8,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                countLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batchCard(_DisbursementBatch batch) {
    if (!batch.hasDisplayableData) return const SizedBox.shrink();
    final details = batch.details;
    final total = batch.total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: 22,
        shadow: true,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.brandTint,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.fileText,
                color: context.colors.brand,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (batch.title != null)
                    Text(
                      batch.title!,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (details.isNotEmpty) ...[
                    if (batch.title != null) const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(
                        color: context.colors.textBody,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (total != null) ...[
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  'PHP ${fmtPhp(total)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: context.colors.brand,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DisbursementBatch {
  final String? title;
  final DateTime? createdAt;
  final int? recipientCount;
  final double? amountPerScholar;

  const _DisbursementBatch({
    required this.title,
    required this.createdAt,
    required this.recipientCount,
    required this.amountPerScholar,
  });

  factory _DisbursementBatch.fromMap(Map<String, dynamic> row) {
    final rawTitle = row['title'];
    final rawDate = row['created_at'];
    final rawCount = row['recipient_count'];
    final rawAmount = row['amount_per_scholar'];
    final title = rawTitle?.toString().trim();

    return _DisbursementBatch(
      title: title == null || title.isEmpty ? null : title,
      createdAt: rawDate == null ? null : DateTime.tryParse(rawDate.toString()),
      recipientCount: rawCount is num ? rawCount.toInt() : null,
      amountPerScholar: rawAmount is num ? rawAmount.toDouble() : null,
    );
  }

  double? get total => recipientCount == null || amountPerScholar == null
      ? null
      : recipientCount! * amountPerScholar!;

  bool get hasDisplayableData =>
      title != null ||
      createdAt != null ||
      recipientCount != null ||
      amountPerScholar != null;

  String get details {
    final parts = <String>[];
    if (createdAt != null) {
      parts.add(DateFormat('MMM d, yyyy').format(createdAt!.toLocal()));
    }
    if (recipientCount != null && amountPerScholar != null) {
      parts.add(
        '$recipientCount '
        '${recipientCount == 1 ? 'scholar' : 'scholars'} '
        '× PHP ${fmtPhp(amountPerScholar!)}',
      );
    } else if (recipientCount != null) {
      parts.add(
        '$recipientCount ${recipientCount == 1 ? 'scholar' : 'scholars'}',
      );
    } else if (amountPerScholar != null) {
      parts.add('PHP ${fmtPhp(amountPerScholar!)}');
    }
    return parts.join(' · ');
  }

  List<String> get exportCells => [
        title ?? '',
        createdAt == null
            ? ''
            : DateFormat('MMM d, yyyy').format(createdAt!.toLocal()),
        recipientCount?.toString() ?? '',
        amountPerScholar == null ? '' : 'PHP ${fmtPhp(amountPerScholar!)}',
        total == null ? '' : 'PHP ${fmtPhp(total!)}',
      ];
}

enum _ExportFormat { pdf, csv }

class _ExportReportSheet extends StatefulWidget {
  final List<_DisbursementBatch> batches;
  final double grandTotal;

  const _ExportReportSheet({
    required this.batches,
    required this.grandTotal,
  });

  @override
  State<_ExportReportSheet> createState() => _ExportReportSheetState();
}

class _ExportReportSheetState extends State<_ExportReportSheet> {
  _ExportFormat _format = _ExportFormat.pdf;
  bool _includeBatchSummary = true;
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final generatedAt =
          DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
      final rows = widget.batches
          .map((batch) => batch.exportCells)
          .toList(growable: false);
      final filename = _format == _ExportFormat.pdf
          ? 'scholar-wallet-disbursement-report.pdf'
          : 'scholar-wallet-disbursement-report.csv';
      final mimeType =
          _format == _ExportFormat.pdf ? 'application/pdf' : 'text/csv';
      final Uint8List bytes;
      if (_format == _ExportFormat.pdf) {
        bytes = await compute(
          _generatePdfBytes,
          <String, Object?>{
            'generatedAt': generatedAt,
            'includeSummary': _includeBatchSummary,
            'grandTotal': 'PHP ${fmtPhp(widget.grandTotal)}',
            'batchCount': _batchCountLabel(widget.batches.length),
            'rows': rows,
          },
        );
      } else {
        bytes = Uint8List.fromList(
          utf8.encode(
            _generateCsv(
              generatedAt: generatedAt,
              includeSummary: _includeBatchSummary,
              grandTotal: 'PHP ${fmtPhp(widget.grandTotal)}',
              batchCount: _batchCountLabel(widget.batches.length),
              rows: rows,
            ),
          ),
        );
      }

      if (!mounted) return;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: mimeType),
          ],
          fileNameOverrides: [filename],
          subject: 'Scholar Wallet Disbursement Report',
        ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        showMsg(context, 'Could not share the report on this device.',
            error: true);
      } else if (result.status == ShareResultStatus.success) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        showMsg(context, 'Could not export the report. Please try again.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Export report',
      radius: 28,
      showDragHandle: true,
      dragHandleSize: const Size(44, 5),
      dragHandleColor: context.colors.sheetHandle,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export report',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a file format for the disbursement report',
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 13,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _formatTile(
                  label: 'PDF',
                  description: 'Ready to print',
                  icon: AppIcons.fileText,
                  format: _ExportFormat.pdf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _formatTile(
                  label: 'CSV',
                  description: 'Open in Excel',
                  icon: AppIcons.table,
                  format: _ExportFormat.csv,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionLabel('INCLUDE'),
          Divider(height: 16, color: context.colors.borderSoft),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Batch summary',
              style: TextStyle(color: context.colors.textPrimary),
            ),
            value: _includeBatchSummary,
            activeTrackColor: context.colors.brand,
            onChanged: _exporting
                ? null
                : (value) => setState(() => _includeBatchSummary = value),
          ),
          Divider(height: 1, color: context.colors.borderSoft),
          const SizedBox(height: 18),
          PrimaryButton(
            label: _format == _ExportFormat.pdf ? 'Export PDF' : 'Export CSV',
            icon: AppIcons.download,
            minHeight: 56,
            borderRadius: 18,
            shadow: true,
            loading: _exporting,
            loadingLabel: 'Preparing report...',
            onPressed: _exporting ? null : _export,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _exporting ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: context.colors.textBody,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatTile({
    required String label,
    required String description,
    required IconData icon,
    required _ExportFormat format,
  }) {
    final selected = _format == format;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $description',
      child: AppCard(
        onTap: _exporting ? null : () => setState(() => _format = format),
        radius: 22,
        padding: const EdgeInsets.all(16),
        backgroundColor:
            selected ? context.colors.brandTint : context.colors.surface,
        borderColor: selected ? context.colors.brand : context.colors.border,
        borderWidth: selected ? 2 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    selected ? context.colors.brand : context.colors.borderSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: selected
                    ? context.colors.onHeader
                    : context.colors.textBody,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _batchCountLabel(int count) =>
    '$count ${count == 1 ? 'batch' : 'batches'} recorded';

String _generateCsv({
  required String generatedAt,
  required bool includeSummary,
  required String grandTotal,
  required String batchCount,
  required List<List<String>> rows,
}) {
  final records = <List<String>>[
    ['Scholar Wallet'],
    ['Disbursement Report'],
    ['Generated', generatedAt],
    if (includeSummary) ...[
      ['Total disbursed', grandTotal],
      ['Batches recorded', batchCount],
    ],
    [
      'Payout Event',
      'Date',
      'Scholar Count',
      'Amount per Scholar',
      'Payout Total',
    ],
    ...rows,
  ];
  return records.map((record) => record.map(_csvCell).join(',')).join('\r\n');
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

Future<Uint8List> _generatePdfBytes(Map<String, Object?> data) async {
  final rawRows = data['rows'] as List;
  final rows = rawRows
      .map((row) => (row as List).map((cell) => cell.toString()).toList())
      .toList();
  final includeSummary = data['includeSummary'] == true;
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            'Scholar Wallet',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Text(
          'Disbursement Report',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Generated: ${data['generatedAt']}'),
        if (includeSummary) ...[
          pw.SizedBox(height: 10),
          pw.Text('Total disbursed: ${data['grandTotal']}'),
          pw.Text('Batches recorded: ${data['batchCount']}'),
        ],
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Payout Event',
            'Date',
            'Scholar Count',
            'Amount per Scholar',
            'Payout Total',
          ],
          data: rows,
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(
            color: pdf.PdfColors.grey300,
          ),
          cellAlignments: const {
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
        ),
      ],
    ),
  );
  return document.save();
}
