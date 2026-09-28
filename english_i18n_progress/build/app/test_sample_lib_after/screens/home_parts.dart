part of 'home_screen.dart';

Future<void> _showConfirm(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('هل تريد حذف هذا العمل؟'.tr()),
      content: Text(
        'لا يمكن إتمام هذه العملية'.tr(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء'.tr())),
      ],
    ),
  );
}
