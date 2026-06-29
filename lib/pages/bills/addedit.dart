import 'dart:convert';

import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

final Logger log = Logger("Pages.Bills.AddEdit");

String billFreqLabel(BuildContext context, BillRepeatFrequency freq) {
  switch (freq) {
    case BillRepeatFrequency.weekly:
      return S.of(context).freqWeekly;
    case BillRepeatFrequency.monthly:
      return S.of(context).freqMonthly;
    case BillRepeatFrequency.quarterly:
      return S.of(context).freqQuarterly;
    case BillRepeatFrequency.halfYear:
      return S.of(context).freqHalfYearly;
    case BillRepeatFrequency.yearly:
      return S.of(context).freqYearly;
    default:
      return freq.value ?? "";
  }
}

/// Add/edit/delete dialog for a bill (subscription). Mirrors the category
/// add/edit dialog. [bill] null = create.
class BillAddEditDialog extends StatefulWidget {
  const BillAddEditDialog({super.key, this.bill});

  final BillRead? bill;

  @override
  State<BillAddEditDialog> createState() => _BillAddEditDialogState();
}

class _BillAddEditDialogState extends State<BillAddEditDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController amountMinController = TextEditingController();
  final TextEditingController amountMaxController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  BillRepeatFrequency _repeatFreq = BillRepeatFrequency.monthly;
  late DateTime _date;
  bool _active = true;

  @override
  void initState() {
    super.initState();

    _date = DateTime.now();

    final BillRead? bill = widget.bill;
    if (bill != null) {
      nameController.text = bill.attributes.name ?? "";
      amountMinController.text = bill.attributes.amountMin ?? "";
      amountMaxController.text = bill.attributes.amountMax ?? "";
      notesController.text = bill.attributes.notes ?? "";
      _active = bill.attributes.active ?? true;
      _date = bill.attributes.date ?? _date;
      final BillRepeatFrequency? freq = bill.attributes.repeatFreq;
      if (freq != null &&
          freq != BillRepeatFrequency.swaggerGeneratedUnknown) {
        _repeatFreq = freq;
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    amountMinController.dispose();
    amountMaxController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
    final S l10n = S.of(context);
    final FireflyService ff = context.read<FireflyService>();
    final String currencyCode =
        widget.bill?.attributes.currencyCode ??
        ff.defaultCurrency.attributes.code;

    late Response<BillSingle> resp;
    if (widget.bill == null) {
      resp = await ff.api.v1BillsPost(
        body: BillStore(
          name: nameController.text,
          amountMin: amountMinController.text,
          amountMax: amountMaxController.text,
          date: _date,
          repeatFreq: _repeatFreq,
          active: _active,
          notes: notesController.text,
          currencyCode: currencyCode,
        ),
      );
    } else {
      resp = await ff.api.v1BillsIdPut(
        id: widget.bill!.id,
        body: BillUpdate(
          name: nameController.text,
          amountMin: amountMinController.text,
          amountMax: amountMaxController.text,
          date: _date,
          repeatFreq: _repeatFreq,
          active: _active,
          notes: notesController.text,
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
        title: Text(S.of(context).billTitleDelete),
        content: Text(S.of(context).billDeleteConfirm),
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
    await api.v1BillsIdDelete(id: widget.bill!.id);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double inputWidth = MediaQuery.of(context).size.width - 128 - 24;

    return AlertDialog(
      icon: const Icon(Icons.receipt_long),
      title: Text(
        widget.bill == null
            ? S.of(context).billTitleAdd
            : S.of(context).billTitleEdit,
      ),
      clipBehavior: Clip.hardEdge,
      actions: <Widget>[
        if (widget.bill != null)
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
                controller: amountMinController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.expand_more),
                  border: const OutlineInputBorder(),
                  labelText: S.of(context).billFormLabelAmountMin,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: inputWidth,
              child: TextFormField(
                controller: amountMaxController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.expand_less),
                  border: const OutlineInputBorder(),
                  labelText: S.of(context).billFormLabelAmountMax,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: inputWidth,
              child: DropdownButtonFormField<BillRepeatFrequency>(
                initialValue: _repeatFreq,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.repeat),
                  border: const OutlineInputBorder(),
                  labelText: S.of(context).billFormLabelFrequency,
                ),
                items: <BillRepeatFrequency>[
                  BillRepeatFrequency.weekly,
                  BillRepeatFrequency.monthly,
                  BillRepeatFrequency.quarterly,
                  BillRepeatFrequency.halfYear,
                  BillRepeatFrequency.yearly,
                ].map((BillRepeatFrequency freq) {
                  return DropdownMenuItem<BillRepeatFrequency>(
                    value: freq,
                    child: Text(billFreqLabel(context, freq)),
                  );
                }).toList(),
                onChanged: (BillRepeatFrequency? value) {
                  if (value != null) {
                    setState(() => _repeatFreq = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: inputWidth,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  "${S.of(context).billFormLabelDate}: "
                  "${DateFormat.yMd().format(_date)}",
                ),
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
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
