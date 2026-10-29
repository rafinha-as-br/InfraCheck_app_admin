import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/session.dart';
import '../routes.dart';
import '../widgets/app_shell.dart';
import '../widgets/common.dart';
import 'detail_tabs.dart';
import 'inspection_detail_controller.dart';

/// W04 — Detalhes e aprovação: resumo da execução, evidências, checklist, histórico e decisão do gestor.
class InspectionDetailPage extends StatefulWidget {
  const InspectionDetailPage({super.key, required this.inspectionId});

  final String inspectionId;

  @override
  State<InspectionDetailPage> createState() => _InspectionDetailPageState();
}

enum _Tab { evidence, checklist, history }

class _InspectionDetailPageState extends State<InspectionDetailPage> {
  InspectionDetailController? _controller;
  _Tab _tab = _Tab.evidence;
  bool _rejecting = false;
  final _reason = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= InspectionDetailController(AppScope.of(context).api, widget.inspectionId)..load();
  }

  @override
  void dispose() {
    _reason.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    final ok = await _controller!.approve();
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspeção aprovada. O relatório em PDF será gerado em seguida.')));
    }
  }

  Future<void> _confirmReject() async {
    final ok = await _controller!.reject(_reason.text.trim());
    if (ok && mounted) setState(() => _rejecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller!;
    return AppShell(
      current: NavDestination.inspections,
      title: 'Inspeções',
      subtitle: 'Revisão e aprovação',
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final s = c.state;
          if (!s.hasData) return StateMessage(loading: s.loading, error: s.error, onRetry: c.load);
          final d = s.data!;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Breadcrumb(number: d.number),
            const SizedBox(height: IcSpacing.s4),
            _Header(inspection: d, controller: c, onApprove: _approve, onReject: () => setState(() => _rejecting = true)),
            const SizedBox(height: IcSpacing.s4),
            if (d.status == InspectionStatus.approved)
              IcNotice(
                  kind: NoticeKind.ok,
                  title: 'Inspeção aprovada${d.reviewedBy != null ? ' por ${d.reviewedBy}' : ''}${d.reviewedAt != null ? ' às ${IcFormat.time(d.reviewedAt!)}' : ''}.',
                  message: 'O relatório em PDF será gerado a partir dos dados aprovados.'),
            if (d.status == InspectionStatus.rejected)
              IcNotice(
                  kind: NoticeKind.danger,
                  title: 'Inspeção rejeitada.',
                  message: '${d.inspector.name} foi notificado para corrigir e reenviar. Motivo: ${d.reviewComment ?? '—'}'),
            if (c.actionError != null) ...[
              const SizedBox(height: IcSpacing.s3),
              IcNotice(kind: NoticeKind.danger, title: 'Não foi possível concluir a ação.', message: c.actionError!),
            ],
            if (_rejecting && d.status == InspectionStatus.completed) ...[
              const SizedBox(height: IcSpacing.s4),
              _RejectPanel(
                reason: _reason,
                busy: c.busy,
                onCancel: () => setState(() => _rejecting = false),
                onConfirm: _confirmReject,
              ),
            ],
            const SizedBox(height: IcSpacing.s4),
            _StatsRow(stats: d.stats),
            const SizedBox(height: IcSpacing.s6),
            LayoutBuilder(builder: (context, constraints) {
              final main = _Main(
                inspection: d,
                tab: _tab,
                onTab: (t) => setState(() => _tab = t),
                busy: c.busy,
                onSavePlan: (item, r, due, a) => c.savePlan(itemId: item, responsible: r, dueDate: due, action: a),
              );
              final side = _SidePanels(inspection: d);
              if (constraints.maxWidth < 1000) return Column(children: [main, const SizedBox(height: IcSpacing.s6), side]);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 68, child: main),
                const SizedBox(width: IcSpacing.s6),
                Expanded(flex: 32, child: side),
              ]);
            }),
          ]);
        },
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(children: [
      InkWell(
          onTap: () => Navigator.of(context).pushReplacementNamed(Routes.inspections),
          child: Text('Inspeções', style: t.bodyMedium?.copyWith(color: IcColors.primary700, fontWeight: FontWeight.w600))),
      Text('  /  ', style: t.bodyMedium?.copyWith(color: IcColors.ink600)),
      Text('OS $number', style: t.bodyMedium),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.inspection, required this.controller, required this.onApprove, required this.onReject});

  final InspectionDetail inspection;
  final InspectionDetailController controller;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final d = inspection;
    final t = Theme.of(context).textTheme;
    final missing = controller.itemsMissingPlan;
    final pending = d.status == InspectionStatus.completed;
    return Panel(
      child: Wrap(spacing: IcSpacing.s6, runSpacing: IcSpacing.s4, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: IcSpacing.s3, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('OS ${d.number} · ${d.contract.clientName}', style: t.titleLarge),
            if (d.urgent) const UrgentBadge(),
            StatusBadge(d.status, label: pending ? 'Concluída · aguardando revisão' : null),
          ]),
          const SizedBox(height: 4),
          Text('${d.type.label} · ${d.checklistCode} · ${d.contract.address}', style: t.bodyMedium?.copyWith(color: IcColors.ink600)),
        ]),
        if (pending)
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton.icon(
                onPressed: controller.busy ? null : onReject,
                icon: const Icon(Icons.close),
                label: const Text('Rejeitar'),
                style: OutlinedButton.styleFrom(foregroundColor: IcColors.danger700, side: const BorderSide(color: IcColors.danger700)),
              ),
              const SizedBox(width: IcSpacing.s3),
              FilledButton.icon(
                onPressed: controller.busy || missing.isNotEmpty ? null : onApprove,
                icon: const Icon(Icons.check),
                label: const Text('Aprovar inspeção'),
              ),
            ]),
            if (missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    'Registre o plano de ação do item ${missing.map((i) => i.itemNo.toString().padLeft(2, '0')).join(', ')} '
                    '(criticidade ${missing.first.criticality!.label}) para aprovar.',
                    style: t.bodySmall?.copyWith(color: IcColors.signal700)),
              ),
          ]),
      ]),
    );
  }
}

class _RejectPanel extends StatelessWidget {
  const _RejectPanel({required this.reason, required this.busy, required this.onCancel, required this.onConfirm});

  final TextEditingController reason;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rejeitar e pedir correção', style: t.titleMedium),
        const SizedBox(height: IcSpacing.s3),
        ListenableBuilder(
          listenable: reason,
          builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: reason,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                  labelText: 'Motivo (obrigatório, o inspetor verá no aplicativo)',
                  hintText: 'Ex.: a foto do item 12 está ilegível'),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(onPressed: onCancel, child: const Text('Cancelar')),
              const SizedBox(width: IcSpacing.s3),
              FilledButton(
                onPressed: busy || reason.text.trim().isEmpty ? null : onConfirm,
                style: FilledButton.styleFrom(backgroundColor: IcColors.danger700),
                child: const Text('Confirmar rejeição'),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget cell(String label, String value) => Container(
          width: 150,
          padding: const EdgeInsets.all(IcSpacing.s4),
          decoration: BoxDecoration(
              color: IcColors.surface0,
              borderRadius: BorderRadius.circular(IcRadius.md),
              border: Border.all(color: IcColors.borderSubtle)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: t.labelSmall?.copyWith(color: IcColors.ink600)),
            const SizedBox(height: 4),
            Text(value, style: t.titleLarge),
          ]),
        );
    return Wrap(spacing: IcSpacing.s3, runSpacing: IcSpacing.s3, children: [
      cell('Itens', '${stats.total}'),
      cell('Conformes', '${stats.conforming}'),
      cell('Não conformes', '${stats.nonConforming}'),
      cell('Conformidade', IcFormat.percent(stats.conformityPercent)),
      cell('Fotos', '${stats.photos}'),
      cell('Criticidade máx.', stats.maxCriticality?.label ?? '—'),
    ]);
  }
}

class _Main extends StatelessWidget {
  const _Main({required this.inspection, required this.tab, required this.onTab, required this.busy, required this.onSavePlan});

  final InspectionDetail inspection;
  final _Tab tab;
  final ValueChanged<_Tab> onTab;
  final bool busy;
  final Future<bool> Function(String itemId, String responsible, DateTime due, String action) onSavePlan;

  @override
  Widget build(BuildContext context) {
    Widget tabButton(_Tab value, String label, {int? count}) {
      final selected = tab == value;
      return InkWell(
        onTap: () => onTab(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: IcSpacing.s4, vertical: IcSpacing.s3),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? IcColors.signal500 : Colors.transparent, width: 3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? IcColors.primary700 : IcColors.ink700)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text('$count', style: IcText.mono(size: 12, color: IcColors.ink600)),
            ],
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: IcColors.borderSubtle))),
        child: Row(children: [
          tabButton(_Tab.evidence, 'Evidências', count: inspection.nonConformingItems.length),
          tabButton(_Tab.checklist, 'Checklist', count: inspection.items.length),
          tabButton(_Tab.history, 'Histórico'),
        ]),
      ),
      const SizedBox(height: IcSpacing.s4),
      switch (tab) {
        _Tab.evidence => EvidenceTab(
            inspection: inspection,
            canPlan: inspection.status == InspectionStatus.completed,
            busy: busy,
            onSavePlan: onSavePlan),
        _Tab.checklist => ChecklistTab(items: inspection.items),
        _Tab.history => HistoryTab(events: inspection.events),
      },
    ]);
  }
}

class _SidePanels extends StatelessWidget {
  const _SidePanels({required this.inspection});

  final InspectionDetail inspection;

  @override
  Widget build(BuildContext context) {
    final d = inspection;
    final t = Theme.of(context).textTheme;
    final api = AppScope.of(context).api;
    String point(GeoPoint? g) => g == null
        ? '—'
        : '${IcFormat.coordinates(g.lat, g.lng)}${g.accuracy != null ? ' · ±${g.accuracy!.round()} m' : ''}';
    return Column(children: [
      Panel(
        title: 'Execução',
        child: KeyValueList([
          ('Inspetor', Text('${d.inspector.name}${d.inspector.registration != null ? '  ${d.inspector.registration}' : ''}')),
          ('Previsão', Text(IcFormat.scheduled(d.scheduledDate, d.shift))),
          ('Início', Text(d.startedAt == null ? '—' : IcFormat.dayMonthTime(d.startedAt!))),
          ('Encerramento', Text(d.finishedAt == null ? '—' : IcFormat.dayMonthTime(d.finishedAt!))),
          ('Duração', Text(d.duration == null ? '—' : IcFormat.duration(d.duration!))),
          ('Gestor', Text(d.manager.name)),
        ]),
      ),
      const SizedBox(height: IcSpacing.s4),
      Panel(
        title: 'Localização',
        child: KeyValueList([
          ('Início', Text(point(d.startLocation), style: IcText.mono(size: 12))),
          ('Fim', Text(point(d.endLocation), style: IcText.mono(size: 12))),
        ]),
      ),
      const SizedBox(height: IcSpacing.s4),
      Panel(
        title: 'Assinatura do inspetor',
        child: d.hasSignature
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                      color: IcColors.surface0,
                      borderRadius: BorderRadius.circular(IcRadius.md),
                      border: Border.all(color: IcColors.borderSubtle)),
                  child: ApiImage(cacheKey: 'sig-${d.id}-${d.finishedAt?.millisecondsSinceEpoch}', loader: () => api.signatureBytes(d.id), fit: BoxFit.contain),
                ),
                const SizedBox(height: 6),
                Text(
                    'Assinado digitalmente${d.finishedAt != null ? ' em ${IcFormat.dayMonthTime(d.finishedAt!)}' : ''} por ${d.inspector.name}.',
                    style: t.bodySmall?.copyWith(color: IcColors.ink600)),
              ])
            : Text('Ainda não assinada.', style: t.bodyMedium),
      ),
      const SizedBox(height: IcSpacing.s4),
      Panel(
        title: 'Cliente',
        child: KeyValueList([
          ('Contrato', Text(d.contract.code, style: IcText.mono(size: 13))),
          ('Responsável', Text(d.contract.responsibleName ?? '—')),
          ('Segmento', Text(d.contract.segment ?? '—')),
          if (d.notes != null) ('Observação prévia', Text(d.notes!)),
        ]),
      ),
    ]);
  }
}
