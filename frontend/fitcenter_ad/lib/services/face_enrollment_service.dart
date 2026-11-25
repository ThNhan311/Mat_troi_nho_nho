import 'api_client.dart';
import 'admin_account_service.dart';
import 'initial_activation_service.dart' show requiredUuid;

class FaceEnrollment {
  final String id,
      requestId,
      memberId,
      status,
      proposedProfileId,
      mode,
      consentVersion;
  final String? profileId, failureCode;
  final DateTime startedAt;
  final bool cleanupPending;
  FaceEnrollment(
    this.id,
    this.requestId,
    this.memberId,
    this.status,
    this.proposedProfileId,
    this.mode,
    this.consentVersion,
    this.profileId,
    this.failureCode,
    this.startedAt,
    this.cleanupPending,
  );
  static FaceEnrollment parse(dynamic value, {bool write = false}) {
    try {
      if (value is! Map<String, dynamic> ||
          ![
            'PENDING',
            'ACTIVE',
            'FAILED',
            'REVOKED',
          ].contains(value['status']) ||
          value['verificationMode'] != 'SIMULATED_TEST' ||
          value['consentVersion'] is! String ||
          value['cleanupPending'] is! bool)
        throw const FormatException();
      final profile = value['profileId'] == null
          ? null
          : requiredUuid(value['profileId']);
      if (value['status'] == 'ACTIVE' && profile != value['proposedProfileId'])
        throw const FormatException();
      if (value['failureCode'] != null && value['failureCode'] is! String)
        throw const FormatException();
      final at = DateTime.parse(value['startedAt']);
      if (!value['startedAt'].toString().endsWith('Z'))
        throw const FormatException();
      return FaceEnrollment(
        requiredUuid(value['id']),
        requiredUuid(value['requestId']),
        requiredUuid(value['memberId']),
        value['status'],
        requiredUuid(value['proposedProfileId']),
        value['verificationMode'],
        value['consentVersion'],
        profile,
        value['failureCode'],
        at,
        value['cleanupPending'],
      );
    } catch (_) {
      throw ApiError(
        0,
        'INVALID_RESPONSE',
        'Dữ liệu đăng ký khuôn mặt không hợp lệ.',
        outcomeUnknown: write,
      );
    }
  }
}

class FaceProfile {
  final String id, status, mode;
  final DateTime? revokedAt;
  FaceProfile(this.id, this.status, this.mode, this.revokedAt);
  static FaceProfile parse(dynamic value) {
    if (value is! Map ||
        !['ACTIVE', 'REVOKED'].contains(value['status']) ||
        ![
          'SIMULATED_TEST',
          'UNVERIFIED_LEGACY',
        ].contains(value['verificationMode']))
      throw const FormatException();
    return FaceProfile(
      requiredUuid(value['id']),
      value['status'],
      value['verificationMode'],
      value['revokedAt'] == null ? null : DateTime.parse(value['revokedAt']),
    );
  }
}

class FaceEnrollmentState {
  final String memberId;
  final List<FaceProfile> profiles;
  final List<FaceEnrollment> enrollments;
  FaceEnrollmentState(this.memberId, this.profiles, this.enrollments);
  static FaceEnrollmentState parse(
    dynamic value,
    String member, {
    bool write = false,
  }) {
    try {
      if (value is! Map<String, dynamic> ||
          value['memberId'] != member ||
          value['profiles'] is! List ||
          value['enrollments'] is! List)
        throw const FormatException();
      final profiles = (value['profiles'] as List)
              .map(FaceProfile.parse)
              .toList(),
          ops = (value['enrollments'] as List)
              .map((v) => FaceEnrollment.parse(v, write: write))
              .toList();
      if (profiles.where((v) => v.status == 'ACTIVE').length > 1 ||
          ops.any((v) => v.memberId != member))
        throw const FormatException();
      return FaceEnrollmentState(member, profiles, ops);
    } catch (_) {
      throw ApiError(
        0,
        'INVALID_RESPONSE',
        'Không đối chiếu được trạng thái khuôn mặt.',
        outcomeUnknown: write,
      );
    }
  }
}

class FaceEnrollmentService {
  final ApiClient api;
  FaceEnrollmentService(this.api);
  String path(String member) =>
      '/admin/members/${requiredUuid(member)}/face-enrollments';
  Future<List<AdminAccount>> members() =>
      AdminAccountService(api).list('MEMBER');
  Future<FaceEnrollmentState> read(String member) async =>
      FaceEnrollmentState.parse(await api.request('GET', path(member)), member);
  Future<FaceEnrollment> start(
    String member,
    String key, {
    required bool consent,
    required bool verified,
    required bool atGym,
  }) async {
    final row = FaceEnrollment.parse(
      await api.request(
        'POST',
        path(member),
        expectedStatus: 201,
        idempotencyKey: key,
        body: {
          'consentAccepted': consent,
          'memberVerified': verified,
          'atGym': atGym,
          'consentVersion': 'face-consent-v1',
        },
      ),
      write: true,
    );
    if (row.memberId != member || row.requestId != key)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Chưa đối chiếu được yêu cầu vừa gửi.',
        outcomeUnknown: true,
      );
    return row;
  }

  Future<FaceEnrollment> complete(String member, String operation) async {
    final row = FaceEnrollment.parse(
      await api.request(
        'POST',
        '${path(member)}/${requiredUuid(operation)}/complete',
        body: const {},
      ),
      write: true,
    );
    if (row.memberId != member || row.id != operation)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Kết quả không khớp yêu cầu.',
        outcomeUnknown: true,
      );
    return row;
  }

  Future<FaceEnrollment> revokePending(String member, String operation) async {
    final row = FaceEnrollment.parse(
      await api.request(
        'POST',
        '${path(member)}/${requiredUuid(operation)}/revoke',
        body: const {},
      ),
      write: true,
    );
    if (row.memberId != member ||
        row.id != operation ||
        row.status != 'REVOKED')
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Chưa xác nhận hủy đăng ký.',
        outcomeUnknown: true,
      );
    return row;
  }

  Future<FaceEnrollmentState> revoke(
    String member,
    String profile,
    String key,
  ) async {
    final state = FaceEnrollmentState.parse(
      await api.request(
        'POST',
        '${path(member)}/profiles/${requiredUuid(profile)}/revoke',
        idempotencyKey: key,
        body: const {},
      ),
      member,
      write: true,
    );
    if (!state.profiles.any((v) => v.id == profile && v.status == 'REVOKED'))
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Chưa xác nhận thu hồi mẫu.',
        outcomeUnknown: true,
      );
    return state;
  }
}
