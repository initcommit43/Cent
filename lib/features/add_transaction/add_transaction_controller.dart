import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../data/providers.dart';
import 'amount_input.dart';

@immutable
class TransactionDraft {
  const TransactionDraft({
    required this.kind,
    required this.amount,
    required this.accountId,
    required this.occurredAt,
    this.editingId,
    this.toAccountId,
    this.categoryId,
    this.title = '',
    this.note = '',
  });

  /// Set when editing an existing entry (the sending half for transfers).
  final int? editingId;
  final TransactionKind kind;
  final AmountInput amount;
  final int accountId;
  final int? toAccountId;
  final int? categoryId;
  final String title;
  final String note;
  final DateTime occurredAt;

  bool get isTransfer => kind == TransactionKind.transfer;

  TransactionDraft copyWith({
    TransactionKind? kind,
    AmountInput? amount,
    int? accountId,
    int? toAccountId,
    int? categoryId,
    bool clearCategory = false,
    String? title,
    String? note,
    DateTime? occurredAt,
  }) => TransactionDraft(
    editingId: editingId,
    kind: kind ?? this.kind,
    amount: amount ?? this.amount,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId ?? this.toAccountId,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    title: title ?? this.title,
    note: note ?? this.note,
    occurredAt: occurredAt ?? this.occurredAt,
  );
}

/// State behind the add/edit sheet. Null until [startNew] or [startEdit]
/// has loaded accounts and categories.
class AddTransactionController extends Notifier<TransactionDraft?> {
  late Map<int, Account> _accounts;
  late List<Category> _categories;

  @override
  TransactionDraft? build() {
    // Riverpod pauses providers nobody listens to, so a one-off read of the
    // converter could wait forever. Listening keeps it live for the sheet.
    ref.listen(converterProvider, (_, _) {});
    return null;
  }

  Future<void> startNew({
    TransactionKind kind = TransactionKind.expense,
  }) async {
    await _load();
    final first = _accounts.values.first;
    state = TransactionDraft(
      kind: kind,
      amount: const AmountInput(),
      accountId: first.id,
      toAccountId: _otherAccount(first.id),
      categoryId: _defaultCategory(kind),
      occurredAt: ref.read(clockProvider)(),
    );
  }

  Future<void> startEdit(int entryId) async {
    await _load();
    final db = ref.read(databaseProvider);
    var entry = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(entryId))).getSingle();

    // A transfer is edited from its sending half.
    int? toAccountId;
    if (entry.kind == TransactionKind.transfer &&
        entry.transferPeerId != null) {
      final peer = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(entry.transferPeerId!))).getSingle();
      if (entry.amountMinor > 0) (entry, toAccountId) = (peer, entry.accountId);
      toAccountId ??= peer.accountId;
    }

    state = TransactionDraft(
      editingId: entry.id,
      kind: entry.kind,
      amount: AmountInput.fromMinor(
        entry.amountMinor,
        Currency.of(entry.currency),
      ),
      accountId: entry.accountId,
      toAccountId: toAccountId,
      categoryId: entry.categoryId,
      title: entry.title,
      note: entry.note ?? '',
      occurredAt: entry.occurredAt,
    );
  }

  Currency currencyOf(int accountId) =>
      Currency.of(_accounts[accountId]!.currency);

  Currency get currency => currencyOf(state!.accountId);

  Money get amount => state!.amount.toMoney(currency);

  /// What arrives in the destination account, converted when currencies
  /// differ. Null when no rate is available.
  Future<Money?> received() async {
    final draft = state!;
    if (!draft.isTransfer || draft.toAccountId == null) return null;
    final target = currencyOf(draft.toAccountId!);
    if (target == currency) return amount;
    final converter = await ref.read(converterProvider.future);
    return converter.canConvert(currency, target)
        ? converter.convert(amount, target)
        : null;
  }

  bool get canContinue {
    final draft = state;
    if (draft == null || draft.amount.isZero) return false;
    if (!draft.isTransfer) return true;
    return draft.toAccountId != null && draft.toAccountId != draft.accountId;
  }

  bool get canSave =>
      canContinue && (state!.isTransfer || state!.categoryId != null);

  void setKind(TransactionKind kind) {
    final draft = state!;
    if (draft.kind == kind) return;
    final category = _categories.where((c) => c.id == draft.categoryId);
    final keepCategory =
        category.isNotEmpty && category.first.kind.name == kind.name;
    state = draft.copyWith(
      kind: kind,
      toAccountId: draft.toAccountId ?? _otherAccount(draft.accountId),
      categoryId: keepCategory ? draft.categoryId : _defaultCategory(kind),
      clearCategory: !keepCategory && _defaultCategory(kind) == null,
    );
  }

  void pressKey(String key) =>
      state = state!.copyWith(amount: state!.amount.press(key, currency));

  void deleteKey() => state = state!.copyWith(amount: state!.amount.delete());

  void setAccount(int id) {
    final draft = state!;
    // Re-parse the typed text in case the new currency has no minor units.
    final amount = AmountInput.fromMinor(
      draft.amount.toMinor(currency),
      currencyOf(id),
    );
    state = draft.copyWith(
      accountId: id,
      amount: amount,
      toAccountId: draft.toAccountId == id ? _otherAccount(id) : null,
    );
  }

  void setToAccount(int id) => state = state!.copyWith(toAccountId: id);

  void setCategory(int id) => state = state!.copyWith(categoryId: id);

  void setTitle(String title) => state = state!.copyWith(title: title);

  void setNote(String note) => state = state!.copyWith(note: note);

  void setDate(DateTime at) => state = state!.copyWith(occurredAt: at);

  Future<void> save() async {
    final draft = state!;
    final repo = ref.read(transactionsRepositoryProvider);
    final title = draft.title.trim().isNotEmpty
        ? draft.title.trim()
        : _fallbackTitle(draft);
    final note = draft.note.trim().isEmpty ? null : draft.note.trim();

    if (draft.isTransfer) {
      final arrives = await received() ?? amount;
      if (draft.editingId != null) await repo.delete(draft.editingId!);
      await repo.addTransfer(
        fromAccountId: draft.accountId,
        toAccountId: draft.toAccountId!,
        sent: amount,
        received: arrives,
        title: title,
        occurredAt: draft.occurredAt,
        note: note,
      );
      return;
    }

    if (draft.editingId != null) {
      await repo.edit(
        draft.editingId!,
        kind: draft.kind,
        accountId: draft.accountId,
        categoryId: draft.categoryId,
        amount: amount,
        title: title,
        occurredAt: draft.occurredAt,
        note: note,
      );
    } else {
      await repo.add(
        kind: draft.kind,
        accountId: draft.accountId,
        categoryId: draft.categoryId,
        amount: amount,
        title: title,
        occurredAt: draft.occurredAt,
        note: note,
      );
    }
  }

  String _fallbackTitle(TransactionDraft draft) {
    if (draft.isTransfer) {
      return '${_accounts[draft.accountId]!.name} → '
          '${_accounts[draft.toAccountId]!.name}';
    }
    return _categories.firstWhere((c) => c.id == draft.categoryId).name;
  }

  Future<void> _load() async {
    final accounts = await ref
        .read(accountsRepositoryProvider)
        .watchAll()
        .first;
    _accounts = {for (final a in accounts) a.account.id: a.account};
    _categories = await ref.read(categoriesRepositoryProvider).watchAll().first;
  }

  int? _otherAccount(int id) =>
      _accounts.keys.where((k) => k != id).firstOrNull;

  int? _defaultCategory(TransactionKind kind) {
    if (kind == TransactionKind.transfer) return null;
    final wanted = kind == TransactionKind.income
        ? CategoryKind.income
        : CategoryKind.expense;
    return _categories.where((c) => c.kind == wanted).firstOrNull?.id;
  }
}

final addTransactionControllerProvider =
    NotifierProvider.autoDispose<AddTransactionController, TransactionDraft?>(
      AddTransactionController.new,
    );
