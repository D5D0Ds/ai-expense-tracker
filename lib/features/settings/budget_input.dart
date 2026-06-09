/// Parses a user-entered monthly budget amount.
double? parseBudgetAmount(String value) {
  final amount = double.tryParse(value.trim());
  if (amount == null || amount < 0) return null;
  return amount;
}
