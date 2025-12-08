import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/stock_asset.dart';

class StockServiceException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRateLimited;
  final bool isNetworkError;

  StockServiceException(
      this.message, {
        this.statusCode,
        this.isRateLimited = false,
        this.isNetworkError = false,
      });

  @override
  String toString() => message;
}

class StockService {
  static const String baseUrl = 'https://financialmodelingprep.com/api/v3';
  static const Duration timeout = Duration(seconds: 15);
  static const int maxRetries = 2;

  // Daftar saham populer untuk ditampilkan
  final List<String> popularStocks = [
    'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA',
    'META', 'NVDA', 'JPM', 'V', 'JNJ',
    'WMT', 'PG', 'MA', 'UNH', 'HD',
    'DIS', 'BAC', 'XOM', 'PFE', 'CSCO'
  ];

  // Helper method untuk HTTP request dengan retry dan timeout
  Future<http.Response> _makeRequest(
      Uri uri, {
        int retryCount = 0,
      }) async {
    try {
      final response = await http.get(uri).timeout(
        timeout,
        onTimeout: () {
          throw StockServiceException(
            'Request timeout. Please check your internet connection.',
            isNetworkError: true,
          );
        },
      );

      // Handle rate limiting
      if (response.statusCode == 429) {
        if (retryCount < maxRetries) {
          // Wait before retry (exponential backoff)
          await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
          return _makeRequest(uri, retryCount: retryCount + 1);
        }
        throw StockServiceException(
          'Too many requests. Please try again later.',
          statusCode: 429,
          isRateLimited: true,
        );
      }

      // Handle other HTTP errors
      if (response.statusCode != 200) {
        throw StockServiceException(
          'Failed to load stock data (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      return response;
    } on SocketException {
      throw StockServiceException(
        'No internet connection. Please check your network.',
        isNetworkError: true,
      );
    } on http.ClientException {
      throw StockServiceException(
        'Network error. Please try again.',
        isNetworkError: true,
      );
    } on StockServiceException {
      rethrow;
    } catch (e) {
      throw StockServiceException(
        'Unexpected error: ${e.toString()}',
      );
    }
  }

  // Fetch popular stocks
  Future<List<StockAsset>> fetchStockAssets({int limit = 20}) async {
    try {
      print('🔄 Fetching stock assets (limit: $limit)...');

      final symbols = popularStocks.take(limit).join(',');
      final uri = Uri.parse('$baseUrl/quote/$symbols');

      final response = await _makeRequest(uri);
      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        print('⚠️ No stock data from API, using fallback data');
        return _getDummyStocks(limit);
      }

      final stocks = data.map((json) => StockAsset.fromJson(json)).toList();
      print('✅ Successfully fetched ${stocks.length} stock assets');
      return stocks;
    } on StockServiceException catch (e) {
      print('⚠️ Stock Service Exception: ${e.message}');
      if (e.isRateLimited) {
        print('📊 API rate limit reached, using fallback data');
      } else if (e.isNetworkError) {
        print('🌐 Network error, using fallback data');
      }
      return _getDummyStocks(limit);
    } catch (e) {
      print('❌ Unexpected error fetching stocks: $e');
      print('📊 Using fallback stock data');
      return _getDummyStocks(limit);
    }
  }

  // Fetch single stock data
  Future<StockAsset> fetchSingleStock(String symbol) async {
    try {
      print('🔄 Fetching single stock: $symbol');

      final uri = Uri.parse('$baseUrl/quote/$symbol');
      final response = await _makeRequest(uri);
      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        throw StockServiceException('Stock "$symbol" not found');
      }

      print('✅ Successfully fetched stock: $symbol');
      return StockAsset.fromJson(data[0]);
    } on StockServiceException catch (e) {
      print('❌ Stock Service Exception for $symbol: ${e.message}');
      throw StockServiceException('Failed to load stock "$symbol": ${e.message}');
    } catch (e) {
      print('❌ Error fetching stock $symbol: $e');
      throw StockServiceException('Error fetching stock: ${e.toString()}');
    }
  }

  // Dummy data sebagai fallback
  List<StockAsset> _getDummyStocks(int limit) {
    print('📊 Loading ${limit} dummy stock assets');

    final dummyData = [
      {'symbol': 'AAPL', 'name': 'Apple Inc.', 'price': 178.25, 'changesPercentage': 2.15, 'change': 3.75, 'marketCap': 2800000000000, 'volume': 52000000},
      {'symbol': 'MSFT', 'name': 'Microsoft Corp.', 'price': 378.91, 'changesPercentage': 1.82, 'change': 6.75, 'marketCap': 2820000000000, 'volume': 24000000},
      {'symbol': 'GOOGL', 'name': 'Alphabet Inc.', 'price': 141.80, 'changesPercentage': -0.45, 'change': -0.64, 'marketCap': 1780000000000, 'volume': 28000000},
      {'symbol': 'AMZN', 'name': 'Amazon.com Inc.', 'price': 178.35, 'changesPercentage': 1.23, 'change': 2.17, 'marketCap': 1850000000000, 'volume': 45000000},
      {'symbol': 'TSLA', 'name': 'Tesla Inc.', 'price': 242.84, 'changesPercentage': -1.67, 'change': -4.12, 'marketCap': 771000000000, 'volume': 98000000},
      {'symbol': 'META', 'name': 'Meta Platforms Inc.', 'price': 494.53, 'changesPercentage': 2.89, 'change': 13.91, 'marketCap': 1260000000000, 'volume': 18000000},
      {'symbol': 'NVDA', 'name': 'NVIDIA Corp.', 'price': 875.28, 'changesPercentage': 3.45, 'change': 29.21, 'marketCap': 2160000000000, 'volume': 42000000},
      {'symbol': 'JPM', 'name': 'JPMorgan Chase', 'price': 198.52, 'changesPercentage': 0.87, 'change': 1.71, 'marketCap': 572000000000, 'volume': 12000000},
      {'symbol': 'V', 'name': 'Visa Inc.', 'price': 283.47, 'changesPercentage': 1.12, 'change': 3.14, 'marketCap': 583000000000, 'volume': 8000000},
      {'symbol': 'JNJ', 'name': 'Johnson & Johnson', 'price': 156.23, 'changesPercentage': -0.34, 'change': -0.53, 'marketCap': 381000000000, 'volume': 7000000},
      {'symbol': 'WMT', 'name': 'Walmart Inc.', 'price': 166.84, 'changesPercentage': 0.56, 'change': 0.93, 'marketCap': 442000000000, 'volume': 9000000},
      {'symbol': 'PG', 'name': 'Procter & Gamble', 'price': 167.92, 'changesPercentage': 0.23, 'change': 0.38, 'marketCap': 395000000000, 'volume': 6000000},
      {'symbol': 'MA', 'name': 'Mastercard Inc.', 'price': 461.28, 'changesPercentage': 1.45, 'change': 6.59, 'marketCap': 429000000000, 'volume': 3500000},
      {'symbol': 'UNH', 'name': 'UnitedHealth Group', 'price': 524.67, 'changesPercentage': -0.78, 'change': -4.12, 'marketCap': 488000000000, 'volume': 2800000},
      {'symbol': 'HD', 'name': 'Home Depot Inc.', 'price': 368.91, 'changesPercentage': 0.91, 'change': 3.32, 'marketCap': 367000000000, 'volume': 4200000},
      {'symbol': 'DIS', 'name': 'Walt Disney Co.', 'price': 113.82, 'changesPercentage': -1.23, 'change': -1.42, 'marketCap': 207000000000, 'volume': 11000000},
      {'symbol': 'BAC', 'name': 'Bank of America', 'price': 36.84, 'changesPercentage': 1.67, 'change': 0.61, 'marketCap': 286000000000, 'volume': 38000000},
      {'symbol': 'XOM', 'name': 'Exxon Mobil Corp.', 'price': 119.47, 'changesPercentage': 2.34, 'change': 2.73, 'marketCap': 478000000000, 'volume': 16000000},
      {'symbol': 'PFE', 'name': 'Pfizer Inc.', 'price': 28.93, 'changesPercentage': -0.89, 'change': -0.26, 'marketCap': 162000000000, 'volume': 31000000},
      {'symbol': 'CSCO', 'name': 'Cisco Systems', 'price': 56.78, 'changesPercentage': 0.67, 'change': 0.38, 'marketCap': 227000000000, 'volume': 19000000},
    ];

    return dummyData
        .take(limit)
        .map((json) => StockAsset.fromJson(json))
        .toList();
  }
}