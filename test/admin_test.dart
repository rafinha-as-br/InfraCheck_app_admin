import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infracheck_admin/core/session.dart';
import 'package:infracheck_admin/presentation/inspection_detail/inspection_detail_controller.dart';
import 'package:infracheck_modules/infracheck_modules.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _user(String role) =>
    {'id': 'u1', 'name': 'Helena Prado', 'email': 'h@x.com', 'role': role, 'registration': null};

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> _detail({required List<Map<String, dynamic>> items}) => {
      'id': 'i1',
      'number': 1047,
      'status': 'COMPLETED',
      'type': 'PREVENTIVE',
      'urgent': false,
      'scheduledDate': '2025-06-12',
      'shift': 'MORNING',
      'notes': null,
      'contract': {'id': 'c', 'code': 'CT', 'clientName': 'Cliente', 'address': 'Rua', 'segment': null, 'responsibleName': null},
      'checklistCode': 'CKL',
      'checklistName': 'Checklist',
      'inspector': {'id': 'x', 'name': 'Marcos', 'registration': null},
      'manager': {'id': 'm', 'name': 'Helena', 'registration': null},
      'hasSignature': true,
      'stats': {'total': items.length, 'answered': items.length, 'conforming': 0, 'nonConforming': 1, 'notApplicable': 0, 'photos': 1, 'maxCriticality': 'HIGH', 'conformityPercent': 0.0},
      'items': items,
      'events': <dynamic>[],
    };

Map<String, dynamic> _ncItem({required List<Map<String, dynamic>> plans, String criticality = 'HIGH'}) => {
      'id': 'it1',
      'itemNo': 4,
      'category': 'Incêndio',
      'statement': 'Mangueira',
      'location': 'Abrigo',
      'result': 'NON_CONFORMING',
      'criticality': criticality,
      'description': 'Trinca',
      'recommendedAction': 'Trocar',
      'photos': <dynamic>[],
      'actionPlans': plans,
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SessionController', () {
    test('gestor entra e o token fica salvo só se "manter conectado"', () async {
      final api = InfraCheckApi(
          baseUrl: 'http://x',
          client: MockClient((_) async => _json({'token': 't', 'expiresAt': '2030-01-01T00:00:00Z', 'user': _user('CONTRACT_MANAGER')})));
      final session = SessionController(api: api, store: SessionStore());

      expect(await session.login('h@x.com', 'senha', remember: false), isNull);
      expect(session.isLoggedIn, isTrue);
      expect(await SessionStore().read(), isNull);

      expect(await session.login('h@x.com', 'senha', remember: true), isNull);
      expect(await SessionStore().read(), 't');
    });

    test('inspetor não entra no painel', () async {
      final api = InfraCheckApi(
          baseUrl: 'http://x',
          client: MockClient((_) async => _json({'token': 't', 'expiresAt': '2030-01-01T00:00:00Z', 'user': _user('INSPECTOR')})));
      final session = SessionController(api: api, store: SessionStore());

      final error = await session.login('m@x.com', 'senha', remember: true);

      expect(error, contains('aplicativo'));
      expect(session.isLoggedIn, isFalse);
      expect(api.token, isNull);
    });

    test('senha errada devolve mensagem amigável', () async {
      final api = InfraCheckApi(
          baseUrl: 'http://x', client: MockClient((_) async => _json({'code': 'INVALID_CREDENTIALS', 'message': 'x'}, 401)));
      final session = SessionController(api: api, store: SessionStore());
      expect(await session.login('h@x.com', 'errada', remember: false), 'E-mail ou senha incorretos.');
    });

    test('401 em qualquer chamada encerra a sessão', () async {
      var calls = 0;
      final api = InfraCheckApi(
          baseUrl: 'http://x',
          client: MockClient((_) async {
            calls++;
            return calls == 1
                ? _json({'token': 't', 'expiresAt': '2030-01-01T00:00:00Z', 'user': _user('ADMIN')})
                : _json({'code': 'X', 'message': 'expirou'}, 401);
          }));
      final session = SessionController(api: api, store: SessionStore());
      await session.login('a@x.com', 's', remember: true);

      await expectLater(api.me(), throwsA(isA<ApiError>()));
      await Future<void>.delayed(Duration.zero);

      expect(session.isLoggedIn, isFalse);
      expect(await SessionStore().read(), isNull);
    });
  });

  group('InspectionDetailController', () {
    test('NC Alta sem plano de ação bloqueia a aprovação até o plano ser salvo', () async {
      var plans = <Map<String, dynamic>>[];
      final api = InfraCheckApi(
        baseUrl: 'http://x',
        client: MockClient((req) async {
          if (req.url.path.endsWith('/action-plans')) {
            plans = [
              {'id': 'p', 'responsible': 'Síndica', 'dueDate': '2025-06-19', 'action': 'Trocar', 'createdBy': 'Helena', 'createdAt': '2025-06-12T10:00:00Z'}
            ];
          }
          return _json(_detail(items: [_ncItem(plans: plans)]));
        }),
      );
      final c = InspectionDetailController(api, 'i1');
      await c.load();
      expect(c.itemsMissingPlan.map((i) => i.itemNo), [4]);

      final ok = await c.savePlan(itemId: 'it1', responsible: 'Síndica', dueDate: DateTime(2025, 6, 19), action: 'Trocar');

      expect(ok, isTrue);
      expect(c.itemsMissingPlan, isEmpty);
    });

    test('NC de criticidade Baixa não exige plano', () async {
      final api = InfraCheckApi(baseUrl: 'http://x', client: MockClient((_) async => _json(_detail(items: [_ncItem(plans: [], criticality: 'LOW')]))));
      final c = InspectionDetailController(api, 'i1');
      await c.load();
      expect(c.itemsMissingPlan, isEmpty);
    });

    test('erro do servidor na aprovação fica disponível para a tela, com os detalhes', () async {
      final api = InfraCheckApi(
        baseUrl: 'http://x',
        client: MockClient((req) async => req.url.path.endsWith('/approve')
            ? _json({'code': 'ACTION_PLAN_REQUIRED', 'message': 'Falta plano', 'details': ['Item 04 (HIGH) sem plano de ação']}, 422)
            : _json(_detail(items: [_ncItem(plans: [])]))),
      );
      final c = InspectionDetailController(api, 'i1');
      await c.load();

      expect(await c.approve(), isFalse);
      expect(c.actionError, contains('Item 04'));
      expect(c.busy, isFalse);
    });
  });
}
