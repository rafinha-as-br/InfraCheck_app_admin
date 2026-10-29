import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

/// Painel branco com borda sutil e raio grande (`ic-panel` do design system).
class Panel extends StatelessWidget {
  const Panel({super.key, this.title, this.subtitle, this.trailing, required this.child, this.padding = const EdgeInsets.all(IcSpacing.s6)});

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  /// Use [EdgeInsets.zero] quando o conteúdo (ex.: tabela) vai de borda a borda.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: IcColors.surface0,
        borderRadius: BorderRadius.circular(IcRadius.lg),
        border: Border.all(color: IcColors.borderSubtle),
        boxShadow: IcShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(IcSpacing.s6, IcSpacing.s5, IcSpacing.s6, IcSpacing.s4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title!, style: t.titleLarge),
                  if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(color: IcColors.ink600)),
                ]),
              ),
              if (trailing != null) trailing!,
            ]),
          ),
        if (title != null) const Divider(),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

/// Indicador do dashboard (`ic-kpi`). [attention] destaca o único indicador que pede ação do gestor.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, this.help, this.attention = false, this.onHelpTap, this.progress});

  final String label;
  final String value;
  final String? help;
  final bool attention;
  final VoidCallback? onHelpTap;

  /// 0 a 1; mostra uma barra de progresso abaixo do valor.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(IcSpacing.s5),
      decoration: BoxDecoration(
        color: attention ? IcColors.signal100 : IcColors.surface0,
        borderRadius: BorderRadius.circular(IcRadius.lg),
        border: Border.all(color: attention ? IcColors.signal100 : IcColors.borderSubtle),
        boxShadow: IcShadows.sm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: t.labelSmall?.copyWith(color: attention ? IcColors.signal700 : IcColors.ink600)),
        const SizedBox(height: IcSpacing.s2),
        Text(value, style: t.displayMedium),
        if (progress != null) ...[
          const SizedBox(height: IcSpacing.s2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: progress!.clamp(0, 1), minHeight: 8, color: IcColors.primary700, backgroundColor: IcColors.surface100),
          ),
        ],
        if (help != null) ...[
          const SizedBox(height: IcSpacing.s2),
          onHelpTap == null
              ? Text(help!, style: t.bodySmall?.copyWith(color: IcColors.ink600))
              : InkWell(
                  onTap: onHelpTap,
                  child: Text(help!,
                      style: t.bodyMedium?.copyWith(
                          color: attention ? IcColors.signal700 : IcColors.primary700, fontWeight: FontWeight.w600)),
                ),
        ],
      ]),
    );
  }
}

/// Linha de barra horizontal (distribuição por status, carga de inspetores).
class BarRow extends StatelessWidget {
  const BarRow({super.key, required this.label, required this.value, required this.max, required this.color});

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: t.bodyMedium, overflow: TextOverflow.ellipsis)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: max == 0 ? 0 : value / max, minHeight: 10, color: color, backgroundColor: IcColors.surface100),
          ),
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.right, style: IcText.mono())),
      ]),
    );
  }
}

/// Coluna de [DataGridView].
class GridColumn {
  const GridColumn(this.title, {this.flex = 1, this.width});

  final String title;
  final double flex;

  /// Largura fixa (substitui [flex]).
  final double? width;
}

/// Tabela de listagem (visual do design system `ic-table`), com rolagem horizontal em telas estreitas.
class DataGridView extends StatelessWidget {
  const DataGridView({super.key, required this.columns, required this.rows, this.onRowTap, this.minWidth = 820});

  final List<GridColumn> columns;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;
  final double minWidth;

  Widget _cells(List<Widget> cells, {Color? background, VoidCallback? onTap, bool header = false}) {
    final row = Row(children: [
      for (var i = 0; i < columns.length; i++)
        if (columns[i].width != null)
          SizedBox(width: columns[i].width, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: cells[i]))
        else
          Expanded(
              flex: (columns[i].flex * 10).round(),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: cells[i])),
    ]);
    return Material(
      color: background ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: IcColors.primary50,
        child: Container(
          constraints: BoxConstraints(minHeight: header ? 40 : 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: IcColors.borderSubtle))),
          alignment: Alignment.centerLeft,
          child: row,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth < minWidth ? minWidth : c.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(children: [
            _cells([for (final col in columns) Text(col.title.toUpperCase(), style: t.labelSmall?.copyWith(color: IcColors.ink600))],
                background: IcColors.surface100, header: true),
            for (var i = 0; i < rows.length; i++) _cells(rows[i], onTap: onRowTap == null ? null : () => onRowTap!(i)),
          ]),
        ),
      );
    });
  }
}

/// Mensagem de carregamento/erro padronizada das telas.
class StateMessage extends StatelessWidget {
  const StateMessage({super.key, this.loading = false, this.error, this.onRetry, this.emptyText});

  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(padding: EdgeInsets.all(IcSpacing.s10), child: Center(child: CircularProgressIndicator()));
    }
    return Padding(
      padding: const EdgeInsets.all(IcSpacing.s8),
      child: Column(children: [
        if (error != null) IcNotice(kind: NoticeKind.danger, title: 'Não foi possível carregar.', message: error!),
        if (emptyText != null) Text(emptyText!, style: Theme.of(context).textTheme.bodyLarge),
        if (onRetry != null) ...[
          const SizedBox(height: IcSpacing.s4),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
        ],
      ]),
    );
  }
}

/// Rótulo + valor em duas colunas (`ic-kv`), usado nos painéis laterais de detalhe.
class KeyValueList extends StatelessWidget {
  const KeyValueList(this.entries, {super.key});

  final List<(String, Widget)> entries;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      for (final (k, v) in entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(k, style: t.bodySmall?.copyWith(color: IcColors.ink600))),
            Expanded(child: v),
          ]),
        ),
    ]);
  }
}
