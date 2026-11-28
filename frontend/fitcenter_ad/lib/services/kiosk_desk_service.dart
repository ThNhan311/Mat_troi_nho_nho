import 'api_client.dart';

class KioskEnrollment {
  final String requestId, memberName, status;
  const KioskEnrollment(this.requestId, this.memberName, this.status);

  static KioskEnrollment parse(Object? data) {
    if (data is Map<String, dynamic>) {
      final id = data['requestId'];
      final name = data['memberName'];
      final status = data['status'];
      if (id is String && name is String && status is String) {
        return KioskEnrollment(id, name, status);
      }
    }
    throw KioskDeskState.invalid;
  }
}

class KioskScan {
  final String memberName, role;
  final bool membershipValid;
  final DateTime at;
  const KioskScan(this.memberName, this.role, this.membershipValid, this.at);
}

class KioskDeskState {
  final KioskEnrollment? enrollment;
  final List<KioskScan> recent;
  const KioskDeskState(this.enrollment, this.recent);

  static KioskDeskState parse(Object? data) {
    try {
      final map = data as Map<String, dynamic>;
      final e = map['enrollment'];
      return KioskDeskState(e == null ? null : KioskEnrollment.parse(e), [
        for (final row in map['recent'] as List)
          KioskScan(
            row['memberName'] as String,
            row['role'] as String,
            row['membershipValid'] as bool,
            DateTime.parse(row['at'] as String),
          ),
      ]);
    } on TypeError {
      throw invalid;
    } on FormatException {
      throw invalid;
    }
  }

  static const invalid = ApiError(
    0,
    'INVALID_RESPONSE',
    'Dữ liệu kiosk không hợp lệ.',
  );
}

class KioskDeskService {
  final ApiClient api;
  KioskDeskService(this.api);

  Future<KioskDeskState> read() async =>
      KioskDeskState.parse(await api.request('GET', '/admin/kiosk'));

  /// A write answered with "expired" was not run: the client has just renewed
  /// the session. These camera commands are safe to send again, once.
  Future<T> _afterRenewal<T>(Future<T> Function() send) async {
    try {
      return await send();
    } on ApiError catch (e) {
      if (e.code != 'SESSION_REFRESHED') rethrow;
      return send();
    }
  }

  /// Asks the screen on the second monitor to take this person's face.
  Future<KioskEnrollment> requestEnrollment(String profileId) async =>
      KioskEnrollment.parse(
        await _afterRenewal(
          () => api.request(
            'POST',
            '/admin/kiosk/enrollment',
            body: {'memberId': profileId},
          ),
        ),
      );

  /// Opens the camera screen on the front desk computer.
  Future<void> openScreen() async {
    await _afterRenewal(
      () => api.request('POST', '/admin/kiosk/open', expectedStatus: 204),
    );
  }

  Future<void> cancel() async {
    await _afterRenewal(
      () => api.request(
        'DELETE',
        '/admin/kiosk/enrollment',
        expectedStatus: 204,
      ),
    );
  }
}
