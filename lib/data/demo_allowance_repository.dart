class DemoAllowanceRepository {
  DemoAllowanceRepository._();

  static final DemoAllowanceRepository instance = DemoAllowanceRepository._();

  DateTime? _expectedReleaseDate = DateTime(2026, 12, 1);
  final Map<String, String?> _academicPeriods = {
    'Payout Event': '1st Semester AY 2026-2027',
  };

  DateTime? get expectedReleaseDate => _expectedReleaseDate;

  // TODO: Replace this in-memory value with the backend's expected release date.
  void setExpectedReleaseDate(DateTime? date) {
    _expectedReleaseDate =
        date == null ? null : DateTime(date.year, date.month, date.day);
  }

  String? academicPeriodFor(String payoutEventTitle) =>
      _academicPeriods[payoutEventTitle];

  // TODO: Replace this in-memory map with the backend's Payout Event academic period.
  void setAcademicPeriod(String payoutEventTitle, String? academicPeriod) {
    final title = payoutEventTitle.trim();
    if (title.isEmpty) return;
    final period = academicPeriod?.trim();
    if (period == null || period.isEmpty) {
      _academicPeriods.remove(title);
    } else {
      _academicPeriods[title] = period;
    }
  }
}
