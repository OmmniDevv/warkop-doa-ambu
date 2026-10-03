import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warkop_doa_ambu/main.dart';

void main() {
  testWidgets('Aplikasi menampilkan layar selamat datang', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AplikasiWarkop(supabaseSiap: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saya Owner'), findsOneWidget);
    expect(find.text('Saya Kasir'), findsOneWidget);
  });
}
