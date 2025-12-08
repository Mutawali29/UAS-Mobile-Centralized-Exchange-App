import 'package:flutter/material.dart';
import 'dart:async';
import '../models/news_article.dart';
import '../widgets/news_card.dart';
import '../widgets/trending_crypto_card.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/app_colors.dart';
import '../services/crypto_service.dart';

import 'profile_screen.dart';
import 'activity_screen.dart';
import 'exchange_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 3;
  late TabController _tabController;
  bool _isLoading = true;
  bool _isTrendingLoading = true;

  // Service
  final CryptoService _cryptoService = CryptoService();

  // Trending cryptos dari API
  List<TrendingCrypto> _trendingCryptos = [];

  // State variables untuk error handling
  String? _trendingError;
  bool _hasNetworkError = false;
  bool _isRateLimited = false;

  // Search variables
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _debounce;

  // Sample news articles
  final List<NewsArticle> _allNews = [
    NewsArticle(
      id: '1',
      title: 'Bitcoin Surges Past \$80K as Institutional Adoption Grows',
      description:
      'Major financial institutions continue to add Bitcoin to their portfolios, driving prices to new highs.',
      imageUrl: 'https://picsum.photos/seed/crypto1/800/400',
      source: 'CryptoNews',
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      url: 'https://example.com/news1',
      category: 'Market',
    ),
    NewsArticle(
      id: '2',
      title: 'Ethereum 2.0 Update: What You Need to Know',
      description:
      'The latest developments in Ethereum\'s transition to proof-of-stake and its impact on the ecosystem.',
      imageUrl: 'https://picsum.photos/seed/crypto2/800/400',
      source: 'BlockchainToday',
      publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
      url: 'https://example.com/news2',
      category: 'Technology',
    ),
    NewsArticle(
      id: '3',
      title: 'New Regulations Coming for Cryptocurrency Exchanges',
      description:
      'Government agencies announce new framework for crypto trading platforms.',
      imageUrl: 'https://picsum.photos/seed/crypto3/800/400',
      source: 'FinanceDaily',
      publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
      url: 'https://example.com/news3',
      category: 'Regulation',
    ),
    NewsArticle(
      id: '4',
      title: 'DeFi Protocols See Record Trading Volume',
      description:
      'Decentralized finance platforms report unprecedented growth in user activity.',
      imageUrl: 'https://picsum.photos/seed/crypto4/800/400',
      source: 'DeFi Insider',
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      url: 'https://example.com/news4',
      category: 'DeFi',
    ),
    NewsArticle(
      id: '5',
      title: 'NFT Market Shows Signs of Recovery',
      description:
      'Trading volumes for non-fungible tokens increase as new projects launch.',
      imageUrl: 'https://picsum.photos/seed/crypto5/800/400',
      source: 'NFT Weekly',
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      url: 'https://example.com/news5',
      category: 'NFT',
    ),
    NewsArticle(
      id: '6',
      title: 'Top 5 Altcoins to Watch This Week',
      description:
      'Market analysts highlight promising cryptocurrencies with strong fundamentals.',
      imageUrl: 'https://picsum.photos/seed/crypto6/800/400',
      source: 'AltcoinBuzz',
      publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      url: 'https://example.com/news6',
      category: 'Analysis',
    ),
  ];

  final List<String> _categories = [
    'All',
    'Market',
    'Technology',
    'DeFi',
    'NFT',
    'Regulation'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      }
    });
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadTrendingCryptos(),
      _loadNews(),
    ]);
  }

  Future<void> _loadTrendingCryptos() async {
    if (!mounted) return;

    setState(() {
      _isTrendingLoading = true;
      _trendingError = null;
      _hasNetworkError = false;
      _isRateLimited = false;
    });

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('📱 [DiscoverScreen] Loading trending cryptocurrencies...');
    debugPrint('═══════════════════════════════════════════════════════');

    try {
      final trendingData = await _cryptoService.fetchTrendingCryptos(limit: 10);

      if (mounted) {
        setState(() {
          _trendingCryptos = trendingData;
          _isTrendingLoading = false;
          _trendingError = null;
        });

        debugPrint('');
        debugPrint('✅ [DiscoverScreen] Successfully loaded ${trendingData.length} trending cryptos');
        debugPrint('═══════════════════════════════════════════════════════');
      }
    } on CryptoServiceException catch (e) {
      debugPrint('');
      debugPrint('ℹ️ [DiscoverScreen] Unable to load trending cryptos');
      debugPrint('   Reason: ${e.message}');

      if (e.isNetworkError) {
        debugPrint('   Type: Network/Connection Issue');
        debugPrint('   Suggestion: Check internet connection or try again later');
      } else if (e.isRateLimited) {
        debugPrint('   Type: API Rate Limit');
        debugPrint('   Suggestion: Wait a few moments before retrying');
      } else if (e.statusCode != null) {
        debugPrint('   HTTP Status: ${e.statusCode}');
        debugPrint('   Suggestion: API may be temporarily unavailable');
      }
      debugPrint('═══════════════════════════════════════════════════════');

      if (mounted) {
        setState(() {
          _trendingCryptos = [];
          _isTrendingLoading = false;
          _trendingError = e.message;
          _hasNetworkError = e.isNetworkError;
          _isRateLimited = e.isRateLimited;
        });

        if (e.isNetworkError || e.isRateLimited) {
          _showErrorSnackbar(e.message, isWarning: e.isRateLimited);
        }
      }
    } catch (e) {
      debugPrint('');
      debugPrint('⚠️ [DiscoverScreen] Unexpected error occurred');
      debugPrint('   Details: $e');
      debugPrint('   Suggestion: This may be a bug, please report if it persists');
      debugPrint('═══════════════════════════════════════════════════════');

      if (mounted) {
        setState(() {
          _trendingCryptos = [];
          _isTrendingLoading = false;
          _trendingError = 'An unexpected error occurred';
          _hasNetworkError = false;
          _isRateLimited = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isWarning ? Icons.warning_amber_rounded : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isWarning ? Colors.orange : AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isWarning ? 4 : 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<NewsArticle> get _filteredNews {
    final selectedCategory = _categories[_tabController.index];
    List<NewsArticle> filtered = _allNews;

    // Filter by category
    if (selectedCategory != 'All') {
      filtered = filtered.where((news) => news.category == selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((news) {
        final titleLower = news.title.toLowerCase();
        final descriptionLower = news.description.toLowerCase();
        return titleLower.contains(_searchQuery) ||
            descriptionLower.contains(_searchQuery);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header dengan search bar
            _buildHeader(),

            const SizedBox(height: 16),

            // Search Bar
            _buildSearchBar(),

            const SizedBox(height: 16),

            // Trending Section - hide when searching
            if (!_isSearching) ...[
              _buildTrendingSection(),
              const SizedBox(height: 12),
            ],

            // Modern Category Tabs - hide when searching
            if (!_isSearching) _buildModernCategoryTabs(),

            const SizedBox(height: 8),

            // News List
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : _filteredNews.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.cardBackground,
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 20),
                  itemCount: _filteredNews.length,
                  itemBuilder: (context, index) {
                    return NewsCard(
                      article: _filteredNews[index],
                      onTap: () {
                        _showArticleDialog(_filteredNews[index]);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.pop(context);
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ActivityScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ExchangeScreen(),
              ),
            );
          } else if (index == 3) {
            // Already on Discover
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Discover',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: IconButton(
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.notifications_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () {
                // TODO: Open notifications
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isSearching
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.textSecondary.withOpacity(0.1),
            width: _isSearching ? 1.5 : 1,
          ),
          boxShadow: _isSearching
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Search news...',
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.6),
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: _isSearching
                  ? AppColors.primary
                  : AppColors.textSecondary.withOpacity(0.6),
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: Icon(
                Icons.clear,
                color: AppColors.textSecondary.withOpacity(0.6),
                size: 20,
              ),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _isSearching = false;
                });
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onTap: () {
            setState(() {
              _isSearching = true;
            });
          },
          onChanged: (value) {
            setState(() {
              _isSearching = value.isNotEmpty;
            });
          },
        ),
      ),
    );
  }

  Widget _buildModernCategoryTabs() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _tabController.index == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildCategoryChip(
              _categories[index],
              isSelected,
                  () {
                setState(() {
                  _tabController.animateTo(index);
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected ? null : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.textSecondary.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trending',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.2),
                      Colors.deepOrange.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isTrendingLoading ? 'Loading...' : 'Hot',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 165,
          child: _isTrendingLoading
              ? const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          )
              : _trendingCryptos.isEmpty
              ? _buildTrendingEmptyState()
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _trendingCryptos.length,
            itemBuilder: (context, index) {
              return TrendingCryptoCard(
                crypto: _trendingCryptos[index],
                onTap: () {
                  _showCryptoDetail(_trendingCryptos[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingEmptyState() {
    IconData icon;
    String title;
    String subtitle;
    Color iconColor;

    if (_hasNetworkError) {
      icon = Icons.wifi_off_rounded;
      title = 'No Internet Connection';
      subtitle = 'Please check your network and try again';
      iconColor = Colors.orange;
    } else if (_isRateLimited) {
      icon = Icons.hourglass_empty_rounded;
      title = 'Too Many Requests';
      subtitle = 'Please wait a moment before retrying';
      iconColor = Colors.amber;
    } else if (_trendingError != null) {
      icon = Icons.error_outline_rounded;
      title = 'Failed to Load';
      subtitle = _trendingError!;
      iconColor = AppColors.red;
    } else {
      icon = Icons.trending_up;
      title = 'No trending data';
      subtitle = 'Unable to fetch trending cryptocurrencies';
      iconColor = AppColors.textSecondary;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: iconColor.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 24,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _isRateLimited
                  ? null
                  : () {
                _loadTrendingCryptos();
              },
              style: TextButton.styleFrom(
                backgroundColor: _isRateLimited
                    ? AppColors.textSecondary.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                Icons.refresh,
                size: 16,
                color: _isRateLimited
                    ? AppColors.textSecondary.withOpacity(0.5)
                    : AppColors.primary,
              ),
              label: Text(
                _isRateLimited ? 'Please Wait' : 'Retry',
                style: TextStyle(
                  color: _isRateLimited
                      ? AppColors.textSecondary.withOpacity(0.5)
                      : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isSearching = _searchQuery.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.1),
                width: 2,
              ),
            ),
            child: Icon(
              isSearching ? Icons.search_off : Icons.article_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isSearching ? 'No results found' : 'No news available',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Try searching with different keywords'
                : 'Check back later for updates',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (isSearching) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _isSearching = false;
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.clear,
                size: 18,
                color: AppColors.primary,
              ),
              label: const Text(
                'Clear Search',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showArticleDialog(NewsArticle article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          article.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          article.description,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open URL in browser
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Read More',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showCryptoDetail(TrendingCrypto crypto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textSecondary.withOpacity(0.1),
                  width: 2,
                ),
              ),
              child: crypto.imageUrl != null
                  ? ClipOval(
                child: Image.network(
                  crypto.imageUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: Text(
                        crypto.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    );
                  },
                ),
              )
                  : Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: Text(
                  crypto.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crypto.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    crypto.symbol,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'Price',
              '\${crypto.priceUSD >= 1 ? crypto.priceUSD.toStringAsFixed(2) : crypto.priceUSD.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              '24h Change',
              '${crypto.isPositive ? '+' : ''}${crypto.changePercent.toStringAsFixed(2)}%',
              valueColor: crypto.isPositive ? AppColors.green : AppColors.red,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Market Cap',
              '\${_formatNumber(crypto.marketCap)}',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              '24h Volume',
              '\${_formatNumber(crypto.volume24h)}',
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Rank', '#${crypto.rank}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: AppColors.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatNumber(double number) {
    if (number >= 1e12) {
      return '${(number / 1e12).toStringAsFixed(2)}T';
    } else if (number >= 1e9) {
      return '${(number / 1e9).toStringAsFixed(2)}B';
    } else if (number >= 1e6) {
      return '${(number / 1e6).toStringAsFixed(2)}M';
    } else if (number >= 1e3) {
      return '${(number / 1e3).toStringAsFixed(2)}K';
    } else {
      return number.toStringAsFixed(2);
    }
  }
}