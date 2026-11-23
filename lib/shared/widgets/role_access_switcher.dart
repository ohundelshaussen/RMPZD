import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum AccessEntryMode { patient, staff }

class RoleAccessSwitcher extends StatelessWidget {
  final AccessEntryMode selectedMode;
  final VoidCallback? onSelectPatient;
  final VoidCallback? onSelectStaff;

  const RoleAccessSwitcher({
    required this.selectedMode,
    this.onSelectPatient,
    this.onSelectStaff,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentItem(
              icon: Icons.person_search_rounded,
              label: 'Soy Paciente',
              selected: selectedMode == AccessEntryMode.patient,
              onTap: selectedMode == AccessEntryMode.patient
                  ? null
                  : onSelectPatient,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentItem(
              icon: Icons.medical_services_outlined,
              label: 'Personal de Salud',
              selected: selectedMode == AccessEntryMode.staff,
              onTap: selectedMode == AccessEntryMode.staff
                  ? null
                  : onSelectStaff,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SegmentItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    if (selected) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: content,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: content,
    );
  }
}
