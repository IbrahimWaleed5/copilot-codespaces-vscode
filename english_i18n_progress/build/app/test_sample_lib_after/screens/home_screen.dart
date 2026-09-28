import 'package:flutter/material.dart';

import '../widgets/status_chip.dart';

import '../i18n/i18n.dart';
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
        title: Text('الإشعارات'.tr()),
        actions: [
          Padding(
            padding: EdgeInsets.all(8),
            child: Tooltip(message: 'الدعم'.tr(), child: Icon(Icons.help)),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.wallet),
            title: Text('المحفظة'.tr()),
            subtitle: Text(('الرصيد' ' المتاح').tr()),
          ),
          Text('$count مشروع منشور'.tr()),
          Text(status == 'مقبول' ? 'تم قبول طلبك'.tr() : 'الدفع مرفوض'.tr()),
          TextField(
            decoration: InputDecoration(
              labelText: 'عنوان المصروف'.tr(),
              hintText: 'مثال: دفعة طباعة مخططات تنفيذية'.tr(),
            ),
          ),
          StatusChip(status: status, label: 'الحالة'.tr()),
          if (status.contains('مقبول')) Text("مكتملة".tr()),
          RichText(text: TextSpan(text: 'الملفات'.tr(), children: [TextSpan(text: 'مرفقات'.tr())])),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم الإيداع بنجاح'.tr())),
              );
              switch (status) {
                case 'مرفوض':
                  break;
              }
              _showConfirm(context);
            },
            child: Text('حفظ المصروف'.tr()),
          ),
          Text('الإشعارات'.toString()),
        ],
      ),
    );
  }
}
