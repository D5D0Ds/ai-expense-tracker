import 'dart:convert';

import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:ai_expense_tracker/shared/platform/gemma_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides SMS parsing through Gemma.
final gemmaExpenseParserProvider = Provider<GemmaExpenseParser>((ref) {
  return GemmaExpenseParser(ref.watch(gemmaGatewayProvider));
});

enum _MoneyDirection { outgoing, incoming, unknown }

/// Parses Indian bank and UPI SMS messages into editable expense proposals.
final class GemmaExpenseParser {
  /// Creates a parser.
  const GemmaExpenseParser(GemmaGateway bridge) : this._(bridge);

  const GemmaExpenseParser._(this._bridge);

  final GemmaGateway _bridge;

  /// Parses a raw SMS body with the native Gemma runtime.
  Future<ParsedExpense> parse(String smsBody) async {
    final parsed = await _bridge.parseSms(smsBody);
    if (parsed == null) {
      throw StateError('Gemma did not return a valid SMS parse.');
    }
    return parsed;
  }

  /// Deterministic parser retained for focused parser tests only.
  static ParsedExpense parseWithHeuristics(
    String smsBody, {
    required DateTime fallbackDate,
  }) {
    final normalized = smsBody.replaceAll(',', ' ');
    final amount = _extractAmount(normalized);
    final direction = _directionFor(normalized);
    final payee = _extractPayee(normalized, direction);
    final isPersonLike = _looksLikePerson(payee);
    final paymentMethod = _paymentMethodFor(normalized);
    final accountHint = _accountPattern.firstMatch(normalized)?.group(0);
    final bank = _detectBank(normalized);
    final suffix = _extractSuffix(normalized);
    final upiHandle = _upiHandlePattern.firstMatch(normalized)?.group(0);
    final transactionKind = _transactionKindFor(
      payee,
      normalized,
      direction: direction,
      isPersonLike: isPersonLike,
    );
    final category = _categoryFor(
      payee,
      normalized,
      transactionKind: transactionKind,
    );
    final sourceLabel = _sourceLabelFor(
      paymentMethod: paymentMethod,
      bank: bank,
      suffix: suffix,
      upiHandle: upiHandle,
    );
    final fundingSourceLabel = _fundingSourceLabelFor(
      paymentMethod: paymentMethod,
      bank: bank,
      suffix: suffix,
      sourceLabel: sourceLabel,
    );
    return ParsedExpense(
      amount: amount,
      currency: 'INR',
      date: fallbackDate,
      payee: payee,
      category: category,
      transactionKind: transactionKind,
      paymentMethod: paymentMethod,
      confidence: _confidenceFor(
        sourceLabel: sourceLabel,
        accountHint: accountHint,
        direction: direction,
      ),
      reason: _reasonFor(
        transactionKind: transactionKind,
        paymentMethod: paymentMethod,
        sourceLabel: sourceLabel,
      ),
      isPersonLike: isPersonLike,
      accountHint: accountHint,
      sourceLabel: sourceLabel,
      fundingSourceLabel: fundingSourceLabel,
    );
  }

  /// Parses strict JSON returned by a model.
  static ParsedExpense parseJson(String jsonText) {
    return ParsedExpense.fromJson(jsonDecode(jsonText) as Map<String, dynamic>);
  }

  static const _bankKeywords = <String, List<String>>{
    'HDFC': ['hdfc'],
    'Axis': ['axis'],
    'SBI': ['sbi', 'state bank'],
    'HSBC': ['hsbc'],
    'Federal': ['federal'],
    'Kotak': ['kotak'],
    'ICICI': ['icici'],
    'Yes Bank': ['yes bank'],
  };
  static final _amountPattern = RegExp(
    r'(?:INR|Rs\.?|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final _accountPattern = RegExp(
    r'(?:A/c|Acct|account)\s*(?:no\.?\s*)?(?:ending|XX|xx|X+|x+|\*+)?\s*[0-9]{2,6}',
    caseSensitive: false,
  );
  static final _accountSuffixPattern = RegExp(
    r'(?:A/c|Acct|account)\s*(?:no\.?\s*)?(?:ending|XX|xx|X+|x+|\*+)?\s*([0-9]{2,6})',
    caseSensitive: false,
  );
  static final _cardSuffixPattern = RegExp(
    r'(?:credit|debit)?\s*card(?:\s*(?:ending|xx|XX|x+|\*+))?\s*([0-9]{2,6})',
    caseSensitive: false,
  );
  static final _upiHandlePattern = RegExp(
    r'[A-Za-z0-9._-]{2,}@[A-Za-z]{2,}',
    caseSensitive: false,
  );

  static double _extractAmount(String smsBody) {
    final raw =
        _amountPattern
            .firstMatch(smsBody)
            ?.group(1)
            ?.replaceAll(RegExp('[^0-9.]'), '') ??
        '0';
    return double.tryParse(raw) ?? 0;
  }

  static _MoneyDirection _directionFor(String smsBody) {
    final lower = smsBody.toLowerCase();
    if (_containsAny(lower, [
      'credited',
      'credit for',
      'received',
      'deposit',
      'refund',
      'reversal',
    ])) {
      return _MoneyDirection.incoming;
    }
    if (_containsAny(lower, [
      'debited',
      'paid',
      'spent',
      'withdrawn',
      'sent',
      'purchase',
      'transferred to',
      'upi',
    ])) {
      return _MoneyDirection.outgoing;
    }
    return _MoneyDirection.unknown;
  }

  static String _extractPayee(String smsBody, _MoneyDirection direction) {
    final patterns = switch (direction) {
      _MoneyDirection.incoming => [
        RegExp(
          r'(?:from|received from|credited by)\s+([A-Z0-9 .&@_-]{3,40})',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:UPI|IMPS|NEFT)\s+from\s+([A-Z0-9 .&@_-]{3,40})',
          caseSensitive: false,
        ),
      ],
      _MoneyDirection.outgoing => [
        RegExp(
          r'(?:to|at|paid to|sent to|towards)\s+([A-Z0-9 .&@_-]{3,40})',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:UPI/P2M|UPI/P2A|UPI)\s+([A-Z0-9 .&@_-]{3,40})',
          caseSensitive: false,
        ),
      ],
      _MoneyDirection.unknown => [
        RegExp(
          r'(?:to|at|paid to|sent to|towards|from|received from)\s+([A-Z0-9 .&@_-]{3,40})',
          caseSensitive: false,
        ),
      ],
    };
    for (final pattern in patterns) {
      final match = pattern.firstMatch(smsBody);
      if (match == null) continue;
      final value = (match.group(1) ?? '')
          .split(
            RegExp(
              r'\s+(?:on|ref|txn|upi|from|via|avl|bal|info|id)\s+',
              caseSensitive: false,
            ),
          )
          .first
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      if (value.isNotEmpty) return value;
    }
    return 'Unknown payee';
  }

  static TransactionKind _transactionKindFor(
    String payee,
    String body, {
    required _MoneyDirection direction,
    required bool isPersonLike,
  }) {
    final text = '$payee $body'.toLowerCase();
    if (direction == _MoneyDirection.incoming &&
        (isPersonLike || _containsAny(text, ['friend', 'family', 'loan']))) {
      return TransactionKind.borrowed;
    }
    if (direction == _MoneyDirection.outgoing &&
        (isPersonLike || _containsAny(text, ['friend', 'family']))) {
      return TransactionKind.lent;
    }
    return TransactionKind.expense;
  }

  static PaymentMethodKind _paymentMethodFor(String body) {
    final text = body.toLowerCase();
    if (_upiHandlePattern.hasMatch(body) || text.contains('upi')) {
      return PaymentMethodKind.upi;
    }
    if (text.contains('credit card') || text.contains('creditcard')) {
      return PaymentMethodKind.creditCard;
    }
    if (text.contains('debit card') || text.contains('debitcard')) {
      return PaymentMethodKind.debitCard;
    }
    if (_accountPattern.hasMatch(body) || text.contains('account')) {
      return PaymentMethodKind.bankAccount;
    }
    if (text.contains('cash')) return PaymentMethodKind.cash;
    return PaymentMethodKind.other;
  }

  static ExpenseCategory _categoryFor(
    String payee,
    String body, {
    required TransactionKind transactionKind,
  }) {
    if (transactionKind != TransactionKind.expense) {
      return ExpenseCategory.transfer;
    }
    final text = '$payee $body'.toLowerCase();
    if (_containsAny(text, [
      'swiggy',
      'zomato',
      'restaurant',
      'cafe',
      'food',
      'grocery',
    ])) {
      return ExpenseCategory.food;
    }
    if (_containsAny(text, [
      'amazon',
      'flipkart',
      'myntra',
      'shopping',
      'store',
    ])) {
      return ExpenseCategory.shopping;
    }
    if (_containsAny(text, [
      'uber',
      'ola',
      'metro',
      'irctc',
      'fuel',
      'petrol',
      'travel',
    ])) {
      return ExpenseCategory.travel;
    }
    if (_containsAny(text, [
      'airtel',
      'jio',
      'electricity',
      'bill',
      'recharge',
    ])) {
      return ExpenseCategory.bills;
    }
    if (_containsAny(text, [
      'rent',
      'landlord',
      'house rent',
      'brokerage',
    ])) {
      return ExpenseCategory.rent;
    }
    if (_containsAny(text, [
      'apollo',
      'pharmacy',
      'hospital',
      'clinic',
      'medicine',
    ])) {
      return ExpenseCategory.health;
    }
    return ExpenseCategory.other;
  }

  static String? _detectBank(String body) {
    final lower = body.toLowerCase();
    for (final entry in _bankKeywords.entries) {
      if (entry.value.any(lower.contains)) return entry.key;
    }
    return null;
  }

  static String? _extractSuffix(String body) {
    return _cardSuffixPattern.firstMatch(body)?.group(1) ??
        _accountSuffixPattern.firstMatch(body)?.group(1);
  }

  static String? _sourceLabelFor({
    required PaymentMethodKind paymentMethod,
    required String? bank,
    required String? suffix,
    required String? upiHandle,
  }) {
    final maskedSuffix = suffix == null ? null : '•$suffix';
    final handleLabel = upiHandle == null
        ? null
        : '· ${upiHandle.toLowerCase()}';
    final label = switch (paymentMethod) {
      PaymentMethodKind.creditCard => [
        ?bank,
        'Credit card',
        ?maskedSuffix,
      ].join(' '),
      PaymentMethodKind.debitCard => [
        ?bank,
        'Debit card',
        ?maskedSuffix,
      ].join(' '),
      PaymentMethodKind.bankAccount => [
        ?bank,
        'Account',
        ?maskedSuffix,
      ].join(' '),
      PaymentMethodKind.upi => [
        ?bank,
        'UPI',
        ?handleLabel,
      ].join(' '),
      PaymentMethodKind.cash => 'Cash',
      PaymentMethodKind.other => bank,
    };
    if (label == null || label.trim().isEmpty) return null;
    return label;
  }

  static String? _fundingSourceLabelFor({
    required PaymentMethodKind paymentMethod,
    required String? bank,
    required String? suffix,
    required String? sourceLabel,
  }) {
    final maskedSuffix = suffix == null ? null : '•$suffix';
    final label = switch (paymentMethod) {
      PaymentMethodKind.creditCard => sourceLabel,
      PaymentMethodKind.cash => 'Cash wallet',
      PaymentMethodKind.other => sourceLabel,
      _ => [
        ?bank,
        'Account',
        ?maskedSuffix,
      ].join(' '),
    };
    if (label == null || label.trim().isEmpty) return null;
    return label;
  }

  static double _confidenceFor({
    required String? sourceLabel,
    required String? accountHint,
    required _MoneyDirection direction,
  }) {
    if (sourceLabel != null && accountHint != null) return 0.76;
    if (sourceLabel != null || accountHint != null) return 0.69;
    if (direction != _MoneyDirection.unknown) return 0.63;
    return 0.56;
  }

  static String _reasonFor({
    required TransactionKind transactionKind,
    required PaymentMethodKind paymentMethod,
    required String? sourceLabel,
  }) {
    final subject = switch (transactionKind) {
      TransactionKind.expense => 'expense',
      TransactionKind.lent => 'person-to-person transfer',
      TransactionKind.borrowed => 'borrowed money',
    };
    final method = switch (paymentMethod) {
      PaymentMethodKind.creditCard => 'credit-card',
      PaymentMethodKind.debitCard => 'debit-card',
      PaymentMethodKind.bankAccount => 'bank-account',
      PaymentMethodKind.upi => 'UPI',
      PaymentMethodKind.cash => 'cash',
      PaymentMethodKind.other => 'payment-source',
    };
    if (sourceLabel != null) {
      return 'Fallback parser matched a $subject on $method using $sourceLabel.';
    }
    return 'Fallback parser matched a $subject on $method.';
  }

  static bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  static bool _looksLikePerson(String payee) {
    final words = payee
        .split(RegExp(r'\s+'))
        .where((word) => RegExp(r'^[A-Za-z]+$').hasMatch(word))
        .toList();
    return words.length >= 2 &&
        words.length <= 4 &&
        !payee.contains(
          RegExp(r'(PVT|LTD|STORE|MART|BANK)', caseSensitive: false),
        );
  }
}
