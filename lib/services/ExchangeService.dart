// services/exchange_service.dart
import '../models/crypto_asset.dart';
import '../models/exchange_rate.dart';
import 'crypto_service.dart';
import 'wallet_service.dart';

class ExchangeService {
  final CryptoService _cryptoService = CryptoService();
  final WalletService _walletService = WalletService();

  // Mapping symbol ke CoinGecko ID
  final Map<String, String> _symbolToCoinId = {
    'BTC': 'bitcoin',
    'ETH': 'ethereum',
    'XRP': 'ripple',
    'BNB': 'binancecoin',
    'ADA': 'cardano',
    'SOL': 'solana',
    'USDT': 'tether',
    'USDC': 'usd-coin',
    'DOGE': 'dogecoin',
    'DOT': 'polkadot',
    'MATIC': 'matic-network',
    'AVAX': 'avalanche-2',
    'SHIB': 'shiba-inu',
    'LTC': 'litecoin',
    'LINK': 'chainlink',
  };

  // Mapping CoinGecko ID ke symbol
  Map<String, String> get _coinIdToSymbol =>
      _symbolToCoinId.map((key, value) => MapEntry(value, key));

  // Icon mapping untuk crypto
  final Map<String, String> _symbolToIcon = {
    'BTC': '₿',
    'ETH': '⟠',
    'XRP': '✕',
    'BNB': 'B',
    'ADA': '₳',
    'SOL': '◎',
    'USDT': '₮',
    'USDC': '\$',
    'DOGE': 'Ð',
    'DOT': '●',
    'MATIC': '◆',
    'AVAX': '▲',
    'SHIB': '🐕',
    'LTC': 'Ł',
    'LINK': '⬡',
  };

  // Get available cryptocurrencies for exchange dengan balance user
  Future<List<ExchangePair>> getAvailableExchangePairs() async {
    try {
      print('\n🔄 Getting available exchange pairs...');

      // Step 1: Fetch crypto prices from CoinGecko
      print('   Step 1: Fetching crypto prices...');
      final cryptoAssets = await _cryptoService.fetchCryptoAssets(limit: 15);

      // Step 2: Fetch user portfolio (balances) - menggunakan getPortfolio() yang sudah ada
      print('   Step 2: Fetching user portfolio...');
      final userBalances = await _walletService.getPortfolio();

      // Step 3: Combine data
      print('   Step 3: Combining data...');
      final List<ExchangePair> pairs = [];

      for (final asset in cryptoAssets) {
        final symbol = asset.symbol.toUpperCase();
        // Portfolio menggunakan coinId (bitcoin, ethereum) bukan symbol (BTC, ETH)
        final coinId = asset.id.toLowerCase();
        final balance = userBalances[coinId] ?? 0.0;

        pairs.add(ExchangePair(
          symbol: symbol,
          name: asset.name,
          icon: _symbolToIcon[symbol] ?? asset.icon,
          balance: balance,
          priceUSD: asset.priceUSD,
          imageUrl: asset.imageUrl,
          coinId: coinId, // Tambahkan coinId untuk referensi Firebase
        ));
      }

      // Sort: crypto dengan balance > 0 di atas
      pairs.sort((a, b) {
        if (a.balance > 0 && b.balance == 0) return -1;
        if (a.balance == 0 && b.balance > 0) return 1;
        return b.priceUSD.compareTo(a.priceUSD);
      });

      print('✅ Successfully prepared ${pairs.length} exchange pairs');
      print('   User has balance in: ${userBalances.keys.join(", ")}');

      return pairs;

    } catch (e) {
      print('❌ Error getting exchange pairs: $e');
      rethrow;
    }
  }

  // Get specific crypto pair with balance
  Future<ExchangePair> getCryptoPairBySymbol(String symbol) async {
    try {
      final coinId = _symbolToCoinId[symbol.toUpperCase()];
      if (coinId == null) {
        throw Exception('Unsupported crypto: $symbol');
      }

      // Fetch crypto data
      final asset = await _cryptoService.fetchSingleCrypto(coinId);

      // Fetch user balance - menggunakan getPortfolio() yang sudah ada
      final userBalances = await _walletService.getPortfolio();
      final balance = userBalances[coinId] ?? 0.0;

      return ExchangePair(
        symbol: asset.symbol.toUpperCase(),
        name: asset.name,
        icon: _symbolToIcon[asset.symbol.toUpperCase()] ?? asset.icon,
        balance: balance,
        priceUSD: asset.priceUSD,
        imageUrl: asset.imageUrl,
        coinId: coinId,
      );

    } catch (e) {
      print('❌ Error getting crypto pair: $e');
      rethrow;
    }
  }

  // Calculate exchange rate
  double calculateExchangeRate(
      ExchangePair fromCrypto,
      ExchangePair toCrypto,
      ) {
    return fromCrypto.priceUSD / toCrypto.priceUSD;
  }

  // Calculate network fee (0.1% of transaction value)
  double calculateNetworkFee(double fromAmount, double priceUSD) {
    return fromAmount * 0.001; // 0.1% fee
  }

  // Execute exchange - menggunakan updatePortfolio() yang sudah ada
  Future<void> executeExchange({
    required ExchangePair fromCrypto,
    required ExchangePair toCrypto,
    required double fromAmount,
    required double toAmount,
    required double exchangeRate,
    required double networkFee,
  }) async {
    try {
      print('\n💱 Executing exchange...');
      print('   From: $fromAmount ${fromCrypto.symbol}');
      print('   To: $toAmount ${toCrypto.symbol}');
      print('   Rate: $exchangeRate');
      print('   Fee: $networkFee ${fromCrypto.symbol}');

      // Validate balance
      if (fromAmount > fromCrypto.balance) {
        throw Exception('Insufficient balance');
      }

      if (fromAmount <= 0 || toAmount <= 0) {
        throw Exception('Invalid amount');
      }

      // Deduct network fee from fromAmount
      final actualFromAmount = fromAmount + networkFee;

      if (actualFromAmount > fromCrypto.balance) {
        throw Exception('Insufficient balance to cover network fee');
      }

      // Calculate new balances
      final newFromBalance = fromCrypto.balance - actualFromAmount;
      final newToBalance = toCrypto.balance + toAmount;

      // Update FROM crypto - menggunakan updatePortfolio() yang sudah ada
      await _walletService.updatePortfolio(
        fromCrypto.coinId!, // Gunakan coinId, bukan symbol
        newFromBalance,
        averagePrice: fromCrypto.priceUSD,
      );

      // Update TO crypto - menggunakan updatePortfolio() yang sudah ada
      await _walletService.updatePortfolio(
        toCrypto.coinId!, // Gunakan coinId, bukan symbol
        newToBalance,
        averagePrice: toCrypto.priceUSD,
      );

      print('✅ Exchange completed successfully');

    } catch (e) {
      print('❌ Error executing exchange: $e');
      rethrow;
    }
  }

  // Validate exchange
  bool validateExchange({
    required double fromAmount,
    required double balance,
    required double networkFee,
  }) {
    if (fromAmount <= 0) return false;
    if (fromAmount + networkFee > balance) return false;
    return true;
  }

  // Get minimum exchange amount (varies by crypto)
  double getMinimumExchangeAmount(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'BTC':
        return 0.0001;
      case 'ETH':
        return 0.001;
      case 'BNB':
        return 0.01;
      default:
        return 0.1;
    }
  }
}