import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/nft_asset.dart';

class NFTServiceException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRateLimited;
  final bool isNetworkError;

  NFTServiceException(
      this.message, {
        this.statusCode,
        this.isRateLimited = false,
        this.isNetworkError = false,
      });

  @override
  String toString() => message;
}

class NFTService {
  static const String baseUrl = 'https://api.coingecko.com/api/v3';
  static const Duration timeout = Duration(seconds: 15);
  static const int maxRetries = 2;

  // Helper method untuk HTTP request dengan retry dan timeout
  Future<http.Response> _makeRequest(
      Uri uri, {
        int retryCount = 0,
      }) async {
    try {
      final response = await http.get(uri).timeout(
        timeout,
        onTimeout: () {
          throw NFTServiceException(
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
        throw NFTServiceException(
          'Too many requests. Please try again later.',
          statusCode: 429,
          isRateLimited: true,
        );
      }

      // Handle other HTTP errors
      if (response.statusCode != 200) {
        throw NFTServiceException(
          'Failed to load NFT data (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      return response;
    } on SocketException {
      throw NFTServiceException(
        'No internet connection. Please check your network.',
        isNetworkError: true,
      );
    } on http.ClientException {
      throw NFTServiceException(
        'Network error. Please try again.',
        isNetworkError: true,
      );
    } on NFTServiceException {
      rethrow;
    } catch (e) {
      throw NFTServiceException(
        'Unexpected error: ${e.toString()}',
      );
    }
  }

  // Fetch NFT collections
  Future<List<NFTAsset>> fetchNFTAssets({int limit = 20}) async {
    try {
      print('🔄 Fetching NFT assets (limit: $limit)...');

      final uri = Uri.parse('$baseUrl/nfts/list?per_page=$limit');
      final response = await _makeRequest(uri);
      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        print('⚠️ No NFT data from API, using fallback data');
        return _getDummyNFTs(limit);
      }

      // Get detailed info for each NFT
      print('✅ NFT list fetched, getting detailed info...');
      final detailedNFTs = await _fetchDetailedNFTs(data.take(limit).toList());

      print('✅ Successfully fetched ${detailedNFTs.length} NFT assets');
      return detailedNFTs;
    } on NFTServiceException catch (e) {
      print('⚠️ NFT Service Exception: ${e.message}');
      print('📦 Using fallback NFT data');
      return _getDummyNFTs(limit);
    } catch (e) {
      print('❌ Unexpected error fetching NFTs: $e');
      print('📦 Using fallback NFT data');
      return _getDummyNFTs(limit);
    }
  }

  // Fetch detailed NFT data
  Future<List<NFTAsset>> _fetchDetailedNFTs(List<dynamic> nftList) async {
    List<NFTAsset> detailedNFTs = [];

    for (var nft in nftList) {
      try {
        final id = nft['id'];
        final uri = Uri.parse('$baseUrl/nfts/$id');
        final response = await _makeRequest(uri);
        final data = json.decode(response.body);
        detailedNFTs.add(NFTAsset.fromJson(data));

        print('  ✓ Fetched details for: $id');
      } on NFTServiceException catch (e) {
        print('  ⚠️ Failed to fetch NFT detail: ${e.message}');
        continue;
      } catch (e) {
        print('  ⚠️ Error fetching NFT detail: $e');
        continue;
      }

      // Batasi request untuk menghindari rate limit
      if (detailedNFTs.length >= 10) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (detailedNFTs.isEmpty) {
      print('⚠️ No detailed NFT data available, using fallback');
      return _getDummyNFTs(10);
    }

    return detailedNFTs;
  }

  // Fetch single NFT
  Future<NFTAsset> fetchSingleNFT(String nftId) async {
    try {
      print('🔄 Fetching single NFT: $nftId');

      final uri = Uri.parse('$baseUrl/nfts/$nftId');
      final response = await _makeRequest(uri);
      final data = json.decode(response.body);

      print('✅ Successfully fetched NFT: $nftId');
      return NFTAsset.fromJson(data);
    } on NFTServiceException catch (e) {
      print('❌ NFT Service Exception for $nftId: ${e.message}');
      throw NFTServiceException('Failed to load NFT "$nftId": ${e.message}');
    } catch (e) {
      print('❌ Error fetching NFT $nftId: $e');
      throw NFTServiceException('Error fetching NFT: ${e.toString()}');
    }
  }

  // Dummy NFT data sebagai fallback
  List<NFTAsset> _getDummyNFTs(int limit) {
    print('📦 Loading ${limit} dummy NFT assets');

    final dummyData = [
      {
        'id': 'bored-ape-yacht-club',
        'name': 'Bored Ape #1234',
        'collection': 'Bored Ape Yacht Club',
        'floor_price_in_usd': 45280.50,
        'floor_price_24h_percentage_change': 5.23,
        'volume_24h': 1250000,
        'image': {'small': 'https://via.placeholder.com/150/FF6B6B/FFFFFF?text=BAYC'},
      },
      {
        'id': 'cryptopunks',
        'name': 'CryptoPunk #5678',
        'collection': 'CryptoPunks',
        'floor_price_in_usd': 98750.00,
        'floor_price_24h_percentage_change': -2.15,
        'volume_24h': 3400000,
        'image': {'small': 'https://via.placeholder.com/150/4ECDC4/FFFFFF?text=PUNK'},
      },
      {
        'id': 'mutant-ape-yacht-club',
        'name': 'Mutant Ape #9012',
        'collection': 'Mutant Ape Yacht Club',
        'floor_price_in_usd': 12450.75,
        'floor_price_24h_percentage_change': 3.87,
        'volume_24h': 680000,
        'image': {'small': 'https://via.placeholder.com/150/95E1D3/FFFFFF?text=MAYC'},
      },
      {
        'id': 'azuki',
        'name': 'Azuki #3456',
        'collection': 'Azuki',
        'floor_price_in_usd': 18920.30,
        'floor_price_24h_percentage_change': 7.12,
        'volume_24h': 920000,
        'image': {'small': 'https://via.placeholder.com/150/F38181/FFFFFF?text=AZUKI'},
      },
      {
        'id': 'doodles-official',
        'name': 'Doodle #7890',
        'collection': 'Doodles',
        'floor_price_in_usd': 8340.20,
        'floor_price_24h_percentage_change': -1.45,
        'volume_24h': 430000,
        'image': {'small': 'https://via.placeholder.com/150/AA96DA/FFFFFF?text=DOODLE'},
      },
      {
        'id': 'clone-x',
        'name': 'CloneX #2345',
        'collection': 'CloneX',
        'floor_price_in_usd': 6780.90,
        'floor_price_24h_percentage_change': 4.56,
        'volume_24h': 540000,
        'image': {'small': 'https://via.placeholder.com/150/FCBAD3/FFFFFF?text=CLONEX'},
      },
      {
        'id': 'meebits',
        'name': 'Meebit #6789',
        'collection': 'Meebits',
        'floor_price_in_usd': 3420.50,
        'floor_price_24h_percentage_change': -3.21,
        'volume_24h': 280000,
        'image': {'small': 'https://via.placeholder.com/150/FFD93D/FFFFFF?text=MEEBIT'},
      },
      {
        'id': 'pudgy-penguins',
        'name': 'Pudgy Penguin #4567',
        'collection': 'Pudgy Penguins',
        'floor_price_in_usd': 7890.40,
        'floor_price_24h_percentage_change': 2.89,
        'volume_24h': 390000,
        'image': {'small': 'https://via.placeholder.com/150/6BCB77/FFFFFF?text=PUDGY'},
      },
      {
        'id': 'moonbirds',
        'name': 'Moonbird #8901',
        'collection': 'Moonbirds',
        'floor_price_in_usd': 5670.80,
        'floor_price_24h_percentage_change': 1.23,
        'volume_24h': 320000,
        'image': {'small': 'https://via.placeholder.com/150/4D96FF/FFFFFF?text=MOONBIRD'},
      },
      {
        'id': 'otherdeed',
        'name': 'Otherdeed #1111',
        'collection': 'Otherdeed for Otherside',
        'floor_price_in_usd': 1250.30,
        'floor_price_24h_percentage_change': -0.87,
        'volume_24h': 180000,
        'image': {'small': 'https://via.placeholder.com/150/C780FA/FFFFFF?text=OTHERDEED'},
      },
      {
        'id': 'cool-cats',
        'name': 'Cool Cat #2222',
        'collection': 'Cool Cats',
        'floor_price_in_usd': 4320.60,
        'floor_price_24h_percentage_change': 3.45,
        'volume_24h': 210000,
        'image': {'small': 'https://via.placeholder.com/150/FF6B9D/FFFFFF?text=COOLCAT'},
      },
      {
        'id': 'world-of-women',
        'name': 'WoW #3333',
        'collection': 'World of Women',
        'floor_price_in_usd': 2890.20,
        'floor_price_24h_percentage_change': -2.34,
        'volume_24h': 150000,
        'image': {'small': 'https://via.placeholder.com/150/FFB6C1/FFFFFF?text=WOW'},
      },
      {
        'id': 'vee-friends',
        'name': 'VeeFriend #4444',
        'collection': 'VeeFriends',
        'floor_price_in_usd': 3210.50,
        'floor_price_24h_percentage_change': 1.78,
        'volume_24h': 190000,
        'image': {'small': 'https://via.placeholder.com/150/98D8C8/FFFFFF?text=VEEFRIEND'},
      },
      {
        'id': 'the-sandbox',
        'name': 'Sandbox Land #5555',
        'collection': 'The Sandbox',
        'floor_price_in_usd': 980.90,
        'floor_price_24h_percentage_change': 0.56,
        'volume_24h': 120000,
        'image': {'small': 'https://via.placeholder.com/150/FFE66D/FFFFFF?text=SANDBOX'},
      },
      {
        'id': 'decentraland',
        'name': 'Decentraland LAND #6666',
        'collection': 'Decentraland',
        'floor_price_in_usd': 1450.30,
        'floor_price_24h_percentage_change': -1.23,
        'volume_24h': 160000,
        'image': {'small': 'https://via.placeholder.com/150/A8E6CF/FFFFFF?text=MANA'},
      },
    ];

    return dummyData
        .take(limit)
        .map((json) => NFTAsset.fromJson(json))
        .toList();
  }
}