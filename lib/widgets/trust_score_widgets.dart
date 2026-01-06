import 'package:flutter/material.dart';
import '../services/trust_score_service.dart';

class TrustScoreBadge extends StatelessWidget {
  final int score;
  final bool showLabel;
  final double size;

  const TrustScoreBadge({
    Key? key,
    required this.score,
    this.showLabel = true,
    this.size = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tierInfo = TrustScoreService.getTierFromScore(score);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(tierInfo['color']).withOpacity(0.1),
        border: Border.all(color: Color(tierInfo['color']), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tierInfo['badge'],
            style: TextStyle(fontSize: size),
          ),
          SizedBox(width: 4),
          Text(
            score.toString(),
            style: TextStyle(
              fontSize: size * 0.75,
              fontWeight: FontWeight.bold,
              color: Color(tierInfo['color']),
            ),
          ),
          if (showLabel) ...[
            SizedBox(width: 4),
            Text(
              tierInfo['tier'],
              style: TextStyle(
                fontSize: size * 0.6,
                fontWeight: FontWeight.w600,
                color: Color(tierInfo['color']),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TrustScoreCard extends StatelessWidget {
  final int score;
  final VoidCallback? onTap;

  const TrustScoreCard({
    Key? key,
    required this.score,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tierInfo = TrustScoreService.getTierFromScore(score);
    
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(tierInfo['color']).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      tierInfo['badge'],
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trust Score',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              score.toString(),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Color(tierInfo['color']),
                              ),
                            ),
                            Text(
                              ' / 100',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(tierInfo['color']),
                  ),
                  minHeight: 8,
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tierInfo['tier'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(tierInfo['color']),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                tierInfo['description'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoinBalance extends StatelessWidget {
  final int balance;
  final bool showLabel;
  final double iconSize;

  const CoinBalance({
    Key? key,
    required this.balance,
    this.showLabel = true,
    this.iconSize = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '🪙',
          style: TextStyle(fontSize: iconSize),
        ),
        SizedBox(width: 4),
        Text(
          balance.toString(),
          style: TextStyle(
            fontSize: iconSize * 0.9,
            fontWeight: FontWeight.bold,
            color: Colors.amber[700],
          ),
        ),
        if (showLabel) ...[
          SizedBox(width: 4),
          Text(
            'coins',
            style: TextStyle(
              fontSize: iconSize * 0.7,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}
