import 'package:collection/collection.dart';

/// Expense categories supported by the on-device classifier.
enum ExpenseCategory {
  /// Food, groceries, restaurants, cafes, and delivery.
  food('Food', 0xFF5EEAD4),

  /// Shopping, ecommerce, clothing, and household items.
  shopping('Shopping', 0xFFF0ABFC),

  /// Cab, fuel, train, flight, and other transport.
  travel('Travel', 0xFF93C5FD),

  /// Rent, utilities, phone, broadband, and recurring bills.
  bills('Bills', 0xFFFDE68A),

  /// Rent, landlord payments, and housing accommodation.
  rent('Rent', 0xFFFDBA74),

  /// Health, medicine, doctor, and fitness.
  health('Health', 0xFFFCA5A5),

  /// Entertainment, movies, subscriptions, and events.
  entertainment('Entertainment', 0xFFC4B5FD),

  /// Person-to-person transfer or uncategorized UPI payment.
  transfer('Transfer', 0xFFCBD5E1),

  /// Fallback category.
  other('Other', 0xFFA7F3D0);

  const ExpenseCategory(this.label, this.accentValue);

  /// Human-readable category label.
  final String label;

  /// Accent color value used by the UI.
  final int accentValue;

  /// Finds a category from model output.
  static ExpenseCategory fromLabel(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return other;

    final exact = values.firstWhereOrNull(
      (category) =>
          category.label.toLowerCase() == normalized ||
          category.name.toLowerCase() == normalized,
    );
    if (exact != null) return exact;

    if (normalized.contains('food') ||
        normalized.contains('grocery') ||
        normalized.contains('groceries') ||
        normalized.contains('dining') ||
        normalized.contains('restaurant') ||
        normalized.contains('cafe') ||
        normalized.contains('zomato') ||
        normalized.contains('swiggy')) {
      return food;
    }
    if (normalized.contains('travel') ||
        normalized.contains('transport') ||
        normalized.contains('cab') ||
        normalized.contains('uber') ||
        normalized.contains('ola') ||
        normalized.contains('flight') ||
        normalized.contains('train') ||
        normalized.contains('fuel') ||
        normalized.contains('petrol') ||
        normalized.contains('diesel')) {
      return travel;
    }
    if (normalized.contains('shopping') ||
        normalized.contains('clothes') ||
        normalized.contains('clothing') ||
        normalized.contains('amazon') ||
        normalized.contains('flipkart') ||
        normalized.contains('ecommerce') ||
        normalized.contains('store')) {
      return shopping;
    }
    if (normalized.contains('bill') ||
        normalized.contains('utility') ||
        normalized.contains('utilities') ||
        normalized.contains('recharge') ||
        normalized.contains('phone') ||
        normalized.contains('mobile') ||
        normalized.contains('broadband') ||
        normalized.contains('electricity') ||
        normalized.contains('water') ||
        normalized.contains('gas')) {
      return bills;
    }
    if (normalized.contains('rent') ||
        normalized.contains('landlord') ||
        normalized.contains('housing') ||
        normalized.contains('flat') ||
        normalized.contains('pg')) {
      return rent;
    }
    if (normalized.contains('health') ||
        normalized.contains('medical') ||
        normalized.contains('medicine') ||
        normalized.contains('doctor') ||
        normalized.contains('pharmacy') ||
        normalized.contains('hospital') ||
        normalized.contains('fitness') ||
        normalized.contains('gym')) {
      return health;
    }
    if (normalized.contains('entertainment') ||
        normalized.contains('movie') ||
        normalized.contains('show') ||
        normalized.contains('subscription') ||
        normalized.contains('netflix') ||
        normalized.contains('prime') ||
        normalized.contains('spotify') ||
        normalized.contains('event') ||
        normalized.contains('game')) {
      return entertainment;
    }
    if (normalized.contains('transfer') ||
        normalized.contains('sent to') ||
        normalized.contains('peer') ||
        normalized.contains('p2p') ||
        normalized.contains('send')) {
      return transfer;
    }
    return other;
  }
}

/// Source that created an expense.
enum ExpenseSource {
  /// User entered the expense manually.
  manual,

  /// User confirmed a suggestion parsed from SMS.
  sms,
}

/// Business meaning of a tracked ledger entry.
enum TransactionKind {
  /// Merchant or household spend.
  expense('Expense', 0xFFFFFFFF),

  /// Money given out to another person.
  lent('Lent', 0xFFF59E0B),

  /// Money received from another person that should be paid back later.
  borrowed('Borrowed', 0xFF7DD3FC);

  const TransactionKind(this.label, this.accentValue);

  /// Human-readable label.
  final String label;

  /// Accent color value used by the UI.
  final int accentValue;

  /// Whether this contributes to spending totals.
  bool get countsTowardsSpend => this == expense;

  /// Whether the money flow is incoming.
  bool get isIncoming => this == borrowed;

  /// Finds a kind from model output or persisted data.
  static TransactionKind fromValue(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll(
      RegExp(r'[_-]+'),
      ' ',
    );
    if (normalized == null || normalized.isEmpty) return expense;
    final exact = values.firstWhereOrNull((kind) {
      return kind.label.toLowerCase() == normalized ||
          kind.name.toLowerCase() == normalized;
    });
    if (exact != null) return exact;
    if (normalized == 'spend' ||
        normalized == 'spent' ||
        normalized == 'outgoing expense') {
      return expense;
    }
    if (normalized == 'loaned' ||
        normalized == 'lend' ||
        normalized == 'lent' ||
        normalized == 'outgoing loan') {
      return lent;
    }
    if (normalized == 'loan' ||
        normalized == 'borrow' ||
        normalized == 'borrowed' ||
        normalized == 'received' ||
        normalized == 'credited' ||
        normalized == 'credit' ||
        normalized == 'inflow' ||
        normalized == 'incoming') {
      return borrowed;
    }
    return expense;
  }
}

/// Payment method or rail used to create the entry.
enum PaymentMethodKind {
  /// Credit card transaction.
  creditCard('Credit card', 0xFF93C5FD),

  /// Debit card transaction.
  debitCard('Debit card', 0xFF5EEAD4),

  /// Direct bank account debit or credit.
  bankAccount('Account', 0xFFEAB308),

  /// UPI payment or transfer.
  upi('UPI', 0xFFC4B5FD),

  /// Cash entry.
  cash('Cash', 0xFFFCA5A5),

  /// Fallback.
  other('Other', 0xFFA7F3D0);

  const PaymentMethodKind(this.label, this.accentValue);

  /// Human-readable label.
  final String label;

  /// Accent color value used by the UI.
  final int accentValue;

  /// Finds a payment method from model output or persisted data.
  static PaymentMethodKind fromValue(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll(
      RegExp(r'[_-]+'),
      ' ',
    );
    if (normalized == null || normalized.isEmpty) return other;
    if (normalized.contains('upi')) return upi;
    if (normalized.contains('credit')) return creditCard;
    if (normalized.contains('debit')) return debitCard;
    if (normalized.contains('account') || normalized.contains('bank')) {
      return bankAccount;
    }
    if (normalized.contains('cash')) return cash;
    return values.firstWhereOrNull((kind) {
          return kind.label.toLowerCase() == normalized ||
              kind.name.toLowerCase() == normalized;
        }) ??
        other;
  }
}

/// Current lifecycle state of an SMS suggestion.
enum SmsCandidateStatus {
  /// Waiting for user action.
  pending,

  /// Confirmed and converted into an expense.
  confirmed,

  /// Explicitly ignored.
  ignored,

  /// Edited by the user before confirmation.
  edited,
}

/// Local expense entity stored in Hive.
final class Expense {
  /// Creates an expense.
  const Expense({
    required this.id,
    required this.amount,
    required this.currency,
    required this.occurredAt,
    required this.payee,
    required this.category,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.transactionKind = TransactionKind.expense,
    this.paymentMethod = PaymentMethodKind.other,
    this.accountHint,
    this.rawSmsHash,
    this.confidence,
    this.reason,
    this.notes,
    this.sourceLabel,
    this.fundingSourceLabel,
    this.exportedAt,
  });

  static const _unset = Object();

  /// Stable local identifier.
  final String id;

  /// Expense amount in [currency].
  final double amount;

  /// Currency code. The app defaults to INR.
  final String currency;

  /// When the payment occurred.
  final DateTime occurredAt;

  /// Merchant, payee, or recipient.
  final String payee;

  /// User-visible category.
  final ExpenseCategory category;

  /// Creation source.
  final ExpenseSource source;

  /// Semantic type of the entry.
  final TransactionKind transactionKind;

  /// Payment method inferred from the message or chosen by the user.
  final PaymentMethodKind paymentMethod;

  /// Optional masked account hint from SMS.
  final String? accountHint;

  /// SHA-256 hash of the raw SMS body.
  final String? rawSmsHash;

  /// Model confidence from zero to one.
  final double? confidence;

  /// Short model reasoning shown in the suggestion UI.
  final String? reason;

  /// User notes.
  final String? notes;

  /// User-visible payment source, such as a card or UPI alias.
  final String? sourceLabel;

  /// User-visible settlement or linked bank account.
  final String? fundingSourceLabel;

  /// Local creation time.
  final DateTime createdAt;

  /// Local update time.
  final DateTime updatedAt;

  /// Last report export time, if included in an export.
  final DateTime? exportedAt;

  /// Returns a modified copy.
  Expense copyWith({
    String? id,
    double? amount,
    String? currency,
    DateTime? occurredAt,
    String? payee,
    ExpenseCategory? category,
    ExpenseSource? source,
    TransactionKind? transactionKind,
    PaymentMethodKind? paymentMethod,
    Object? accountHint = _unset,
    Object? rawSmsHash = _unset,
    Object? confidence = _unset,
    Object? reason = _unset,
    Object? notes = _unset,
    Object? sourceLabel = _unset,
    Object? fundingSourceLabel = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? exportedAt = _unset,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      occurredAt: occurredAt ?? this.occurredAt,
      payee: payee ?? this.payee,
      category: category ?? this.category,
      source: source ?? this.source,
      transactionKind: transactionKind ?? this.transactionKind,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      accountHint: identical(accountHint, _unset)
          ? this.accountHint
          : accountHint as String?,
      rawSmsHash: identical(rawSmsHash, _unset)
          ? this.rawSmsHash
          : rawSmsHash as String?,
      confidence: identical(confidence, _unset)
          ? this.confidence
          : confidence as double?,
      reason: identical(reason, _unset) ? this.reason : reason as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      sourceLabel: identical(sourceLabel, _unset)
          ? this.sourceLabel
          : sourceLabel as String?,
      fundingSourceLabel: identical(fundingSourceLabel, _unset)
          ? this.fundingSourceLabel
          : fundingSourceLabel as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      exportedAt: identical(exportedAt, _unset)
          ? this.exportedAt
          : exportedAt as DateTime?,
    );
  }

  /// Serializes this expense.
  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    'currency': currency,
    'occurredAt': occurredAt.toIso8601String(),
    'payee': payee,
    'category': category.label,
    'source': source.name,
    'transactionKind': transactionKind.label,
    'paymentMethod': paymentMethod.label,
    'accountHint': accountHint,
    'rawSmsHash': rawSmsHash,
    'confidence': confidence,
    'reason': reason,
    'notes': notes,
    'sourceLabel': sourceLabel,
    'fundingSourceLabel': fundingSourceLabel,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'exportedAt': exportedAt?.toIso8601String(),
  };

  /// Deserializes an expense from Hive JSON.
  factory Expense.fromJson(Map<dynamic, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      payee: json['payee'] as String,
      category: ExpenseCategory.fromLabel(json['category'] as String?),
      source: ExpenseSource.values.byName(
        json['source'] as String? ?? 'manual',
      ),
      transactionKind: TransactionKind.fromValue(
        json['transactionKind'] as String?,
      ),
      paymentMethod: PaymentMethodKind.fromValue(
        json['paymentMethod'] as String?,
      ),
      accountHint: json['accountHint'] as String?,
      rawSmsHash: json['rawSmsHash'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      sourceLabel: json['sourceLabel'] as String?,
      fundingSourceLabel: json['fundingSourceLabel'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      exportedAt: json['exportedAt'] == null
          ? null
          : DateTime.parse(json['exportedAt'] as String),
    );
  }
}

/// Expense fields returned by Gemma before user confirmation.
final class ParsedExpense {
  /// Creates a parsed expense.
  const ParsedExpense({
    required this.amount,
    required this.currency,
    required this.date,
    required this.payee,
    required this.category,
    required this.confidence,
    required this.reason,
    required this.isPersonLike,
    this.transactionKind = TransactionKind.expense,
    this.paymentMethod = PaymentMethodKind.other,
    this.accountHint,
    this.sourceLabel,
    this.fundingSourceLabel,
  });

  static const _unset = Object();

  /// Parsed amount.
  final double amount;

  /// Parsed currency.
  final String currency;

  /// Parsed transaction date.
  final DateTime date;

  /// Parsed payee.
  final String payee;

  /// Parsed category.
  final ExpenseCategory category;

  /// Semantic type of the entry.
  final TransactionKind transactionKind;

  /// Payment method inferred from the message or chosen by the user.
  final PaymentMethodKind paymentMethod;

  /// Confidence from zero to one.
  final double confidence;

  /// Short reasoning.
  final String reason;

  /// Whether the payee looks like a person name.
  final bool isPersonLike;

  /// Optional masked account hint.
  final String? accountHint;

  /// User-visible payment source, such as a card or UPI alias.
  final String? sourceLabel;

  /// User-visible settlement or linked bank account.
  final String? fundingSourceLabel;

  /// Serializes parsed output.
  Map<String, Object?> toJson() => {
    'amount': amount,
    'currency': currency,
    'date': date.toIso8601String(),
    'payee': payee,
    'category': category.label,
    'transactionKind': transactionKind.label,
    'paymentMethod': paymentMethod.label,
    'confidence': confidence,
    'reason': reason,
    'isPersonLike': isPersonLike,
    'accountHint': accountHint,
    'sourceLabel': sourceLabel,
    'fundingSourceLabel': fundingSourceLabel,
  };

  /// Returns a modified copy.
  ParsedExpense copyWith({
    double? amount,
    String? currency,
    DateTime? date,
    String? payee,
    ExpenseCategory? category,
    TransactionKind? transactionKind,
    PaymentMethodKind? paymentMethod,
    double? confidence,
    String? reason,
    bool? isPersonLike,
    Object? accountHint = _unset,
    Object? sourceLabel = _unset,
    Object? fundingSourceLabel = _unset,
  }) {
    return ParsedExpense(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      payee: payee ?? this.payee,
      category: category ?? this.category,
      transactionKind: transactionKind ?? this.transactionKind,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      confidence: confidence ?? this.confidence,
      reason: reason ?? this.reason,
      isPersonLike: isPersonLike ?? this.isPersonLike,
      accountHint: identical(accountHint, _unset)
          ? this.accountHint
          : accountHint as String?,
      sourceLabel: identical(sourceLabel, _unset)
          ? this.sourceLabel
          : sourceLabel as String?,
      fundingSourceLabel: identical(fundingSourceLabel, _unset)
          ? this.fundingSourceLabel
          : fundingSourceLabel as String?,
    );
  }

  /// Deserializes parsed output.
  factory ParsedExpense.fromJson(Map<dynamic, dynamic> json) {
    return ParsedExpense(
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      date: DateTime.parse(json['date'] as String),
      payee: json['payee'] as String,
      category: ExpenseCategory.fromLabel(json['category'] as String?),
      transactionKind: TransactionKind.fromValue(
        json['transactionKind'] as String?,
      ),
      paymentMethod: PaymentMethodKind.fromValue(
        json['paymentMethod'] as String?,
      ),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      reason: json['reason'] as String? ?? 'Parsed on device.',
      isPersonLike: json['isPersonLike'] as bool? ?? false,
      accountHint: json['accountHint'] as String?,
      sourceLabel: json['sourceLabel'] as String?,
      fundingSourceLabel: json['fundingSourceLabel'] as String?,
    );
  }
}

/// SMS candidate queued for user review.
final class SmsCandidate {
  /// Creates an SMS candidate.
  const SmsCandidate({
    required this.id,
    required this.sender,
    required this.receivedAt,
    required this.bodyHash,
    required this.redactedPreview,
    required this.status,
    required this.proposedExpense,
    required this.modelReason,
    required this.createdAt,
  });

  /// Stable local identifier.
  final String id;

  /// SMS sender ID or phone number.
  final String sender;

  /// Device received time.
  final DateTime receivedAt;

  /// Hash of the raw body for deduplication.
  final String bodyHash;

  /// Redacted preview displayed to the user.
  final String redactedPreview;

  /// Review status.
  final SmsCandidateStatus status;

  /// Parsed expense proposal.
  final ParsedExpense proposedExpense;

  /// Model reasoning.
  final String modelReason;

  /// Local creation time.
  final DateTime createdAt;

  /// Returns a modified copy.
  SmsCandidate copyWith({
    SmsCandidateStatus? status,
    ParsedExpense? proposedExpense,
    String? modelReason,
  }) {
    return SmsCandidate(
      id: id,
      sender: sender,
      receivedAt: receivedAt,
      bodyHash: bodyHash,
      redactedPreview: redactedPreview,
      status: status ?? this.status,
      proposedExpense: proposedExpense ?? this.proposedExpense,
      modelReason: modelReason ?? this.modelReason,
      createdAt: createdAt,
    );
  }

  /// Serializes this candidate.
  Map<String, Object?> toJson() => {
    'id': id,
    'sender': sender,
    'receivedAt': receivedAt.toIso8601String(),
    'bodyHash': bodyHash,
    'redactedPreview': redactedPreview,
    'status': status.name,
    'proposedExpense': proposedExpense.toJson(),
    'modelReason': modelReason,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Deserializes a candidate from Hive JSON.
  factory SmsCandidate.fromJson(Map<dynamic, dynamic> json) {
    return SmsCandidate(
      id: json['id'] as String,
      sender: json['sender'] as String,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      bodyHash: json['bodyHash'] as String,
      redactedPreview: json['redactedPreview'] as String,
      status: SmsCandidateStatus.values.byName(
        json['status'] as String? ?? 'pending',
      ),
      proposedExpense: ParsedExpense.fromJson(
        json['proposedExpense'] as Map<dynamic, dynamic>,
      ),
      modelReason: json['modelReason'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Current model file lifecycle.
enum ModelAssetPhase {
  /// No model file exists.
  absent,

  /// Inspecting local file metadata.
  checking,

  /// Download is active.
  downloading,

  /// Model is available and size-verified.
  ready,

  /// Download was cancelled.
  cancelled,

  /// Operation failed.
  failed,
}

/// Gemma model status and download progress.
final class ModelAssetState {
  /// Creates a model asset state.
  const ModelAssetState({
    required this.phase,
    this.path,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0,
    this.eta,
    this.message,
  });

  /// Absent state.
  const ModelAssetState.absent() : this(phase: ModelAssetPhase.absent);

  /// Current phase.
  final ModelAssetPhase phase;

  /// Local model path.
  final String? path;

  /// Downloaded bytes.
  final int receivedBytes;

  /// Total bytes if known.
  final int totalBytes;

  /// Rolling download speed.
  final double bytesPerSecond;

  /// Estimated remaining time.
  final Duration? eta;

  /// User-safe status message.
  final String? message;

  /// Progress from zero to one.
  double get progress {
    if (totalBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0, 1).toDouble();
  }

  /// Whether model is ready.
  bool get isReady => phase == ModelAssetPhase.ready;

  /// Serializes state.
  Map<String, Object?> toJson() => {
    'phase': phase.name,
    'path': path,
    'receivedBytes': receivedBytes,
    'totalBytes': totalBytes,
    'bytesPerSecond': bytesPerSecond,
    'etaSeconds': eta?.inSeconds,
    'message': message,
  };

  /// Deserializes state.
  factory ModelAssetState.fromJson(Map<dynamic, dynamic> json) {
    return ModelAssetState(
      phase: ModelAssetPhase.values.byName(
        json['phase'] as String? ?? 'absent',
      ),
      path: json['path'] as String?,
      receivedBytes: json['receivedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      bytesPerSecond: (json['bytesPerSecond'] as num?)?.toDouble() ?? 0,
      eta: json['etaSeconds'] == null
          ? null
          : Duration(seconds: json['etaSeconds'] as int),
      message: json['message'] as String?,
    );
  }
}
