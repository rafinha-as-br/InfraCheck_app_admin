import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/session.dart';
import '../routes.dart';

/// W01 — Login do painel (gestores de contrato e administradores).
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final form = const Center(
            child: Padding(padding: EdgeInsets.all(IcSpacing.s6), child: SingleChildScrollView(child: _LoginCard())));
        if (!wide) return form;
        return Row(children: [
          const Expanded(flex: 11, child: _Hero()),
          Expanded(flex: 9, child: ColoredBox(color: IcColors.surface50, child: form)),
        ]);
      }),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget bullet(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: IcSpacing.s4),
          child: Row(children: [
            Icon(icon, color: IcColors.signal500, size: 22),
            const SizedBox(width: IcSpacing.s3),
            Expanded(child: Text(text, style: t.bodyLarge?.copyWith(color: IcColors.onPrimaryMuted))),
          ]),
        );
    return Stack(children: [
      const Positioned.fill(child: FramePattern()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 56),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IcLogo(LogoVariant.horizontalReverse, height: 44),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Inspeção registrada. Relatório no prazo.',
                  style: t.displayMedium?.copyWith(color: IcColors.onPrimary, fontSize: 52, height: 1.08)),
              const SizedBox(height: IcSpacing.s8),
              bullet(Icons.place_outlined, 'Evidências com data, hora e localização de cada visita'),
              bullet(Icons.verified_user_outlined, 'Aprovação com trilha de auditoria completa'),
              bullet(Icons.description_outlined, 'Relatório em PDF em até 24 horas após o encerramento'),
            ]),
          ),
          const Spacer(),
          Text('InfraCheck Inspeções e Manutenção Industrial Ltda · São Paulo/SP',
              style: t.bodySmall?.copyWith(color: IcColors.onPrimaryMuted)),
        ]),
      ),
    ]);
  }
}

class _LoginCard extends StatefulWidget {
  const _LoginCard();

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = AppScope.of(context);
    final navigator = Navigator.of(context);
    final error = await session.login(_email.text.trim(), _password.text, remember: _remember);
    if (!mounted) return;
    if (error == null) {
      navigator.pushNamedAndRemoveUntil(Routes.dashboard, (_) => false);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: IcColors.surface0,
          borderRadius: BorderRadius.circular(IcRadius.xl),
          border: Border.all(color: IcColors.borderSubtle),
          boxShadow: IcShadows.md,
        ),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Entrar no painel', style: t.headlineMedium),
            const SizedBox(height: 6),
            Text('Acesso para gestores de contrato e administradores.',
                style: t.bodyMedium?.copyWith(color: IcColors.ink600)),
            const SizedBox(height: IcSpacing.s5),
            if (_error != null) ...[
              IcNotice(kind: NoticeKind.danger, title: 'Não foi possível entrar.', message: _error!),
              const SizedBox(height: IcSpacing.s4),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              validator: _required,
              decoration: const InputDecoration(labelText: 'E-mail corporativo', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: IcSpacing.s4),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              validator: _required,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock_outline)),
            ),
            const SizedBox(height: IcSpacing.s3),
            CheckboxListTile(
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? false),
              title: const Text('Manter conectado neste computador'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: IcSpacing.s2),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Entrar'),
            ),
            const SizedBox(height: IcSpacing.s5),
            const Divider(),
            const SizedBox(height: IcSpacing.s5),
            const IcNotice(
                kind: NoticeKind.info,
                message: 'Inspetores acessam o aplicativo InfraCheck no celular.',
                icon: Icons.smartphone),
          ]),
        ),
      ),
    );
  }
}
