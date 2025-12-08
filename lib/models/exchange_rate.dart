// models/exchange_rate.dart

class ExchangeRate {
  final String fromCrypto;
  final String toCrypto;
  final double rate;
  final DateTime timestamp;

  ExchangeRate({
    required this.fromCrypto,
    required this.toCrypto,
    required this.rate,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromCrypto': fromCrypto,
      'toCrypto': toCrypto,
      'rate': rate,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    return ExchangeRate(
      fromCrypto: json['fromCrypto'],
      toCrypto: json['toCrypto'],
      rate: (json['rate'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class ExchangePair {
  final String symbol;       // BTC, ETH, XRP
  final String name;         // Bitcoin, Ethereum, Ripple
  final String icon;         // ₿, ⟠, ✕
  final double balance;      // User's balance
  final double priceUSD;     // Current price in USD
  final String? imageUrl;    // Logo URL
  final String? coinId;      // CoinGecko ID (bitcoin, ethereum, ripple) - untuk Firebase reference

  ExchangePair({
    required this.symbol,
    required this.name,
    required this.icon,
    required this.balance,
    required this.priceUSD,
    this.imageUrl,
    this.coinId,
  });

  // Copy with method untuk update data
  ExchangePair copyWith({
    String? symbol,
    String? name,
    String? icon,
    double? balance,
    double? priceUSD,
    String? imageUrl,
    String? coinId,
  }) {
    return ExchangePair(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      balance: balance ?? this.balance,
      priceUSD: priceUSD ?? this.priceUSD,
      imageUrl: imageUrl ?? this.imageUrl,
      coinId: coinId ?? this.coinId,
    );
  }

  // Convert to JSON (untuk debugging atau storage)
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'icon': icon,
      'balance': balance,
      'priceUSD': priceUSD,
      'imageUrl': imageUrl,
      'coinId': coinId,
    };
  }

  @override
  String toString() {
    return 'ExchangePair(symbol: $symbol, balance: $balance, price: \$$priceUSD)';
  }
}