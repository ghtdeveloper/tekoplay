import 'package:flutter/material.dart';

class WithdrawalCounterWidget extends StatelessWidget {
  final int withdrawableAmount;
  final VoidCallback onWithdraw;

  const WithdrawalCounterWidget({
    super.key,
    required this.withdrawableAmount,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: withdrawableAmount > 0 ? onWithdraw : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: withdrawableAmount > 0
              ? Colors.green.withValues(alpha: 0.8)
              : Colors.grey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              withdrawableAmount.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (withdrawableAmount > 0) ...[
              SizedBox(width: 4),
              Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}