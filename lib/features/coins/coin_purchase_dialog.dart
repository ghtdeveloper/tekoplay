import 'package:flutter/material.dart';

import '../../generated/l10n.dart';

class CoinPurchaseDialog extends StatelessWidget {
  final Function(int coinAmount, int price)? onPurchase;

  const CoinPurchaseDialog({
    super.key,
    this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEC7A34),
              Color(0xFFD4661F),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Column(
                        children: [
                          Text(
                            S.of(context).getMoreCoins,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEC7A34),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            S.of(context).choosePerfectPackage,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          children: [
                            _buildCoinPackage(
                              context,
                              coins: 490,
                              price: 2,
                              isPopular: false,
                            ),
                            SizedBox(height: 12),

                            _buildCoinPackage(
                              context,
                              coins: 1020,
                              price: 4,
                              isPopular: true,
                              popularText: S.of(context).mostPopular,
                            ),
                            SizedBox(height: 12),

                            _buildCoinPackage(
                              context,
                              coins: 2200,
                              price: 8,
                              isPopular: false,
                            ),
                            SizedBox(height: 12),

                            _buildCoinPackage(
                              context,
                              coins: 4600,
                              price: 16,
                              isPopular: false,
                            ),
                            SizedBox(height: 12),

                            _buildCoinPackage(
                              context,
                              coins: 9500,
                              price: 33,
                              isPopular: false,
                            ),
                            SizedBox(height: 12),

                            _buildCoinPackage(
                              context,
                              coins: 20000,
                              price: 66,
                              isPopular: false,
                            ),
                            SizedBox(height: 12),

                            _buildCoinPackage(
                              context,
                              coins: 100000,
                              price: 315,
                              isPopular: false,
                              isBestValue: true,
                              bestValueText: S.of(context).bestValue,
                            ),
                            SizedBox(height: 12),

                            _buildCoinPackage(
                              context,
                              coins: 1000000,
                              price: 3125,
                              isPopular: false,
                              isMegaPack: true,
                              megaPackText: S.of(context).megaPack,
                            ),
                            SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.monetization_on,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                S.of(context).coinStore,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinPackage(
      BuildContext context, {
        required int coins,
        required int price,
        bool isPopular = false,
        bool isBestValue = false,
        bool isMegaPack = false,
        String? popularText,
        String? bestValueText,
        String? megaPackText,
      }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isPopular
                  ? [Color(0xFFFFD700).withValues(alpha: 0.1), Color(0xFFFFD700).withValues(alpha:0.05)]
                  : isBestValue
                  ? [Color(0xFF4CAF50).withValues(alpha:0.1), Color(0xFF4CAF50).withValues(alpha:0.05)]
                  : isMegaPack
                  ? [Color(0xFF9C27B0).withValues(alpha:0.1), Color(0xFF9C27B0).withValues(alpha:0.05)]
                  : [Colors.grey[50]!, Colors.white],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPopular
                  ? Color(0xFFFFD700)
                  : isBestValue
                  ? Color(0xFF4CAF50)
                  : isMegaPack
                  ? Color(0xFF9C27B0)
                  : Colors.grey[300]!,
              width: isPopular || isBestValue || isMegaPack ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isMegaPack
                    ? Color(0xFF9C27B0).withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: isMegaPack ? 12 : 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: isMegaPack ? 45 : 40,
                  height: isMegaPack ? 45 : 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isMegaPack
                          ? [Color(0xFF9C27B0), Color(0xFF7B1FA2)]
                          : [Color(0xFFFFD700), Color(0xFFFFB300)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isMegaPack ? Color(0xFF9C27B0) : Color(0xFFFFD700))
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isMegaPack ? Icons.stars : Icons.monetization_on,
                    color: Colors.white,
                    size: isMegaPack ? 26 : 24,
                  ),
                ),

                SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Coin amount
                      Text(
                        _formatCoins(coins),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isMegaPack
                              ? Color(0xFF9C27B0)
                              : Color(0xFFEC7A34),
                        ),
                      ),
                      SizedBox(height: 2),
                      // Price in USD
                      Text(
                        '\$${_formatPrice(price)} USD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),

                // Buy button
                ElevatedButton(
                  onPressed: () {
                    if (onPurchase != null) {
                      onPurchase!(coins, price);
                    }
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular
                        ? Color(0xFFFFD700)
                        : isBestValue
                        ? Color(0xFF4CAF50)
                        : isMegaPack
                        ? Color(0xFF9C27B0)
                        : Color(0xFFEC7A34),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: isMegaPack ? 5 : 3,
                  ),
                  child: Text(
                    S.of(context).buy,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (isPopular || isBestValue || isMegaPack)
          Positioned(
            top: -8,
            left: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPopular
                      ? [Color(0xFFFFD700), Color(0xFFFFB300)]
                      : isBestValue
                      ? [Color(0xFF4CAF50), Color(0xFF45A049)]
                      : [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (isPopular
                        ? Color(0xFFFFD700)
                        : isBestValue
                        ? Color(0xFF4CAF50)
                        : Color(0xFF9C27B0))
                        .withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                isPopular
                    ? (popularText ?? S.of(context).popular)
                    : isBestValue
                    ? (bestValueText ?? S.of(context).bestValue)
                    : (megaPackText ?? S.of(context).megaPack),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(coins % 1000000 == 0 ? 0 : 1)}M';
    } else if (coins >= 1000) {
      return '${(coins / 1000).toStringAsFixed(coins % 1000 == 0 ? 0 : 1)}K';
    }
    return coins.toString();
  }

  String _formatPrice(int price) {
    if (price >= 1000) {
      return price.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
      );
    }
    return price.toString();
  }
}

void showCoinPurchaseDialog(
    BuildContext context, {
      Function(int coinAmount, int price)? onPurchase,
    }) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => CoinPurchaseDialog(
      onPurchase: onPurchase,
    ),
  );
}