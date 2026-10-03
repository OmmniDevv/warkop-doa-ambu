import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warkop_doa_ambu/main.dart';

void main() {
  testWidgets('Aplikasi menampilkan layar daftar owner', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AplikasiWarkop(supabaseSiap: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daftar Akun Owner'), findsWidgets);
    expect(find.text('WARKOP DOA AMBU'), findsWidgets);
  });
}
