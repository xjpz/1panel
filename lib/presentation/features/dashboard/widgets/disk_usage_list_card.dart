import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatter.dart';
import '../../../../domain/entities/dashboard.dart';
import '../../../common/components/info_panel.dart';
import '../../../common/components/skeleton_item.dart';
import '../../../common/components/thin_divider.dart';
import '../utils/dashboard_display_helpers.dart';
import 'dashboard_linear_meter.dart';

class DashboardDiskUsageListCard extends StatelessWidget {
  const DashboardDiskUsageListCard({
    super.key,
    required this.disks,
    this.loading = false,
  });

  final List<DiskUsage> disks;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      title: context.l10n.dashboard_diskPartitionsTitle,
      icon: TablerIcons.database,
      iconColor: CupertinoColors.systemIndigo.resolveFrom(context),
      child: Column(
        children: [
          if (loading) ...[
            const _DiskUsageLine(loading: true),
            const ThinDivider(indent: 44),
            const _DiskUsageLine(loading: true),
          ] else
            for (var i = 0; i < disks.length; i++) ...[
              _DiskUsageLine(disk: disks[i]),
              if (i != disks.length - 1) const ThinDivider(indent: 44),
            ],
        ],
      ),
    );
  }
}

class _DiskUsageLine extends StatelessWidget {
  const _DiskUsageLine({this.disk, this.loading = false});

  final DiskUsage? disk;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final percent = disk?.usedPercent.clamp(0.0, 100.0).toDouble() ?? 0.0;
    final color = loading
        ? CupertinoColors.systemGrey.resolveFrom(context).withValues(alpha: 0.2)
        : dashboardUsageColor(context, percent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(TablerIcons.database, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: loading
                          ? const SkeletonItem.text(width: 80, height: 14)
                          : Text(
                              disk!.path.isEmpty ? disk!.device : disk!.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.label(context),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    if (loading)
                      const SkeletonItem.text(width: 32, height: 13)
                    else
                      Text(
                        Formatter.percent(percent),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.label(context),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (loading)
                  const SkeletonItem(width: double.infinity, height: 8)
                else
                  Stack(
                    children: [
                      DashboardLinearMeter(
                        percent: 100,
                        color: AppColors.separator(context).withValues(alpha: 0.05),
                      ),
                      DashboardLinearMeter(percent: percent, color: color),
                    ],
                  ),
                const SizedBox(height: 8),
                if (loading)
                  const SkeletonItem.text(width: 120, height: 12)
                else
                  Text(
                    '${Formatter.adaptiveBytes(disk!.used)} / ${Formatter.adaptiveBytes(disk!.total)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
