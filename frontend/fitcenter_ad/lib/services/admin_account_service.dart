import 'api_client.dart';

class AdminAccount {
  final String userId, profileId, email, fullName, role, status;
  final bool activationPending;
  const AdminAccount(
    this.userId,
    this.profileId,
    this.email,
    this.fullName,
    this.role,
    this.status,
    this.activationPending,
  );
  static AdminAccount parse(dynamic data, {bool write = false}) {
    try {
      if (data is! Map<String, dynamic>) throw const FormatException();
      final uuid = RegExp(
        r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
      );
      for (final key in ['userId', 'profileId']) {
        if (data[key] is! String || !uuid.hasMatch(data[key]))
          throw const FormatException();
      }
      if (data['userId'] == data['profileId'] ||
          data['email'] is! String ||
          data['fullName'] is! String ||
          !['MEMBER', 'PT'].contains(data['role']) ||
          !['ACTIVE', 'DISABLED', 'SUSPENDED'].contains(data['status']) ||
          data['activationPending'] is! bool ||
          (data['activationPending'] == true && data['status'] != 'DISABLED'))
        throw const FormatException();
      return AdminAccount(
        data['userId'],
        data['profileId'],
        data['email'],
        data['fullName'],
        data['role'],
        data['status'],
        data['activationPending'],
      );
    } catch (_) {
      throw ApiError(
        0,
        'INVALID_RESPONSE',
        'Dữ liệu tài khoản không hợp lệ.',
        outcomeUnknown: write,
      );
    }
  }

  String get statusLabel => activationPending
      ? 'Chưa kích hoạt'
      : status == 'ACTIVE'
      ? 'Đang hoạt động'
      : status == 'SUSPENDED'
      ? 'Đã tạm khóa'
      : 'Đã vô hiệu hóa';
}

class AdminAccountService {
  final ApiClient api;
  AdminAccountService(this.api);
  String path(String role) {
    if (!['MEMBER', 'PT'].contains(role)) throw ArgumentError('Member/PT only');
    return role == 'MEMBER' ? '/admin/members' : '/admin/personal-trainers';
  }

  Future<List<AdminAccount>> list(String role) async {
    final result = await api.request('GET', path(role));
    if (result is! List)
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Danh sách tài khoản không hợp lệ.',
      );
    final rows = result.map((e) => AdminAccount.parse(e)).toList();
    if (rows.any((a) => a.role != role))
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Vai trò tài khoản không hợp lệ.',
      );
    return rows;
  }

  Future<AdminAccount> create(String role, String email, String name) async {
    final account = AdminAccount.parse(
      await api.request(
        'POST',
        path(role),
        expectedStatus: 201,
        body: {'email': email.trim(), 'fullName': name.trim()},
      ),
      write: true,
    );
    if (account.role != role ||
        account.email != email.trim() ||
        account.fullName != name.trim() ||
        !account.activationPending ||
        account.status != 'DISABLED')
      throw const ApiError(
        0,
        'INVALID_RESPONSE',
        'Chưa đối chiếu được tài khoản vừa tạo.',
        outcomeUnknown: true,
      );
    return account;
  }
}
