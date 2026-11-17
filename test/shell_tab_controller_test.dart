import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/widgets/shell_tab_controller.dart';

void main() {
  test('select updates the current tab and notifies listeners', () {
    final controller = ShellTabController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.select(2);

    expect(controller.selectedIndex, 2);
    expect(notifications, 1);

    controller.select(2);
    expect(notifications, 1);

    controller.dispose();
  });
}
