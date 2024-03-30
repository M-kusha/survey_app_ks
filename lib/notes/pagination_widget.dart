import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function() onPreviousPage;
  final Function() onNextPage;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_outlined),
          onPressed: currentPage > 1 ? onPreviousPage : null,
        ),
        const SizedBox(width: 10),
        Text(
          '${'page'.tr()} $currentPage of $totalPages',
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_outlined),
          onPressed: currentPage < totalPages ? onNextPage : null,
        ),
      ],
    );
  }
}
