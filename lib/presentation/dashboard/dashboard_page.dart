import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/async_state.dart';
import '../../core/session.dart';
import '../routes.dart';
import '../widgets/app_shell.dart';
import '../widgets/common.dart';

/// W02 — Dashboard: indicadores da operação, fila de revisão, distribuição por status e carga dos inspetores.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _controller = AsyncController<Dashboard>();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _reload();
    }
  }

  void _reload() => _controller.load(AppScope.of(context).api.dashboard);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      current: NavDestination.dashboard,
      title: 'Dashboard',
      subtitle: 'Visão geral da operação',
      actions: [IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: _reload)],
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final s = _controller.state;
          if (!s.hasData) return StateMessage(loading: s.loading, error: s.error, onRetry: _reload);
          return _DashboardBody(data: s.data!);
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final Dashboard data;

  @override
  Widget build(BuildContext context) {
    final avg = data.avgHoursToApproval;
    final totalWeek = data.byStatus.values.fold<int>(0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
        final w = (c.maxWidth - (cols - 1) * IcSpacing.s4) / cols;
        return Wrap(spacing: IcSpacing.s4, runSpacing: IcSpacing.s4, children: [
          SizedBox(width: w, child: KpiCard(label: 'Em andamento', value: '${data.inProgress}', help: '${data.startedToday} iniciadas hoje')),
          SizedBox(
            width: w,
            child: KpiCard(
              label: 'Aguardando revisão',
              value: '${data.awaitingReview}',
              attention: data.awaitingReview > 0,
              help: data.awaitingReviewOver12h > 0
                  ? '${data.awaitingReviewOver12h} há mais de 12 horas · revisar'
                  : 'Nenhuma há mais de 12 horas',
              onHelpTap: () => Navigator.of(context).pushNamed(Routes.inspectionsWithStatus('COMPLETED')),
            ),
          ),
          SizedBox(width: w, child: KpiCard(label: 'Atrasadas', value: '${data.overdue}', help: 'Prazo vencido sem encerramento')),
          SizedBox(
            width: w,
            child: KpiCard(
              label: 'Tempo até a aprovação',
              value: avg == null ? '—' : '${avg.toStringAsFixed(avg % 1 == 0 ? 0 : 1).replaceAll('.', ',')} h',
              progress: avg == null ? null : avg / 24,
              help: 'Média entre encerramento e aprovação · meta: 24 h',
            ),
          ),
        ]);
      }),
      const SizedBox(height: IcSpacing.s6),
      LayoutBuilder(builder: (context, c) {
        final stacked = c.maxWidth < 1000;
        final queue = _ReviewQueue(entries: data.reviewQueue);
        final side = Column(children: [
          Panel(
            title: 'Inspeções por status',
            subtitle: '$totalWeek no total',
            child: Column(children: [
              for (final s in InspectionStatus.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: BarRow(
                    label: s.label,
                    value: data.byStatus[s] ?? 0,
                    max: data.byStatus.values.fold<int>(1, (a, b) => b > a ? b : a),
                    color: switch (s) {
                      InspectionStatus.pending => IcColors.ink600,
                      InspectionStatus.inProgress => IcColors.primary700,
                      InspectionStatus.completed => IcColors.teal700,
                      InspectionStatus.approved => IcColors.success700,
                      InspectionStatus.rejected => IcColors.danger700,
                    },
                  ),
                ),
            ]),
          ),
          const SizedBox(height: IcSpacing.s6),
          Panel(
            title: 'Carga dos inspetores hoje',
            child: data.inspectorLoadToday.isEmpty
                ? const Text('Nenhuma OS prevista para hoje.')
                : Column(children: [
                    for (final l in data.inspectorLoadToday)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: BarRow(
                            label: l.name,
                            value: l.count,
                            max: data.inspectorLoadToday.first.count,
                            color: l == data.inspectorLoadToday.first ? IcColors.signal500 : IcColors.primary700),
                      ),
                  ]),
          ),
        ]);
        if (stacked) return Column(children: [queue, const SizedBox(height: IcSpacing.s6), side]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 62, child: queue),
          const SizedBox(width: IcSpacing.s6),
          Expanded(flex: 38, child: side),
        ]);
      }),
    ]);
  }
}

class _ReviewQueue extends StatelessWidget {
  const _ReviewQueue({required this.entries});

  final List<ReviewQueueEntry> entries;

  static String _wait(int minutes) =>
      minutes >= 60 ? '${minutes ~/ 60} h${minutes % 60 == 0 ? '' : ' ${(minutes % 60).toString().padLeft(2, '0')} min'}' : '$minutes min';

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Fila de revisão',
      subtitle: 'Inspeções concluídas esperando aprovação',
      trailing: OutlinedButton(
          onPressed: () => Navigator.of(context).pushNamed(Routes.inspectionsWithStatus('COMPLETED')),
          child: const Text('Ver todas')),
      padding: EdgeInsets.zero,
      child: entries.isEmpty
          ? const Padding(padding: EdgeInsets.all(IcSpacing.s6), child: Text('Nenhuma inspeção aguardando revisão.'))
          : DataGridView(
              minWidth: 720,
              columns: const [
                GridColumn('OS', width: 72),
                GridColumn('Cliente', flex: 2.4),
                GridColumn('Inspetor', flex: 1.4),
                GridColumn('Não conf.', flex: 1),
                GridColumn('Aguardando', flex: 1),
                GridColumn('', width: 132),
              ],
              onRowTap: (i) => Navigator.of(context).pushNamed(Routes.inspection(entries[i].inspection.id)),
              rows: [
                for (final e in entries)
                  [
                    Text('${e.inspection.number}', style: IcText.mono()),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(e.inspection.clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                          e.inspection.finishedAt == null ? '' : 'Encerrada ${IcFormat.dayMonthTime(e.inspection.finishedAt!)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: IcColors.ink600)),
                    ]),
                    Text(e.inspection.inspector.name),
                    _NcCell(stats: e.inspection.stats),
                    Text(_wait(e.waitingMinutes),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: e.waitingMinutes > 12 * 60 ? IcColors.signal700 : IcColors.ink900)),
                    FilledButton(
                        onPressed: () => Navigator.of(context).pushNamed(Routes.inspection(e.inspection.id)),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                        child: const Text('Revisar')),
                  ],
              ],
            ),
    );
  }
}

/// Célula "Não conformidades": selo da maior criticidade + contagem restante, ou "Nenhuma".
class _NcCell extends StatelessWidget {
  const _NcCell({required this.stats});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.nonConforming == 0 || stats.maxCriticality == null) {
      return Text(stats.answered == 0 ? '—' : 'Nenhuma', style: const TextStyle(color: IcColors.ink600));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CriticalityBadge(stats.maxCriticality!),
      if (stats.nonConforming > 1) ...[
        const SizedBox(width: 6),
        Text('+${stats.nonConforming - 1}', style: Theme.of(context).textTheme.bodySmall),
      ],
    ]);
  }
}
