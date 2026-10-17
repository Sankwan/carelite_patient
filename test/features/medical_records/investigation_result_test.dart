import 'package:carelite_app/features/medical_records/domain/investigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('today’s backend (no release fields) reads as released, as before', () {
    final i = Investigation.fromDjangoJson(const {
      'id': 7,
      'test_name': 'Lipid Profile',
      'status': 'RESULT_UPLOADED',
      'result': {'result_text': 'Total cholesterol 6.4', 'file': null},
    });
    expect(i.release, ResultRelease.released);
    expect(i.isSensitive, isFalse);
    expect(i.attachments, isEmpty);
  });

  test('reads panel values with flags, attachments and the release state', () {
    final i = Investigation.fromDjangoJson(const {
      'id': 8,
      'test_name': 'Full Blood Count',
      'status': 'RESULT_UPLOADED',
      'release_status': 'PENDING_REVIEW',
      'is_sensitive': true,
      'result': {
        'values': [
          {'name': 'Haemoglobin', 'value': 9.1, 'unit': 'g/dL', 'reference_range': '12–16', 'flag': 'L'},
          {'name': 'Platelets', 'value': 40, 'unit': '×10⁹/L', 'reference_range': '150–400', 'flag': 'LL'},
        ],
        'attachments': [
          {'url': 'https://files.example/r1?sig=x', 'name': 'Analyser printout', 'content_type': 'application/pdf'},
        ],
      },
    });
    expect(i.release, ResultRelease.pendingReview);
    expect(i.isVisibleToPatient, isFalse);
    expect(i.isSensitive, isTrue);
    expect(i.values.first.flag, ResultFlag.low);
    expect(i.values.last.flag.isCritical, isTrue);
    expect(i.attachments.single.isPdf, isTrue);
  });

  test('a bare /media/ path is not offered as an attachment', () {
    final i = Investigation.fromDjangoJson(const {
      'id': 9,
      'test_name': 'X-ray',
      'status': 'RESULT_UPLOADED',
      'result': {'file': '/media/investigation_results/x.jpg'},
    });
    expect(i.attachments, isEmpty);
    expect(i.hasResultFile, isTrue);
  });
}
