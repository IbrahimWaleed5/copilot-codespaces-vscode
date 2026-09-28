import 'package:flutter/material.dart';

import '../widgets/status_chip.dart';

part 'home_parts.dart';

const String kStatusApproved = 'مقبول';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.title = 'الإشعارات'});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<Tab> _tabs = [
    Tab(text: 'الاستشارات'),
    Tab(text: 'المدفوعات'),
  ];
  String status = 'مقبول';
  final Map<String, String> labels = {'مقبول': 'Approved'};

  @override
  Widget build(BuildContext context) {
    final count = 3;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: const [
          Padding(
            padding: EdgeInsets.all(8),
            child: Tooltip(message: 'الدعم', child: Icon(Icons.help)),
          ),
        ],
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.wallet),
            title: Text('المحفظة'),
            subtitle: Text('الرصيد' ' المتاح'),
          ),
          Text('$count مشروع منشور'),
          Text(status == 'مقبول' ? 'تم قبول طلبك' : 'الدفع مرفوض'),
          TextField(
            decoration: const InputDecoration(
              labelText: 'عنوان المصروف',
              hintText: 'مثال: دفعة طباعة مخططات تنفيذية',
            ),
          ),
          StatusChip(status: status, label: 'الحالة'),
          if (status.contains('مقبول')) const Text("مكتملة"),
          RichText(text: const TextSpan(text: 'الملفات', children: [TextSpan(text: 'مرفقات')])),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم الإيداع بنجاح')),
              );
              switch (status) {
                case 'مرفوض':
                  break;
              }
              _showConfirm(context);
            },
            child: const Text('حفظ المصروف'),
          ),
          Text('الإشعارات'.toString()),
        ],
      ),
    );
  }
}
