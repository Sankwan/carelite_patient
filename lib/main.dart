import 'app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
