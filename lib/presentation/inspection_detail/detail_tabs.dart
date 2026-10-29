import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/session.dart';
import '../widgets/common.dart';

/// Aba "Evidências": cada não conformidade com fotos (data, hora e GPS), situação, ação recomendada e
/// plano de ação. O gestor nunca edita evidências; só registra o plano de ação.
class EvidenceTab extends StatelessWidget {
  const EvidenceTab({super.key, required this.inspection, required this.canPlan, required this.busy, required this.onSavePlan});

  final InspectionDetail inspection;

  /// Planos só podem ser registrados enquanto a inspeção aguarda revisão.
  final bool canPlan;
  final bool busy;
  final Future<bool> Function(String itemId, String responsible, DateTime due, String action) onSavePlan;

  @override
  Widget build(BuildContext context) {
    final items = inspection.nonConformingItems;
    if (items.isEmpty) {
      return const Panel(child: Text('Nenhuma não conformidade registrada nesta inspeção.'));
    }
    return Column(children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: IcSpacing.s4),
          child: _EvidenceCard(
              inspectionId: inspection.id, item: item, canPlan: canPlan, busy: busy, onSavePlan: onSavePlan),
        ),
    ]);
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.inspectionId, required this.item, required this.canPlan, required this.busy, required this.onSavePlan});

  final String inspectionId;
  final InspectionItem item;
  final bool canPlan;
  final bool busy;
  final Future<bool> Function(String itemId, String responsible, DateTime due, String action) onSavePlan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final api = AppScope.of(context).api;
    final crit = item.criticality;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Item ${item.itemNo.toString().padLeft(2, '0')}', style: IcText.mono(size: 12, color: IcColors.ink600)),
              Text(item.statement, style: t.titleMedium),
              if (item.location != null)
                Row(children: [
                  const Icon(Icons.place_outlined, size: 16, color: IcColors.ink600),
                  const SizedBox(width: 4),
                  Text(item.location!, style: t.bodySmall?.copyWith(color: IcColors.ink600)),
                ]),
            ]),
          ),
          if (crit != null) CriticalityBadge(crit),
        ]),
        const SizedBox(height: IcSpacing.s4),
        Wrap(spacing: IcSpacing.s3, runSpacing: IcSpacing.s3, children: [
          for (final p in item.photos)
            SizedBox(
              width: 240,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(IcRadius.md),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ApiImage(
                        cacheKey: 'photo-${p.id}',
                        loader: () => api.photoBytes(p.id),
                        semanticLabel: 'Foto do item ${item.itemNo}'),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                    '${IcFormat.dayMonthTime(p.capturedAt)}${p.lat != null && p.lng != null ? ' · ${IcFormat.coordinates(p.lat!, p.lng!)}' : ''}',
                    style: IcText.mono(size: 11, color: IcColors.ink600)),
              ]),
            ),
        ]),
        const SizedBox(height: IcSpacing.s4),
        KeyValueList([
          ('Situação encontrada', Text(item.description ?? '—')),
          ('Ação recomendada', Text(item.recommendedAction ?? '—')),
        ]),
        const Divider(height: IcSpacing.s6),
        if (item.actionPlans.isNotEmpty)
          for (final plan in item.actionPlans) _PlanSummary(plan: plan)
        else if (canPlan)
          _PlanForm(required: crit?.requiresActionPlan ?? false, busy: busy, onSave: (r, d, a) => onSavePlan(item.id, r, d, a))
        else
          Text('Sem plano de ação registrado.', style: t.bodySmall?.copyWith(color: IcColors.ink600)),
      ]),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan});

  final ActionPlan plan;

  @override
  Widget build(BuildContext context) {
    return IcNotice(
      kind: NoticeKind.ok,
      title: 'Plano de ação registrado.',
      message: 'Responsável: ${plan.responsible} · Prazo: ${IcFormat.date(plan.dueDate)}\n${plan.action}',
      icon: Icons.assignment_turned_in_outlined,
    );
  }
}

/// Formulário do plano de ação (responsável, prazo e ação).
class _PlanForm extends StatefulWidget {
  const _PlanForm({required this.required, required this.busy, required this.onSave});

  final bool required;
  final bool busy;
  final Future<bool> Function(String responsible, DateTime due, String action) onSave;

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  final _key = GlobalKey<FormState>();
  final _responsible = TextEditingController();
  final _action = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _responsible.dispose();
    _action.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context, initialDate: _due, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() => _due = d);
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Form(
      key: _key,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Plano de ação', style: t.titleMedium),
          const SizedBox(width: IcSpacing.s3),
          if (widget.required)
            Text('Obrigatório para aprovar', style: t.bodySmall?.copyWith(color: IcColors.signal700, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: IcSpacing.s3),
        Wrap(spacing: IcSpacing.s3, runSpacing: IcSpacing.s3, children: [
          SizedBox(
              width: 320,
              child: TextFormField(
                  controller: _responsible, validator: _req, decoration: const InputDecoration(labelText: 'Responsável pela correção'))),
          SizedBox(
            width: 200,
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              label: Text('Prazo: ${IcFormat.date(_due)}'),
            ),
          ),
        ]),
        const SizedBox(height: IcSpacing.s3),
        TextFormField(controller: _action, validator: _req, maxLines: 3, decoration: const InputDecoration(labelText: 'Ação')),
        const SizedBox(height: IcSpacing.s3),
        FilledButton.icon(
          onPressed: widget.busy
              ? null
              : () {
                  if (_key.currentState!.validate()) widget.onSave(_responsible.text.trim(), _due, _action.text.trim());
                },
          icon: const Icon(Icons.check),
          label: const Text('Salvar plano de ação'),
        ),
      ]),
    );
  }
}

/// Aba "Checklist": todos os itens com resultado e criticidade.
class ChecklistTab extends StatelessWidget {
  const ChecklistTab({super.key, required this.items});

  final List<InspectionItem> items;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        DataGridView(
          minWidth: 720,
          columns: const [
            GridColumn('Nº', width: 56),
            GridColumn('Item', flex: 3),
            GridColumn('Local', flex: 1.8),
            GridColumn('Resultado', flex: 1.4),
            GridColumn('Criticidade', flex: 1.2),
          ],
          rows: [
            for (final i in items)
              [
                Text(i.itemNo.toString().padLeft(2, '0'), style: IcText.mono()),
                Text(i.statement),
                Text(i.location ?? '—'),
                i.result == null ? const Text('—') : ResultBadge(i.result!),
                i.criticality == null ? const Text('—', style: TextStyle(color: IcColors.ink600)) : CriticalityBadge(i.criticality!),
              ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(IcSpacing.s3),
          child: Text('${items.length} itens', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: IcColors.ink600)),
        ),
      ]),
    );
  }
}

/// Aba "Histórico": trilha de auditoria (criação, atribuição, início em campo, sincronização, revisão).
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key, required this.events});

  final List<TimelineEvent> events;

  static String _title(EventType t) => switch (t) {
        EventType.created => 'OS criada e atribuída',
        EventType.started => 'Inspeção iniciada',
        EventType.submitted => 'Inspeção encerrada e assinada',
        EventType.synced => 'Sincronizada ao reconectar',
        EventType.actionPlanSaved => 'Plano de ação registrado',
        EventType.approved => 'Aprovada',
        EventType.rejected => 'Rejeitada e devolvida ao inspetor',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Panel(
      child: Column(children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 24,
                child: Column(children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch (events[i].type) {
                        EventType.approved => IcColors.success700,
                        EventType.rejected => IcColors.danger700,
                        EventType.synced => IcColors.warning700,
                        _ => IcColors.primary700,
                      },
                    ),
                  ),
                  if (i < events.length - 1) Expanded(child: Container(width: 2, color: IcColors.borderSubtle)),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: IcSpacing.s5),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_title(events[i].type), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                        [
                          if (events[i].actor != null) events[i].actor!,
                          IcFormat.dayMonthTime(events[i].occurredAt),
                          if (events[i].location != null)
                            'GPS ${IcFormat.coordinates(events[i].location!.lat, events[i].location!.lng)}'
                                '${events[i].location!.accuracy != null ? ' (±${events[i].location!.accuracy!.round()} m)' : ''}',
                        ].join(' · '),
                        style: t.bodySmall?.copyWith(color: IcColors.ink600)),
                    if (events[i].detail != null && events[i].detail != _title(events[i].type))
                      Text(events[i].detail!, style: t.bodySmall),
                  ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
