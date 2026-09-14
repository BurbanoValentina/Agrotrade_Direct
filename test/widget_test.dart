import 'package:flutter_test/flutter_test.dart';
import 'package:agrotrade_direct/app.dart';

void main() {
  testWidgets('Carga inicial de AgroTrade Direct', (WidgetTester tester) async {
    // Renderiza el widget principal real de tu aplicación
    await tester.pumpWidget(const AgroTradeApp());
  });
}
