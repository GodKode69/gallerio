import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

class TimelineScrubber extends StatefulWidget {
  final List<AssetEntity> assets;
  final ScrollController scrollController;
  final double itemHeight;

  const TimelineScrubber({
    super.key,
    required this.assets,
    required this.scrollController,
    this.itemHeight = 1.0,
  });

  @override
  State<TimelineScrubber> createState() => _TimelineScrubberState();
}

class _TimelineScrubberState extends State<TimelineScrubber> {
  bool _isDragging = false;
  String _currentMonth = '';

  List<_MonthEntry> _buildMonthEntries() {
    if (widget.assets.isEmpty) return [];

    final sorted = List<AssetEntity>.from(widget.assets)
      ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    final entries = <_MonthEntry>[];
    DateTime? lastMonth;

    for (final asset in sorted) {
      final date = asset.createDateTime;
      final monthKey = DateTime(date.year, date.month);

      if (lastMonth == null || monthKey != lastMonth) {
        entries.add(_MonthEntry(
          month: monthKey,
          label: DateFormat('MMM yyyy').format(monthKey),
          assetIndex: sorted.indexOf(asset),
        ));
        lastMonth = monthKey;
      }
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildMonthEntries();
    if (entries.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onVerticalDragStart: (details) {
        setState(() => _isDragging = true);
        _handleDrag(details.localPosition.dy, entries);
      },
      onVerticalDragUpdate: (details) {
        _handleDrag(details.localPosition.dy, entries);
      },
      onVerticalDragEnd: (_) {
        setState(() => _isDragging = false);
      },
      child: AnimatedOpacity(
        opacity: _isDragging ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 50,
          decoration: BoxDecoration(
            color: _isDragging
                ? Colors.black.withValues(alpha: 0.7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              for (int i = 0; i < entries.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _scrollToMonth(entries[i], entries),
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Text(
                          entries[i].label.split(' ').first,
                          style: TextStyle(
                            color: _currentMonth == entries[i].label
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white38,
                            fontSize: 9,
                            fontWeight: _currentMonth == entries[i].label
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDrag(double dy, List<_MonthEntry> entries) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final height = box.size.height;
    final ratio = (dy / height).clamp(0.0, 1.0);
    final index = (ratio * (entries.length - 1)).round();

    if (index >= 0 && index < entries.length) {
      final entry = entries[index];
      setState(() => _currentMonth = entry.label);
      _scrollToMonth(entry, entries);
    }
  }

  void _scrollToMonth(_MonthEntry entry, List<_MonthEntry> entries) {
    if (!widget.scrollController.hasClients) return;

    final totalItems = widget.assets.length;
    if (totalItems == 0) return;

    final targetIndex = entry.assetIndex;
    final estimatedOffset = targetIndex * widget.itemHeight;

    widget.scrollController.animateTo(
      estimatedOffset.clamp(
        0.0,
        widget.scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
}

class _MonthEntry {
  final DateTime month;
  final String label;
  final int assetIndex;

  _MonthEntry({
    required this.month,
    required this.label,
    required this.assetIndex,
  });
}
