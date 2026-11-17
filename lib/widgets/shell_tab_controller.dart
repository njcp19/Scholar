import 'package:flutter/foundation.dart';

class ShellTabController extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void select(int index) {
    if (index < 0 || index > 3) {
      throw RangeError.range(index, 0, 3, 'index');
    }
    if (index == _selectedIndex) return;
    _selectedIndex = index;
    notifyListeners();
  }
}
