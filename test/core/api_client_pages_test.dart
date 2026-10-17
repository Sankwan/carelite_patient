import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _page(List<int> ids, String? next) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
      data: {'count': 45, 'next': next, 'previous': null, 'results': [for (final id in ids) {'id': id}]},
    );

void main() {
  test('follows next across pages and returns every row', () async {
    final client = _MockApiClient();
    when(() => client.get('/api/appointments/', query: any(named: 'query')))
        .thenAnswer((_) async => _page([1, 2], 'http://10.0.2.2:8000/api/appointments/?page=2'));
    when(() => client.get('/api/appointments/', query: {'page': '2'}))
        .thenAnswer((_) async => _page([3, 4], 'http://10.0.2.2:8000/api/appointments/?page=3'));
    when(() => client.get('/api/appointments/', query: {'page': '3'}))
        .thenAnswer((_) async => _page([5], null));

    final response = await client.getAllPages('/api/appointments/');

    final ids = [for (final row in (response.data as Map)['results'] as List) (row as Map)['id']];
    expect(ids, [1, 2, 3, 4, 5]);
  });

  test('a failing later page keeps the rows already read', () async {
    final client = _MockApiClient();
    when(() => client.get('/api/notifications/', query: any(named: 'query')))
        .thenAnswer((_) async => _page([1], 'http://x/api/notifications/?page=2'));
    when(() => client.get('/api/notifications/', query: {'page': '2'})).thenAnswer(
      (_) async => Response<dynamic>(requestOptions: RequestOptions(path: '/'), statusCode: 500),
    );

    final response = await client.getAllPages('/api/notifications/');

    expect(((response.data as Map)['results'] as List).length, 1);
  });
}
