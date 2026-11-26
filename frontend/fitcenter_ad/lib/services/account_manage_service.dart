import 'api_client.dart';

/// What the account table shows besides the account itself.
class AccountDetail {
  final String? phone, planName, validUntil, planState, face;
  const AccountDetail({
    this.phone,
    this.planName,
    this.validUntil,
    this.planState,
    this.face,
  });
}

class AccountManageService {
  final ApiClient api;
  AccountManageService(this.api);

  /// Keyed by profile id. null when the server cannot tell; the table then
  /// shows a dash instead of claiming there is no package.
  Future<Map<String, AccountDetail>?> details() async {
    try {
      final rows = await api.request('GET', '/admin/account-details');
      if (rows is! List) return null;
      final result = <String, AccountDetail>{};
      for (final row in rows) {
        if (row is! Map<String, dynamic> || row['profileId'] is! String) {
          return null;
        }
        String? text(String key) => row[key] is String ? row[key] : null;
        result[row['profileId']] = AccountDetail(
          phone: text('phone'),
          planName: text('planName'),
          validUntil: text('validUntil'),
          planState: text('planState'),
          face: text('face'),
        );
      }
      return result;
    } on ApiError {
      return null;
    }
  }

  Future<void> update(
    String userId,
    String fullName,
    String email, {
    String? phone,
  }) => _send('PATCH', '/admin/accounts/$userId', {
    'fullName': fullName.trim(),
    'email': email.trim(),
    'phone': ?phone,
  });

  Future<void> delete(String userId) =>
      _send('DELETE', '/admin/accounts/$userId');

  Future<void> removeFace(String profileId) =>
      _send('DELETE', '/admin/kiosk/faces/$profileId');

  Future<void> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    await api.request(method, path, body: body, expectedStatus: 204);
  }
}
