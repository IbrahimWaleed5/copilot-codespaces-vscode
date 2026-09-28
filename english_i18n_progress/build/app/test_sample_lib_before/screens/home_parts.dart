part of 'home_screen.dart';

Future<void> _showConfirm(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('هل تريد حذف هذا العمل؟'),
      content: const Text(
        'لا يمكن إتمام هذه العملية',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      ],
    ),
  );
}
