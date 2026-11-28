import 'package:fitcenter/services/renewal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money is grouped by thousands and ends with VND', () {
    expect(paymentMoney(0), '0 VND');
    expect(paymentMoney(99900), '999 VND');
    expect(paymentMoney(10000000), '100.000 VND');
    expect(paymentMoney(123456700), '1.234.567 VND');
    expect(paymentMoney(10000050), '100.000,50 VND');
  });
}
