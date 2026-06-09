/// A selectable filter option and the value it should apply when selected.
final class SelectableFilterOption<T> {
  /// Creates a filter option.
  const SelectableFilterOption({
    required this.label,
    required this.selected,
    required this.nextValue,
    this.accentValue,
  });

  /// Display label.
  final String label;

  /// Whether this option represents the current filter state.
  final bool selected;

  /// Value to apply when selected.
  final T? nextValue;

  /// Optional ARGB accent value.
  final int? accentValue;
}

/// Builds nullable filter options with an "All" clear option.
List<SelectableFilterOption<T>> buildNullableFilterOptions<T>({
  required T? selected,
  required Iterable<T> values,
  required String Function(T value) labelFor,
  int? Function(T value)? accentFor,
}) {
  return [
    SelectableFilterOption<T>(
      label: 'All',
      selected: selected == null,
      nextValue: null,
    ),
    for (final value in values)
      SelectableFilterOption<T>(
        label: labelFor(value),
        selected: selected == value,
        nextValue: selected == value ? null : value,
        accentValue: accentFor?.call(value),
      ),
  ];
}
