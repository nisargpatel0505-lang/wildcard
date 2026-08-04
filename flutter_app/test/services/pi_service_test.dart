import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wildcard/services/pi_service.dart';

void main() {
  test('House Rule run analytics accepts only privacy-safe rule IDs', () async {
    final requests = <http.Request>[];
    final service = PiService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );
    addTearDown(service.dispose);

    service.queueRunStart('house-echo_table');
    service.queueRunEnd(mode: 'house-echo_table', outcome: 'lost', heat: 8);
    service.queueRunEnd(mode: 'house-Invalid ID', outcome: 'lost', heat: 8);
    await service.flushAnalytics();

    expect(requests, hasLength(1));
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['events'], <Map<String, String>>[
      <String, String>{'n': 'run_start', 'm': 'house-echo_table'},
      <String, String>{
        'n': 'run_end',
        'm': 'house-echo_table',
        'o': 'lost',
        'h': '7-9',
      },
    ]);
  });
}
