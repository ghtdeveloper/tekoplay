import 'package:flutter/material.dart';
import '../../../generated/l10n.dart';
import 'package:flutter/services.dart';

class WithdrawalDialog extends StatefulWidget {
  final int withdrawableAmount;
  final Function(int amount) onWithdraw;

  const WithdrawalDialog({
    super.key,
    required this.withdrawableAmount,
    required this.onWithdraw,
  });

  @override
  State<WithdrawalDialog> createState() => _WithdrawalDialogState();
}

class _WithdrawalDialogState extends State<WithdrawalDialog> {
  late TextEditingController _amountController;
  int selectedAmount = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectAmount(int amount) {
    setState(() {
      selectedAmount = amount;
      _amountController.text = amount.toString();
    });
  }

  void _processWithdrawal() async {
    if (selectedAmount <= 0 || selectedAmount > widget.withdrawableAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).invalidAmountToWithdraw),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      widget.onWithdraw(selectedAmount);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).withdrawProcessError),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quickAmounts = [
      if (widget.withdrawableAmount >= 50) 50,
      if (widget.withdrawableAmount >= 100) 100,
      if (widget.withdrawableAmount >= 250) 250,
      if (widget.withdrawableAmount >= 500) 500,
      if (widget.withdrawableAmount >= 1000) 1000,
    ].where((amount) => amount <= widget.withdrawableAmount).toList();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).withdrawDiamonds,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),

            SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.diamond, color: Colors.amber, size: 32),
                  SizedBox(height: 8),
                  Text(
                    S.of(context).availableToWithdraw,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${widget.withdrawableAmount} ${S.of(context).diamonds}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            if (quickAmounts.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                 S.of(context).quickAmounts,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickAmounts.map((amount) {
                  return GestureDetector(
                    onTap: isLoading ? null : () => _selectAmount(amount),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedAmount == amount
                            ? Color(0xFFEC7A34)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selectedAmount == amount
                              ? Color(0xFFEC7A34)
                              : Colors.grey[400]!,
                        ),
                      ),
                      child: Text(
                        '$amount',
                        style: TextStyle(
                          color: selectedAmount == amount
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
            ],

            // Campo de cantidad personalizada
            TextField(
              controller: _amountController,
              enabled: !isLoading,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) {
                setState(() {
                  selectedAmount = int.tryParse(value) ?? 0;
                });
              },
              decoration: InputDecoration(
                labelText: S.of(context).customAmount,
                hintText: S.of(context).enterAmountToWithdraw,
                prefixIcon: Icon(Icons.diamond, color: Colors.amber),
                suffixText: S.of(context).diamonds,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFEC7A34)),
                ),
              ),
            ),

            SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (isLoading || selectedAmount <= 0 || selectedAmount > widget.withdrawableAmount)
                    ? null
                    : _processWithdrawal,
                icon: isLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(Icons.account_balance_wallet),
                label: Text(
                  isLoading ? S.of(context).processing : S.of(context).requestWithdrawal,
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFEC7A34),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            SizedBox(height: 12),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                     S.of(context).withdrawalsProcessedIn,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}