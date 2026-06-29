import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

final Logger log = Logger("Pages.Budgets.AddEdit");

String budgetPeriodLabel(BuildContext context, AutoBudgetPeriod period) {
  switch (period) {
    case AutoBudgetPeriod.daily:
      return S.of(context).freqDaily;
    case AutoBudgetPeriod.weekly:
      return S.of(context).freqWeekly;
    case AutoBudgetPeriod.monthly:
      return S.of(context).freqMonthly;
    case AutoBudgetPeriod.quarterly:
      return S.of(context).freqQuarterly;
    case AutoBudgetPeriod.halfYear:
      return S.of(context).freqHalfYearly;
    case AutoBudgetPeriod.yearly:
      return S.of(context).freqYearly;
    default:
      return period.value ?? "";
  }
}

/// Add/edit/delete dialog for a budget. A non-empty "amount per period" sets a
/// recurring auto-budget (type "reset"), which is the simplest way to give a
/// budget a periodic spending limit without managing per-period limit entities.
/// [budget] null = create.
class BudgetAddEditDialog extends StatefulWidget {
  const BudgetAddEditDialog({super.key, this.budget});

  final BudgetRead? budget;

  @override
  State<BudgetAddEditDialog> createState() => _BudgetAddEditDialogState();
}

class _BudgetAddEditDialogState extends State<BudgetAddEditDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  AutoBudgetPeriod _period = AutoBudgetPeriod.monthly;
  bool _active = true;

  @override
  void initState() {
    super.initState();

    final BudgetRead? budget = widget.budget;
    if (budget != null) {
      nameController.text = budget.attributes.name;
      amountController.text = budget.attributes.autoBudgetAmount ?? "";
      notesController.text = budget.attributes.notes ?? "";
      _active = budget.attributes.active ?? true;
      final AutoBudgetPeriod? period = budget.attributes.autoBudgetPeriod;
      if (period != null &&
          period != AutoBudgetPeriod.swaggerGeneratedUnknown &&
          period != AutoBudgetPeriod.$null) {
        _period = period;
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
    final S l10n = S.of(context);
    final FireflyService ff = context.read<FireflyService>();
    final String amount = amountController.text.trim();
    final bool hasAmount = amount.isNotEmpty;
    final String currencyCode = ff.defaultCurrency.attributes.code;

    late Response<BudgetSingle> resp;
    if (widget.budget == null) {
      resp = await ff.api.v1BudgetsPost(
        body: BudgetStore(
          name: nameController.text,
          active: _active,
          notes: notesController.text,
          autoBudgetType: hasAmount ? AutoBudgetType.reset : null,
          autoBudgetAmount: hasAmount ? amount : null,
          autoBudgetPeriod: hasAmount ? _period : null,
          autoBudgetCurrencyCode: hasAmount ? currencyCode : null,
        ),
      );
    } else {
      resp = await ff.api.v1BudgetsIdPut(
        id: widget.budget!.id,
        body: BudgetUpdate(
          name: nameController.text,
          active: _active,
          notes: notesController.text,
          autoBudgetType: hasAmount ? AutoBudgetType.reset : null,
          autoBudgetAmount: hasAmount ? amount : null,
          autoBudgetPeriod: hasAmount ? _period : null,
          autoBudgetCurrencyCode: hasAmount ? currencyCode : null,
        ),
      );
    }

    if (!resp.isSuccessful || resp.body == null) {
      String error;
      try {
        final ValidationErrorResponse valError = ValidationErrorResponse.fromJson(
          json.decode(resp.error.toString()),
        );
        error = valError.message ?? l10n.errorUnknown;
      } catch (_) {
        error = l10n.errorUnknown;
      }
      msg.showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete() async {
    final FireflyIii api = context.read<FireflyService>().api;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: const Icon(Icons.delete),
        title: Text(S.of(context).budgetTitleDelete),
        content: Text(S.of(context).budgetDeleteConfirm),
        actions: <Widget>[
          TextButton(
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            child: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) {
      return;
    }
    await api.v1BudgetsIdDelete(id: widget.budget!.id);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double inputWidth = MediaQuery.of(context).size.width - 128 - 24;

    return AlertDialog(
      icon: const Icon(Icons.account_balance_wallet),
      title: Text(
        widget.budget == null
            ? S.of(context).budgetTitleAdd
            : S.of(context).budgetTitleEdit,
      ),
      clipBehavior: Clip.hardEdge,
      actions: <Widget>[
        if (widget.budget != null)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(context).colorScheme.errorContainer,
              ),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _delete,
            child: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
          ),
        TextButton(
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: inputWidth,
              child: TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.title),
                  border: const OutlineInputBorder(),
                  labelText: S.of(context).categoryFormLabelName,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: inputWidth,
              child: TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.attach_money),
                  border: const OutlineInputBorder(),
                  labelText: S.of(context).budgetFormLabelAmount,
                  helperText: S.of(context).budgetFormLabelAmountHelp,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: inputWidth,
              child: DropdownButtonFormField<AutoBudgetPeriod>(
                initialValue: _period,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.repeat),
                  border: const OutlineInputBorder(),
                  labelText: S.of(context).budgetFormLabelPeriod,
                ),
                items: <AutoBudgetPeriod>[
                  AutoBudgetPeriod.daily,
                  AutoBudgetPeriod.weekly,
                  AutoBudgetPeriod.monthly,
                  AutoBudgetPeriod.quarterly,
                  AutoBudgetPeriod.halfYear,
                  AutoBudgetPeriod.yearly,
                ].map((AutoBudgetPeriod period) {
                  return DropdownMenuItem<AutoBudgetPeriod>(
                    value: period,
                    child: Text(budgetPeriodLabel(context, period)),
                  );
                }).toList(),
                onChanged: (AutoBudgetPeriod? value) {
                  if (value != null) {
                    setState(() => _period = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: inputWidth,
              child: TextFormField(
                controller: notesController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.description),
                  border: const OutlineInputBorder(),
                  labelText: S.of(context).transactionFormLabelNotes,
                ),
                minLines: 1,
                maxLines: 5,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: inputWidth,
              child: SwitchListTile.adaptive(
                title: Text(S.of(context).formLabelActive),
                value: _active,
                isThreeLine: false,
                onChanged: (bool value) => setState(() => _active = value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
