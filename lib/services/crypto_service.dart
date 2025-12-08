// services/crypto_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/crypto_asset.dart';
import '../models/news_article.dart';

class CryptoServiceException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRateLimited;
  final bool isNetworkError;
  final bool isCorsError;

  CryptoServiceException(
      this.message, {
        this.statusCode,
        this.isRateLimited = false,
        this.isNetworkError = false,
        this.isCorsError = false,
      });

  @override
  String toString() => 'CryptoServiceException: $message (statusCode: $statusCode, rateLimited: $isRateLimited, networkError: $isNetworkError, corsError: $isCorsError)';
}

class CryptoService {
  static const String baseUrl = 'https://api.coingecko.com/api/v3';
  static const Duration timeout = Duration(seconds: 15);
  static const int maxRetries = 3;
  static const int baseDelaySeconds = 2;

  // Rate limiting tracking
  DateTime? _lastRequestTime;
  static const Duration minRequestInterval = Duration(milliseconds: 1500);

  // Helper method untuk HTTP request dengan retry, timeout, dan rate limiting
  Future<http.Response> _makeRequest(
      Uri uri, {
        int retryCount = 0,
      }) async {
    // Rate limiting: tunggu jika request terlalu cepat
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < minRequestInterval) {
        final waitTime = minRequestInterval - timeSinceLastRequest;
        print('⏱️  Rate limiting: waiting ${waitTime.inMilliseconds}ms before request...');
        await Future.delayed(waitTime);
      }
    }

    try {
      print('🌐 Making HTTP request to: ${uri.toString()}');
      print('   Retry attempt: $retryCount/$maxRetries');

      _lastRequestTime = DateTime.now();

      final response = await http.get(uri).timeout(
        timeout,
        onTimeout: () {
          print('⏰ Request timeout after ${timeout.inSeconds} seconds');
          throw CryptoServiceException(
            'Request timeout. Please check your internet connection.',
            isNetworkError: true,
          );
        },
      );

      print('📥 Response received: Status ${response.statusCode}');

      // Handle rate limiting (429)
      if (response.statusCode == 429) {
        print('🚫 Rate limited (429) - Retry $retryCount/$maxRetries');

        if (retryCount < maxRetries) {
          // Exponential backoff: 2s, 4s, 8s
          final delaySeconds = baseDelaySeconds * (1 << retryCount);
          print('⏳ Waiting ${delaySeconds}s before retry...');
          await Future.delayed(Duration(seconds: delaySeconds));
          return _makeRequest(uri, retryCount: retryCount + 1);
        }

        print('❌ Max retries reached for rate limiting');
        throw CryptoServiceException(
          'Service is busy. Please try again in a few moments.',
          statusCode: 429,
          isRateLimited: true,
        );
      }

      // Handle other HTTP errors
      if (response.statusCode != 200) {
        print('❌ HTTP Error: ${response.statusCode}');
        print('   Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

        final errorMessage = _getErrorMessage(response.statusCode);
        throw CryptoServiceException(
          errorMessage,
          statusCode: response.statusCode,
        );
      }

      print('✅ Request successful');
      return response;

    } on SocketException catch (e) {
      print('🔌 SocketException: ${e.message}');
      print('   This usually means no internet connection');
      throw CryptoServiceException(
        'No internet connection. Please check your network.',
        isNetworkError: true,
      );
    } on http.ClientException catch (e) {
      print('🌐 ClientException: ${e.message}');

      // Detect CORS errors
      if (e.message.contains('XMLHttpRequest') ||
          e.message.contains('CORS') ||
          e.message.contains('Access-Control-Allow-Origin')) {
        print('🚫 CORS error detected');
        throw CryptoServiceException(
          'Network error. Please try again.',
          isNetworkError: true,
          isCorsError: true,
        );
      }

      throw CryptoServiceException(
        'Network error. Please try again.',
        isNetworkError: true,
      );
    } on CryptoServiceException {
      // Re-throw our custom exceptions
      rethrow;
    } catch (e) {
      print('❌ Unexpected error: ${e.toString()}');
      print('   Error type: ${e.runtimeType}');
      throw CryptoServiceException(
        'Unexpected error occurred. Please try again.',
      );
    }
  }

  String _getErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please try again.';
      case 401:
        return 'Authentication failed.';
      case 403:
        return 'Access forbidden.';
      case 404:
        return 'Data not found.';
      case 429:
        return 'Too many requests. Please wait a moment.';
      case 500:
      case 502:
      case 503:
        return 'Service temporarily unavailable.';
      case 504:
        return 'Service timeout. Please try again.';
      default:
        return 'Failed to load data (Error $statusCode)';
    }
  }

  // Fetch list of cryptocurrencies with market data
  Future<List<CryptoAsset>> fetchCryptoAssets({int limit = 20}) async {
    try {
      print('\n📊 Fetching crypto assets (limit: $limit)...');

      final uri = Uri.parse(
        '$baseUrl/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=$limit&page=1&sparkline=false&price_change_percentage=24h',
      );

      final response = await _makeRequest(uri);
      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        print('⚠️  No crypto data available');
        throw CryptoServiceException('No crypto data available');
      }

      print('✅ Successfully fetched ${data.length} crypto assets');
      return data.map((json) => CryptoAsset.fromJson(json)).toList();

    } on CryptoServiceException catch (e) {
      print('⚠️  CryptoServiceException in fetchCryptoAssets: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Error parsing crypto data: ${e.toString()}');
      throw CryptoServiceException('Error parsing crypto data: ${e.toString()}');
    }
  }

  // Fetch specific crypto data
  Future<CryptoAsset> fetchSingleCrypto(String coinId) async {
    try {
      print('\n🔍 Fetching single crypto: $coinId');

      final uri = Uri.parse(
        '$baseUrl/coins/markets?vs_currency=usd&ids=$coinId&price_change_percentage=24h',
      );

      final response = await _makeRequest(uri);
      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        print('⚠️  Crypto "$coinId" not found');
        throw CryptoServiceException('Crypto "$coinId" not found');
      }

      print('✅ Successfully fetched $coinId');
      return CryptoAsset.fromJson(data[0]);

    } on CryptoServiceException catch (e) {
      print('⚠️  CryptoServiceException in fetchSingleCrypto: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Error fetching crypto: ${e.toString()}');
      throw CryptoServiceException('Error fetching crypto: ${e.toString()}');
    }
  }

  // Get trending cryptocurrencies
  Future<List<String>> fetchTrendingCoins() async {
    try {
      print('\n🔥 Fetching trending coins...');

      final uri = Uri.parse('$baseUrl/search/trending');
      final response = await _makeRequest(uri);
      final data = json.decode(response.body);
      final List<dynamic> coins = data['coins'];

      if (coins.isEmpty) {
        print('⚠️  No trending coins available');
        throw CryptoServiceException('No trending coins available');
      }

      final trendingIds = coins.map((coin) => coin['item']['id'] as String).toList();
      print('✅ Successfully fetched ${trendingIds.length} trending coins');
      return trendingIds;

    } on CryptoServiceException catch (e) {
      print('⚠️  CryptoServiceException in fetchTrendingCoins: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Error fetching trending: ${e.toString()}');
      throw CryptoServiceException('Error fetching trending: ${e.toString()}');
    }
  }

  // Fetch trending cryptocurrencies dengan detail lengkap
  Future<List<TrendingCrypto>> fetchTrendingCryptos({int limit = 10}) async {
    try {
      print('\n📈 Fetching trending cryptos with details (limit: $limit)...');

      final uri = Uri.parse(
        '$baseUrl/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=$limit&page=1&sparkline=false&price_change_percentage=24h',
      );

      final response = await _makeRequest(uri);
      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        print('⚠️  No trending data available');
        throw CryptoServiceException('No trending data available');
      }

      print('✅ Successfully fetched ${data.length} trending cryptos');
      return data.map((json) => TrendingCrypto.fromJson(json)).toList();

    } on CryptoServiceException catch (e) {
      print('⚠️  CryptoServiceException in fetchTrendingCryptos: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Error fetching trending cryptos: ${e.toString()}');
      throw CryptoServiceException('Error fetching trending cryptos: ${e.toString()}');
    }
  }

  // Fetch trending berdasarkan volume tertinggi
  Future<List<TrendingCrypto>> fetchTrendingByVolume({int limit = 10}) async {
    try {
      print('\n📊 Fetching trending by volume (limit: $limit)...');

      final uri = Uri.parse(
        '$baseUrl/coins/markets?vs_currency=usd&order=volume_desc&per_page=$limit&page=1&sparkline=false&price_change_percentage=24h',
      );

      final response = await _makeRequest(uri);
      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        print('⚠️  No volume data available');
        throw CryptoServiceException('No volume data available');
      }

      print('✅ Successfully fetched ${data.length} cryptos by volume');
      return data.map((json) => TrendingCrypto.fromJson(json)).toList();

    } on CryptoServiceException catch (e) {
      print('⚠️  CryptoServiceException in fetchTrendingByVolume: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Error fetching trending by volume: ${e.toString()}');
      throw CryptoServiceException('Error fetching trending by volume: ${e.toString()}');
    }
  }

  // Fetch top gainers (crypto dengan perubahan harga tertinggi)
  Future<List<TrendingCrypto>> fetchTopGainers({int limit = 10}) async {
    try {
      print('\n📈 Fetching top gainers (limit: $limit)...');

      final uri = Uri.parse(
        '$baseUrl/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false&price_change_percentage=24h',
      );

      final response = await _makeRequest(uri);
      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        print('⚠️  No market data available');
        throw CryptoServiceException('No market data available');
      }

      // Filter yang positif dan urutkan berdasarkan perubahan persen tertinggi
      final gainers = data
          .where((item) =>
      (item['price_change_percentage_24h'] as num?) != null &&
          (item['price_change_percentage_24h'] as num) > 0)
          .toList();

      if (gainers.isEmpty) {
        print('⚠️  No gainers found at this time');
        throw CryptoServiceException('No gainers found at this time');
      }

      gainers.sort((a, b) => (b['price_change_percentage_24h'] as num)
          .compareTo(a['price_change_percentage_24h'] as num));

      final topGainers = gainers
          .take(limit)
          .map((json) => TrendingCrypto.fromJson(json))
          .toList();

      print('✅ Successfully fetched ${topGainers.length} top gainers');
      return topGainers;

    } on CryptoServiceException catch (e) {
      print('⚠️  CryptoServiceException in fetchTopGainers: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Error fetching top gainers: ${e.toString()}');
      throw CryptoServiceException('Error fetching top gainers: ${e.toString()}');
    }
  }

  // Fetch trending dari API trending CoinGecko
  Future<List<TrendingCrypto>> fetchTrendingFromAPI({int limit = 7}) async {
    try {
      print('\n🔥 Fetching trending from API (limit: $limit)...');

      // Step 1: Get trending coin IDs
      print('   Step 1: Getting trending coin IDs...');
      final trendingUri = Uri.parse('$baseUrl/search/trending');
      final trendingResponse = await _makeRequest(trendingUri);
      final trendingData = json.decode(trendingResponse.body);
      final List<dynamic> coins = trendingData['coins'];

      if (coins.isEmpty) {
        print('⚠️  No trending coins available');
        throw CryptoServiceException('No trending coins available');
      }

      // Ambil ID coins
      final coinIds =
      coins.take(limit).map((coin) => coin['item']['id'] as String).join(',');
      print('   Found trending coins: $coinIds');

      // Step 2: Get detail dari coins tersebut
      print('   Step 2: Getting details for trending coins...');
      final detailUri = Uri.parse(
        '$baseUrl/coins/markets?vs_currency=usd&ids=$coinIds&price_change_percentage=24h',
      );

      final detailResponse = await _makeRequest(detailUri);
      final List<dynamic> data = json.decode(detailResponse.body);

      if (data.isEmpty) {
        print('⚠️  No trending details available');
        throw CryptoServiceException('No trending details available');
      }

      print('✅ Successfully fetched ${data.length} trending cryptos from API');
      return data.map((json) => TrendingCrypto.fromJson(json)).toList();

    } on CryptoServiceException catch (e) {
      print('⚠️  CryptoServiceException in fetchTrendingFromAPI: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Error fetching trending from API: ${e.toString()}');
      throw CryptoServiceException('Error fetching trending from API: ${e.toString()}');
    }
  }
}