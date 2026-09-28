import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = status == 'مقبول' ? Colors.green : Colors.red;
    return Chip(label: Text('$label: $status'), backgroundColor: color);
  }
}
