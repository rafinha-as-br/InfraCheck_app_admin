import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/session.dart';
import '../routes.dart';
import '../widgets/app_shell.dart';
import '../widgets/common.dart';
import 'inspection_list_controller.dart';
import 'new_inspection_dialog.dart';

/// W03 — Gestão de inspeções: filtros por status, busca, tabela paginada e criação de OS.
class InspectionsPage extends StatefulWidget {
  const InspectionsPage({super.key, this.initialStatus});

  final InspectionStatus? initialStatus;

  @override
  State<InspectionsPage> createState() => _InspectionsPageState();
}

class _InspectionsPageState extends State<InspectionsPage> {
  InspectionListController? _controller;
  final _search = TextEditingController();
  Timer? _debounce;
  String? _created;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= InspectionListController(AppScope.of(context).api, initialStatus: widget.initialStatus)..init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _controller!.setQuery(v));
  }

  Future<void> _openNew() async {
    final created = await showDialog<InspectionDetail>(context: context, builder: (_) => const NewInspectionDialog());
    if (created != null && mounted) {
      setState(() => _created = 'OS ${created.number} criada e atribuída a ${created.inspector.name}.');
      _controller!.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller!;
    return AppShell(
      current: NavDestination.inspections,
      title: 'Inspeções',
      subtitle: 'Programar, atribuir e acompanhar as ordens de serviço',
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final s = c.state;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_created != null) ...[
              IcNotice(
                  kind: NoticeKind.ok,
                  title: _created!,
                  message: 'Ela aparece no aplicativo do inspetor como Pendente.'),
              const SizedBox(height: IcSpacing.s4),
            ],
            _FilterBar(state: s, controller: c, onNew: _openNew),
            const SizedBox(height: IcSpacing.s4),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(IcSpacing.s4),
                  child: Wrap(spacing: IcSpacing.s3, runSpacing: IcSpacing.s3, children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _search,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                            hintText: 'Buscar por OS, cliente ou inspetor', prefixIcon: Icon(Icons.search), isDense: true),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String?>(
                        initialValue: s.inspectorId,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos os inspetores')),
                          for (final i in s.inspectors) DropdownMenuItem(value: i.id, child: Text(i.name)),
                        ],
                        onChanged: c.setInspector,
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<InspectionType?>(
                        initialValue: s.type,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos os tipos')),
                          for (final t in InspectionType.values) DropdownMenuItem(value: t, child: Text(t.label)),
                        ],
                        onChanged: c.setType,
                      ),
                    ),
                  ]),
                ),
                const Divider(),
                _Results(state: s, controller: c),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state, required this.controller, required this.onNew});

  final InspectionListState state;
  final InspectionListController controller;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int? count, InspectionStatus? value) {
      final selected = state.status == value;
      return FilterChip(
        selected: selected,
        onSelected: (_) => controller.setStatus(value),
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text('$count', style: IcText.mono(size: 12, color: selected ? IcColors.primary700 : IcColors.ink600)),
          ],
        ]),
        side: BorderSide(color: selected ? IcColors.primary700 : IcColors.borderStrong, width: selected ? 2 : 1),
        selectedColor: IcColors.primary100,
        backgroundColor: IcColors.surface0,
      );
    }

    return Wrap(spacing: IcSpacing.s2, runSpacing: IcSpacing.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
      chip('Todas', state.counts.isEmpty ? null : state.totalCount, null),
      for (final s in InspectionStatus.values) chip(s.label, state.counts[s], s),
      const SizedBox(width: IcSpacing.s4),
      FilledButton.icon(onPressed: onNew, icon: const Icon(Icons.add), label: const Text('Nova inspeção')),
    ]);
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.controller});

  final InspectionListState state;
  final InspectionListController controller;

  @override
  Widget build(BuildContext context) {
    final r = state.result;
    final page = r.data;
    if (page == null) return StateMessage(loading: r.loading, error: r.error, onRetry: controller.refresh);
    if (page.content.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(IcSpacing.s10),
        child: Column(children: [
          Text('Nenhuma inspeção encontrada', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: IcSpacing.s2),
          const Text('Ajuste os filtros ou a busca para ver resultados.'),
          const SizedBox(height: IcSpacing.s4),
          OutlinedButton(
              onPressed: () {
                controller
                  ..setStatus(null)
                  ..setInspector(null)
                  ..setType(null)
                  ..setQuery('');
              },
              child: const Text('Limpar filtros')),
        ]),
      );
    }
    final t = Theme.of(context).textTheme;
    final from = page.page * page.size + 1;
    final to = from + page.content.length - 1;
    return Column(children: [
      if (r.error != null) Padding(padding: const EdgeInsets.all(IcSpacing.s4), child: IcNotice(kind: NoticeKind.danger, message: r.error!)),
      DataGridView(
        minWidth: 980,
        columns: const [
          GridColumn('OS', width: 72),
          GridColumn('Cliente', flex: 2.6),
          GridColumn('Tipo', flex: 1.6),
          GridColumn('Inspetor', flex: 1.4),
          GridColumn('Previsão', flex: 1.3),
          GridColumn('Status', flex: 1.7),
          GridColumn('Não conf.', flex: 1.2),
        ],
        onRowTap: (i) => Navigator.of(context).pushNamed(Routes.inspection(page.content[i].id)),
        rows: [
          for (final i in page.content)
            [
              Text('${i.number}', style: IcText.mono()),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(i.clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(i.address, style: t.bodySmall?.copyWith(color: IcColors.ink600), overflow: TextOverflow.ellipsis),
              ]),
              Text(i.type.label),
              Text(i.inspector.name),
              Text(IcFormat.scheduled(i.scheduledDate, i.shift)),
              Wrap(spacing: 6, runSpacing: 4, children: [if (i.urgent) const UrgentBadge(), StatusBadge(i.status)]),
              i.stats.nonConforming == 0 || i.stats.maxCriticality == null
                  ? const Text('—', style: TextStyle(color: IcColors.ink600))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      CriticalityBadge(i.stats.maxCriticality!),
                      if (i.stats.nonConforming > 1) ...[
                        const SizedBox(width: 6),
                        Text('+${i.stats.nonConforming - 1}', style: t.bodySmall),
                      ],
                    ]),
            ],
        ],
      ),
      Padding(
        padding: const EdgeInsets.all(IcSpacing.s4),
        child: Row(children: [
          Expanded(child: Text('Mostrando $from–$to de ${page.total} inspeções', style: t.bodySmall?.copyWith(color: IcColors.ink600))),
          OutlinedButton(onPressed: state.page > 0 ? controller.previousPage : null, child: const Text('Anterior')),
          const SizedBox(width: IcSpacing.s2),
          OutlinedButton(onPressed: to < page.total ? controller.nextPage : null, child: const Text('Próxima')),
        ]),
      ),
    ]);
  }
}
