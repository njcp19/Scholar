String ordinalNumber(int value) {
  final remainder100 = value % 100;
  final suffix = remainder100 >= 11 && remainder100 <= 13
      ? 'th'
      : switch (value % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$value$suffix';
}
