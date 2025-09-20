import 'package:flutter/material.dart';

import '../../generated/l10n.dart';

class DiamondPurchaseDialog extends StatelessWidget {
  final Function(int diamondAmount, int price)? onPurchase;

  const DiamondPurchaseDialog({
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
          maxHeight: MediaQuery.of(context).size.height * 0.9, // Aumentado a 90%
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6A5ACD),
              Color(0xFF483D8B),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header fijo
            _buildHeader(context),

            // Contenido scrolleable
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
                    // Título fijo
                    Padding(
                      padding: EdgeInsets.only(top: 20, left: 20, right: 20),
                      child: Column(
                        children: [
                          Text(
                            S.of(context).getMoreDiamonds,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6A5ACD),
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

                    // Lista scrolleable de paquetes
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        physics: BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _buildDiamondPackage(
                              context,
                              diamonds: 49,
                              price: 2,
                              isPopular: false,
                            ),
                            SizedBox(height: 12),

                            _buildDiamondPackage(
                              context,
                              diamonds: 102,
                              price: 4,
                              isPopular: true,
                              popularText: S.of(context).mostPopular,
                            ),
                            SizedBox(height: 12),

                            _buildDiamondPackage(
                              context,
                              diamonds: 220,
                              price: 8,
                              isPopular: false,
                            ),
                            SizedBox(height: 12),

                            _buildDiamondPackage(
                              context,
                              diamonds: 460,
                              price: 16,
                              isPopular: false,
                            ),
                            SizedBox(height: 12),

                            _buildDiamondPackage(
                              context,
                              diamonds: 950,
                              price: 32,
                              isPopular: false,
                            ),
                            SizedBox(height: 12),

                            _buildDiamondPackage(
                              context,
                              diamonds: 2000,
                              price: 64,
                              isPopular: false,
                            ),
                            SizedBox(height: 12),

                            _buildDiamondPackage(
                              context,
                              diamonds: 10000,
                              price: 315,
                              isPopular: false,
                              isBestValue: true,
                              bestValueText: S.of(context).bestValue,
                            ),
                            SizedBox(height: 12),

                            _buildDiamondPackage(
                              context,
                              diamonds: 100000,
                              price: 3125,
                              isPopular: false,
                              isMegaPack: true,
                              megaPackText: S.of(context).megaPack,
                            ),

                            // Padding extra al final para mejor UX
                            SizedBox(height: 20),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.diamond,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                S.of(context).diamondStore,
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

  Widget _buildDiamondPackage(
      BuildContext context, {
        required int diamonds,
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
                  ? [Color(0xFF00BFFF).withOpacity(0.1), Color(0xFF00BFFF).withOpacity(0.05)]
                  : isBestValue
                  ? [Color(0xFF32CD32).withOpacity(0.1), Color(0xFF32CD32).withOpacity(0.05)]
                  : isMegaPack
                  ? [Color(0xFF8A2BE2).withOpacity(0.1), Color(0xFF8A2BE2).withOpacity(0.05)]
                  : [Colors.grey[50]!, Colors.white],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPopular
                  ? Color(0xFF00BFFF)
                  : isBestValue
                  ? Color(0xFF32CD32)
                  : isMegaPack
                  ? Color(0xFF8A2BE2)
                  : Colors.grey[300]!,
              width: isPopular || isBestValue || isMegaPack ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isMegaPack
                    ? Color(0xFF8A2BE2).withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: isMegaPack ? 12 : 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Diamond icon
                Container(
                  width: isMegaPack ? 45 : 40,
                  height: isMegaPack ? 45 : 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isMegaPack
                          ? [Color(0xFF8A2BE2), Color(0xFF6A1B9A)]
                          : [Color(0xFF00BFFF), Color(0xFF1E90FF)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isMegaPack ? Color(0xFF8A2BE2) : Color(0xFF00BFFF))
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isMegaPack ? Icons.auto_awesome : Icons.diamond,
                    color: Colors.white,
                    size: isMegaPack ? 26 : 24,
                  ),
                ),

                SizedBox(width: 16),

                // Diamond amount and price in vertical layout
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Diamond amount
                      Text(
                        _formatDiamonds(diamonds),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isMegaPack
                              ? Color(0xFF8A2BE2)
                              : Color(0xFF6A5ACD),
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
                      onPurchase!(diamonds, price);
                    }
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular
                        ? Color(0xFF00BFFF)
                        : isBestValue
                        ? Color(0xFF32CD32)
                        : isMegaPack
                        ? Color(0xFF8A2BE2)
                        : Color(0xFF6A5ACD),
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
                      ? [Color(0xFF00BFFF), Color(0xFF1E90FF)]
                      : isBestValue
                      ? [Color(0xFF32CD32), Color(0xFF228B22)]
                      : [Color(0xFF8A2BE2), Color(0xFF6A1B9A)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (isPopular
                        ? Color(0xFF00BFFF)
                        : isBestValue
                        ? Color(0xFF32CD32)
                        : Color(0xFF8A2BE2))
                        .withOpacity(0.3),
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

  String _formatDiamonds(int diamonds) {
    if (diamonds >= 1000000) {
      return '${(diamonds / 1000000).toStringAsFixed(diamonds % 1000000 == 0 ? 0 : 1)}M';
    } else if (diamonds >= 1000) {
      return '${(diamonds / 1000).toStringAsFixed(diamonds % 1000 == 0 ? 0 : 1)}K';
    }
    return diamonds.toString();
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

void showDiamondPurchaseDialog(
    BuildContext context, {
      Function(int diamondAmount, int price)? onPurchase,
    }) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => DiamondPurchaseDialog(
      onPurchase: onPurchase,
    ),
  );
}