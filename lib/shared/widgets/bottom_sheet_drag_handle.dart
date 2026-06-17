import 'package:flutter/material.dart';
import '../../app/theme.dart';

class BottomSheetDragHandle extends StatelessWidget {
  const BottomSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: AppColors.iconOverlay,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
