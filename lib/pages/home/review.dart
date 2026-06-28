import 'package:flutter/material.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/transactions.dart';
import 'package:waterflyiii/pages/home/transactions/filter.dart';

/// The PrivacyPurse "needs review" queue — the signature screen of the
/// review-centric product: bank transactions are imported and auto-categorized
/// server-side, and anything the rules could not categorize lands here for the
/// user to quickly assign a category.
///
/// It reuses [HomeTransactions] (list, pagination, date grouping, tap-to-edit,
/// swipe-to-delete) with a fixed "no category" filter, which the list turns into
/// a `has_no_category:true` search.
///
/// Note: this currently means "uncategorized", so own-account transfers (which
/// never carry a category) can also appear. A tighter definition — e.g. a
/// backend "review" tag applied by the import/auto-categorization flow — is a
/// planned refinement.
class HomeReview extends StatelessWidget {
  const HomeReview({super.key});

  /// Sentinel category whose id "-1" the transaction list maps to
  /// `has_no_category:true` (see [HomeTransactions]'s `_fetchPage`).
  static const CategoryRead _noCategory = CategoryRead(
    id: "-1",
    type: "dummy",
    attributes: CategoryProperties(name: ""),
  );

  @override
  Widget build(BuildContext context) {
    return HomeTransactions(
      key: const ValueKey<String>("needs-review"),
      filters: TransactionFilters(category: _noCategory),
    );
  }
}
