import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/session.dart';

/// Modal "Nova inspeção": escolhe contrato, tipo, checklist, inspetor (com a carga do dia), data e turno.
/// Fecha devolvendo a [InspectionDetail] criada, ou `null` se cancelado.
class NewInspectionDialog extends StatefulWidget {
  const NewInspectionDialog({super.key});

  @override
  State<NewInspectionDialog> createState() => _NewInspectionDialogState();
}

class _NewInspectionDialogState extends State<NewInspectionDialog> {
  final _notes = TextEditingController();
  List<Contract> _contracts = const [];
  List<Checklist> _checklists = const [];
  List<InspectorOption> _inspectors = const [];

  Contract? _contract;
  Checklist? _checklist;
  InspectorOption? _inspector;
  InspectionType _type = InspectionType.preventive;
  Shift _shift = Shift.morning;
  DateTime _date = DateTime.now().add(const Duration(days: 1));

  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    try {
      final results = await Future.wait([api.contracts(), api.checklists(), api.inspectors()]);
      if (!mounted) return;
      setState(() {
        _contracts = results[0] as List<Contract>;
        _checklists = results[1] as List<Checklist>;
        _inspectors = results[2] as List<InspectorOption>;
        _contract = _contracts.firstOrNull;
        _checklist = _checklists.firstOrNull;
        _inspector = _inspectors.firstOrNull;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.fullMessage;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_contract == null || _checklist == null || _inspector == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await AppScope.of(context).api.createInspection(
            contractId: _contract!.id,
            checklistId: _checklist!.id,
            inspectorId: _inspector!.id,
            type: _type,
            scheduledDate: _date,
            shift: _shift,
            notes: _notes.text,
          );
      if (mounted) Navigator.of(context).pop(created);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.fullMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: IcColors.surface0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(IcRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(IcSpacing.s6),
          child: _loading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text('Nova inspeção', style: t.titleLarge)),
                      IconButton(tooltip: 'Fechar', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ]),
                    const SizedBox(height: IcSpacing.s4),
                    if (_error != null) ...[
                      IcNotice(kind: NoticeKind.danger, title: 'Não foi possível criar a OS.', message: _error!),
                      const SizedBox(height: IcSpacing.s4),
                    ],
                    _labeled('Cliente e contrato', DropdownButtonFormField<Contract>(
                      initialValue: _contract,
                      isExpanded: true,
                      items: [for (final c in _contracts) DropdownMenuItem(value: c, child: Text('${c.clientName} · ${c.code}', overflow: TextOverflow.ellipsis))],
                      onChanged: (v) => setState(() => _contract = v),
                    )),
                    _labeled('Tipo de inspeção', DropdownButtonFormField<InspectionType>(
                      initialValue: _type,
                      isExpanded: true,
                      items: [for (final v in InspectionType.values) DropdownMenuItem(value: v, child: Text(v.label))],
                      onChanged: (v) => setState(() => _type = v ?? _type),
                    )),
                    _labeled('Checklist', DropdownButtonFormField<Checklist>(
                      initialValue: _checklist,
                      isExpanded: true,
                      items: [for (final c in _checklists) DropdownMenuItem(value: c, child: Text('${c.code} · ${c.itemCount} itens'))],
                      onChanged: (v) => setState(() => _checklist = v),
                    )),
                    _labeled('Inspetor', DropdownButtonFormField<InspectorOption>(
                      initialValue: _inspector,
                      isExpanded: true,
                      items: [for (final i in _inspectors) DropdownMenuItem(value: i, child: Text('${i.name} · ${i.todayCount} OS hoje'))],
                      onChanged: (v) => setState(() => _inspector = v),
                    ), help: 'Mostra a carga do dia para distribuir melhor.'),
                    _labeled(
                      'Data prevista',
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today_outlined, size: 18),
                            label: Align(alignment: Alignment.centerLeft, child: Text(IcFormat.date(_date))),
                          ),
                        ),
                        const SizedBox(width: IcSpacing.s3),
                        SizedBox(
                          width: 160,
                          child: DropdownButtonFormField<Shift>(
                            initialValue: _shift,
                            items: [for (final v in Shift.values) DropdownMenuItem(value: v, child: Text(v.label))],
                            onChanged: (v) => setState(() => _shift = v ?? _shift),
                          ),
                        ),
                      ]),
                    ),
                    _labeled('Observações prévias', TextField(
                      controller: _notes,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(hintText: 'Ex.: o cliente pediu atenção especial ao quadro elétrico do subsolo'),
                    )),
                    const SizedBox(height: IcSpacing.s2),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      OutlinedButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                      const SizedBox(width: IcSpacing.s3),
                      FilledButton.icon(
                        onPressed: _saving || _contract == null || _checklist == null || _inspector == null ? null : _save,
                        icon: const Icon(Icons.check),
                        label: const Text('Atribuir inspeção'),
                      ),
                    ]),
                  ]),
                ),
        ),
      ),
    );
  }

  Widget _labeled(String label, Widget field, {String? help}) => Padding(
        padding: const EdgeInsets.only(bottom: IcSpacing.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: IcColors.ink700)),
          const SizedBox(height: 6),
          field,
          if (help != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(help, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: IcColors.ink600))),
        ]),
      );
}
