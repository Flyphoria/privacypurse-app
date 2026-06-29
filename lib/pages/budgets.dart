import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/budgets/addedit.dart';
import 'package:waterflyiii/pages/navigation.dart';

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage>
    with AutomaticKeepAliveClientMixin {
  final Logger log = Logger("Pages.Budgets");

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setAppBarActions());
  }

  void _setAppBarActions() {
    if (!mounted) {
      return;
    }
    context.read<NavPageElements>().appBarActions = <Widget>[
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: S.of(context).budgetTitleAdd,
        onPressed: () => _openDialog(null),
      ),
    ];
  }

  Future<void> _openDialog(BudgetRead? budget) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => BudgetAddEditDialog(budget: budget),
    );
    if (ok ?? false) {
      setState(() {});
    }
  }

  Future<List<BudgetRead>> _fetchBudgets() async {
    final Response<BudgetArray> resp = await context
        .read<FireflyService>()
        .api
        .v1BudgetsGet();
    apiThrowErrorIfEmpty(resp, mounted ? context : null);
    return resp.body!.data;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    log.finest(() => "build()");

    return RefreshIndicator.adaptive(
      onRefresh: () async => setState(() {}),
      child: FutureBuilder<List<BudgetRead>>(
        future: _fetchBudgets(),
        builder:
            (BuildContext context, AsyncSnapshot<List<BudgetRead>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                log.severe("Error loading budgets", snapshot.error);
                return Center(
                  child: Text(
                    S.of(context).budgetErrorLoading,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }
              final List<BudgetRead> budgets = snapshot.data!;
              if (budgets.isEmpty) {
                return ListView(
                  children: <Widget>[
                    const SizedBox(height: 80),
                    Center(child: Text(S.of(context).budgetsListEmpty)),
                  ],
                );
              }

              return ListView.separated(
                itemCount: budgets.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final BudgetRead budget = budgets[index];
                  final String? amount = budget.attributes.autoBudgetAmount;
                  final bool active = budget.attributes.active ?? true;
                  return ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(budget.attributes.name),
                    subtitle: (amount != null && amount.isNotEmpty)
                        ? Text(
                            "${context.read<FireflyService>().defaultCurrency.attributes.symbol}$amount",
                          )
                        : null,
                    trailing: active
                        ? null
                        : Chip(label: Text(S.of(context).billsInactive)),
                    onTap: () => _openDialog(budget),
                  );
                },
              );
            },
      ),
    );
  }
}
