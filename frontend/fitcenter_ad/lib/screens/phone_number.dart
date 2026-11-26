/// Same rule as the server, after removing spaces, dots and dashes.
String normalizePhone(String value) => value.replaceAll(RegExp(r'[\s.\-]'), '');

String? phoneError(String? value) =>
    RegExp(r'^(0|\+84)[0-9]{9}$').hasMatch(normalizePhone(value ?? ''))
    ? null
    : 'Số điện thoại gồm 10 số, bắt đầu bằng 0.';
