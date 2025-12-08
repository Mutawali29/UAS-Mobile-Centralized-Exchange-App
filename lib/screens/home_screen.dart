import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../models/crypto_asset.dart';
import '../models/stock_asset.dart';
import '../models/nft_asset.dart';
import '../services/crypto_service.dart';
import '../services/stock_service.dart';
import '../services/nft_service.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../widgets/wallet_card.dart';
import '../widgets/crypto_list_item.dart';
import '../widgets/stock_list_item.dart';
import '../widgets/nft_list_item.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/app_colors.dart';
import 'activity_screen.dart';
import 'exchange_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import '../utils/database_initializer.dart';

// ==================== Enhanced Error Types ====================
enum ErrorType {
  network,
  timeout,
  rateLimit,
  server,
  unauthorized,
  notFound,
  unknown
}

class AppError {
  final ErrorType type;
  final String message;
  final String? technicalDetails;
  final bool isFatal;

  AppError({
    required this.type,
    required this.message,
    this.technicalDetails,
    this.isFatal = false,
  });

  factory AppError.fromException(dynamic error) {
    if (error is SocketException) {
      return AppError(
        type: ErrorType.network,
        message: 'No internet connection. Please check your network.',
        technicalDetails: error.toString(),
      );
    } else if (error is TimeoutException) {
      return AppError(
        type: ErrorType.timeout,
        message: 'Connection timeout. Please try again.',
        technicalDetails: error.toString(),
      );
    } else if (error is CryptoServiceException) {
      return _parseServiceException(error.message, error.toString());
    } else if (error is StockServiceException) {
      return _parseServiceException(error.message, error.toString());
    } else if (error is NFTServiceException) {
      return _parseServiceException(error.message, error.toString());
    } else {
      return AppError(
        type: ErrorType.unknown,
        message: 'Something went wrong. Please try again.',
        technicalDetails: error.toString(),
      );
    }
  }

  static AppError _parseServiceException(String message, String details) {
    if (message.contains('429') || message.toLowerCase().contains('rate limit')) {
      return AppError(
        type: ErrorType.rateLimit,
        message: 'Too many requests. Please wait a moment and try again.',
        technicalDetails: details,
      );
    } else if (message.contains('401') || message.toLowerCase().contains('unauthorized')) {
      return AppError(
        type: ErrorType.unauthorized,
        message: 'Authentication failed. Please login again.',
        technicalDetails: details,
        isFatal: true,
      );
    } else if (message.contains('404') || message.toLowerCase().contains('not found')) {
      return AppError(
        type: ErrorType.notFound,
        message: 'Resource not found. Service may be unavailable.',
        technicalDetails: details,
      );
    } else if (message.contains('5') && message.length >= 3) {
      return AppError(
        type: ErrorType.server,
        message: 'Server error. Please try again later.',
        technicalDetails: details,
      );
    } else if (message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('connection')) {
      return AppError(
        type: ErrorType.network,
        message: 'Network error. Please check your connection.',
        technicalDetails: details,
      );
    } else {
      return AppError(
        type: ErrorType.unknown,
        message: message,
        technicalDetails: details,
      );
    }
  }

  IconData get icon {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.timeout:
        return Icons.access_time;
      case ErrorType.rateLimit:
        return Icons.speed;
      case ErrorType.server:
        return Icons.cloud_off;
      case ErrorType.unauthorized:
        return Icons.lock_outline;
      case ErrorType.notFound:
        return Icons.search_off;
      default:
        return Icons.error_outline;
    }
  }

  Color get color {
    switch (type) {
      case ErrorType.network:
      case ErrorType.timeout:
        return AppColors.orange;
      case ErrorType.rateLimit:
        return AppColors.yellow;
      case ErrorType.server:
      case ErrorType.unauthorized:
        return AppColors.red;
      default:
        return AppColors.red.withOpacity(0.8);
    }
  }
}

// ==================== Home Screen State Provider ====================
class HomeScreenProvider extends ChangeNotifier {
  // Services
  final CryptoService _cryptoService;
  final StockService _stockService;
  final NFTService _nftService;
  final AuthService _authService;
  final WalletService _walletService;

  // Assets
  List<CryptoAsset> _cryptoAssets = [];
  List<StockAsset> _stockAssets = [];
  List<NFTAsset> _nftAssets = [];

  // UI State
  bool _isLoading = true;
  AppError? _currentError;
  bool _isUsingFallbackData = false;
  String? _walletAddress;
  Map<String, double> _portfolio = {};
  int _selectedTab = 1;

  // Error Tracking
  int _consecutiveErrors = 0;
  DateTime? _lastErrorTime;
  DateTime? _lastSuccessTime;
  DateTime? _rateLimitUntil;

  // Constants
  static const int _maxConsecutiveErrors = 3;
  static const Duration _errorResetDuration = Duration(minutes: 5);
  static const Duration _rateLimitCooldown = Duration(seconds: 60);

  // Stream Subscription
  StreamSubscription<Map<String, double>>? _portfolioSubscription;
  Timer? _refreshTimer;

  // Getters
  List<CryptoAsset> get cryptoAssets => _cryptoAssets;
  List<StockAsset> get stockAssets => _stockAssets;
  List<NFTAsset> get nftAssets => _nftAssets;
  bool get isLoading => _isLoading;
  AppError? get currentError => _currentError;
  bool get isUsingFallbackData => _isUsingFallbackData;
  String? get walletAddress => _walletAddress;
  Map<String, double> get portfolio => _portfolio;
  int get selectedTab => _selectedTab;
  int get consecutiveErrors => _consecutiveErrors;
  DateTime? get rateLimitUntil => _rateLimitUntil;
  DateTime? get lastSuccessTime => _lastSuccessTime;

  HomeScreenProvider({
    required CryptoService cryptoService,
    required StockService stockService,
    required NFTService nftService,
    required AuthService authService,
    required WalletService walletService,
  })  : _cryptoService = cryptoService,
        _stockService = stockService,
        _nftService = nftService,
        _authService = authService,
        _walletService = walletService;

  // ==================== Initialization ====================
  Future<void> initialize() async {
    _logInfo('Starting data initialization...');
    try {
      await _loadWalletAddress();
      _subscribeToPortfolio();
      await _loadCurrentTabData();
      _logSuccess('Initialization completed successfully');
    } catch (e) {
      final appError = AppError.fromException(e);
      _logError('Failed to initialize data', e);
      _trackError(appError);
    }
  }

  void startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_canAutoRefresh()) {
        _logInfo('Auto-refresh triggered');
        _loadCurrentTabData(showLoading: false, isAutoRefresh: true);
      } else {
        _logInfo('Auto-refresh skipped (rate limited or too many errors)');
      }
    });
  }

  void dispose() {
    _logInfo('Provider disposing...');
    _refreshTimer?.cancel();
    _portfolioSubscription?.cancel();
    _logInfo('Provider disposed successfully');
    super.dispose();
  }

  // ==================== Wallet & Portfolio ====================
  Future<void> _loadWalletAddress() async {
    _logInfo('Loading wallet address...');
    try {
      final address = await _walletService.getWalletAddress();
      _walletAddress = address;
      if (address != null) {
        _logSuccess(
          'Wallet address loaded: ${address.substring(0, 10)}...${address.substring(address.length - 8)}',
        );
      }
      notifyListeners();
    } catch (e) {
      _logError('Failed to load wallet address', e);
      _walletAddress = null;
      notifyListeners();
    }
  }

  void _subscribeToPortfolio() {
    _logInfo('Setting up portfolio stream subscription...');
    _portfolioSubscription?.cancel();
    _portfolioSubscription = _walletService.portfolioStream().listen(
          (portfolio) {
        _logSuccess('Portfolio updated: ${portfolio.length} assets');
        _portfolio = portfolio;
        _loadCurrentTabData(showLoading: false, isAutoRefresh: true);
      },
      onError: (error) {
        final appError = AppError.fromException(error);
        _logError('Portfolio stream error', error);
        _trackError(appError);
      },
      onDone: () {
        _logWarning('Portfolio stream closed');
      },
    );
    _logSuccess('Portfolio stream subscription active');
  }

  // ==================== Data Loading ====================
  Future<void> _loadCurrentTabData({
    bool showLoading = true,
    bool isAutoRefresh = false,
  }) async {
    if (_rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!)) {
      final remaining = _rateLimitUntil!.difference(DateTime.now()).inSeconds;
      _logWarning('Rate limited. ${remaining}s remaining');
      if (!isAutoRefresh) {
        _showInfoSnackBar('Please wait ${remaining}s before refreshing');
      }
      return;
    }

    final tabNames = ['Cash', 'Crypto', 'Stocks', 'NFT'];
    _logInfo(
      'Loading ${tabNames[_selectedTab]} data (showLoading: $showLoading, auto: $isAutoRefresh)',
    );

    try {
      switch (_selectedTab) {
        case 0:
          _logInfo('Cash tab - Not yet implemented');
          break;
        case 1:
          await _loadCryptoData(showLoading: showLoading, isAutoRefresh: isAutoRefresh);
          break;
        case 2:
          await _loadStockData(showLoading: showLoading, isAutoRefresh: isAutoRefresh);
          break;
        case 3:
          await _loadNFTData(showLoading: showLoading, isAutoRefresh: isAutoRefresh);
          break;
      }
    } catch (e) {
      final appError = AppError.fromException(e);
      _logError('Unexpected error in _loadCurrentTabData', e);
      _trackError(appError);
    }
  }

  Future<void> _loadCryptoData({
    bool showLoading = true,
    bool isAutoRefresh = false,
  }) async {
    _logInfo('[Crypto] Starting data fetch...');
    if (showLoading && !isAutoRefresh) {
      _setLoading(true);
    }

    try {
      final startTime = DateTime.now();
      final assets = await _cryptoService.fetchCryptoAssets(limit: 50);
      final duration = DateTime.now().difference(startTime);
      _logInfo('[Crypto] Fetched ${assets.length} assets in ${duration.inMilliseconds}ms');

      final updatedAssets = assets.map((asset) {
        if (_portfolio.containsKey(asset.id)) {
          final amount = _portfolio[asset.id]!;
          return asset.copyWithAmount(amount);
        }
        return asset;
      }).toList();

      final portfolioAssets = updatedAssets.where((a) => a.amount > 0).length;
      final totalValue = updatedAssets
          .where((a) => a.amount > 0)
          .fold(0.0, (sum, a) => sum + a.valueUSD);

      _cryptoAssets = updatedAssets;
      _isLoading = false;
      _currentError = null;
      _isUsingFallbackData = false;

      _resetErrorTracking();
      _logSuccess(
        '[Crypto] Loaded successfully - $portfolioAssets owned, Total: \$${totalValue.toStringAsFixed(2)}',
      );

      if (!isAutoRefresh && showLoading) {
        _showSuccessSnackBar('Crypto data updated');
      }

      notifyListeners();
    } catch (e) {
      final appError = AppError.fromException(e);
      _logError('[Crypto] ${appError.type.name}: ${appError.message}', e);
      _trackError(appError);

      _isLoading = false;
      _currentError = appError;
      _isUsingFallbackData = false;

      if (showLoading && !isAutoRefresh) {
        _showErrorSnackBar(appError);
      }

      notifyListeners();
    }
  }

  Future<void> _loadStockData({
    bool showLoading = true,
    bool isAutoRefresh = false,
  }) async {
    _logInfo('[Stocks] Starting data fetch...');
    if (showLoading && !isAutoRefresh) {
      _setLoading(true);
    }

    try {
      final startTime = DateTime.now();
      final assets = await _stockService.fetchStockAssets(limit: 20);
      final duration = DateTime.now().difference(startTime);
      _logInfo('[Stocks] Fetched ${assets.length} assets in ${duration.inMilliseconds}ms');

      final updatedAssets = assets.map((asset) {
        final key = asset.symbol.toLowerCase();
        if (_portfolio.containsKey(key)) {
          final amount = _portfolio[key]!;
          return asset.copyWithAmount(amount);
        }
        return asset;
      }).toList();

      final portfolioAssets = updatedAssets.where((a) => a.amount > 0).length;
      final totalValue = updatedAssets
          .where((a) => a.amount > 0)
          .fold(0.0, (sum, a) => sum + a.valueUSD);

      bool isFallback = false;
      if (assets.isNotEmpty) {
        try {
          isFallback = (assets.first.valueUSD == 0);
        } catch (e) {
          _logWarning('[Stocks] Could not determine fallback status: $e');
          isFallback = false;
        }
      }

      _stockAssets = updatedAssets;
      _isLoading = false;
      _currentError = null;
      _isUsingFallbackData = isFallback;

      _resetErrorTracking();

      if (isFallback) {
        _logWarning('[Stocks] Using demo data');
        if (showLoading && !isAutoRefresh) _showInfoSnackBar('Using demo stock data');
      } else {
        _logSuccess(
          '[Stocks] Loaded successfully - $portfolioAssets owned, Total: \$${totalValue.toStringAsFixed(2)}',
        );
        if (!isAutoRefresh && showLoading) {
          _showSuccessSnackBar('Stock data updated');
        }
      }

      notifyListeners();
    } catch (e) {
      final appError = AppError.fromException(e);
      _logError('[Stocks] ${appError.type.name}: ${appError.message}', e);
      _trackError(appError);

      _isLoading = false;
      _currentError = appError;
      _isUsingFallbackData = _stockAssets.isNotEmpty;

      if (showLoading && !isAutoRefresh && _stockAssets.isEmpty) {
        _showErrorSnackBar(appError);
      }

      notifyListeners();
    }
  }

  Future<void> _loadNFTData({
    bool showLoading = true,
    bool isAutoRefresh = false,
  }) async {
    _logInfo('[NFT] Starting data fetch...');
    if (showLoading && !isAutoRefresh) {
      _setLoading(true);
    }

    try {
      final startTime = DateTime.now();
      final assets = await _nftService.fetchNFTAssets(limit: 15);
      final duration = DateTime.now().difference(startTime);
      _logInfo('[NFT] Fetched ${assets.length} assets in ${duration.inMilliseconds}ms');

      final updatedAssets = assets.map((asset) {
        if (_portfolio.containsKey(asset.id)) {
          final amount = _portfolio[asset.id]!;
          return asset.copyWithAmount(amount);
        }
        return asset;
      }).toList();

      final portfolioAssets = updatedAssets.where((a) => a.amount > 0).length;
      final totalValue = updatedAssets
          .where((a) => a.amount > 0)
          .fold(0.0, (sum, a) => sum + a.valueUSD);
      final isFallback = assets.isNotEmpty;

      _nftAssets = updatedAssets;
      _isLoading = false;
      _currentError = null;
      _isUsingFallbackData = isFallback;

      _resetErrorTracking();

      if (isFallback) {
        _logWarning('[NFT] Using demo data');
        if (showLoading && !isAutoRefresh) _showInfoSnackBar('Using demo NFT data');
      } else {
        _logSuccess(
          '[NFT] Loaded successfully - $portfolioAssets owned, Total: \$${totalValue.toStringAsFixed(2)}',
        );
        if (!isAutoRefresh && showLoading) {
          _showSuccessSnackBar('NFT data updated');
        }
      }

      notifyListeners();
    } catch (e) {
      final appError = AppError.fromException(e);
      _logError('[NFT] ${appError.type.name}: ${appError.message}', e);
      _trackError(appError);

      _isLoading = false;
      _currentError = appError;
      _isUsingFallbackData = _nftAssets.isNotEmpty;

      if (showLoading && !isAutoRefresh && _nftAssets.isEmpty) {
        _showErrorSnackBar(appError);
      }

      notifyListeners();
    }
  }

  // ==================== State Management ====================
  void setSelectedTab(int tab) {
    _selectedTab = tab;
    _loadCurrentTabData();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _currentError = null;
    _isUsingFallbackData = false;
    notifyListeners();
  }

  List<dynamic> getCurrentList() {
    try {
      switch (_selectedTab) {
        case 1:
          return _cryptoAssets;
        case 2:
          return _stockAssets;
        case 3:
          return _nftAssets;
        default:
          return [];
      }
    } catch (e) {
      _logError('Failed to get current list', e);
      return [];
    }
  }

  double getTotalBalance() {
    try {
      switch (_selectedTab) {
        case 1:
          return _cryptoAssets
              .where((asset) => asset.amount > 0)
              .fold(0.0, (sum, asset) => sum + asset.valueUSD);
        case 2:
          return _stockAssets
              .where((asset) => asset.amount > 0)
              .fold(0.0, (sum, asset) => sum + asset.valueUSD);
        case 3:
          return _nftAssets
              .where((asset) => asset.amount > 0)
              .fold(0.0, (sum, asset) => sum + asset.valueUSD);
        default:
          return 0;
      }
    } catch (e) {
      _logError('Failed to calculate total balance', e);
      return 0;
    }
  }

  double getTotalChangePercent() {
    try {
      List<dynamic> portfolioAssets;
      switch (_selectedTab) {
        case 1:
          portfolioAssets = _cryptoAssets.where((asset) => asset.amount > 0).toList();
          break;
        case 2:
          portfolioAssets = _stockAssets.where((asset) => asset.amount > 0).toList();
          break;
        case 3:
          portfolioAssets = _nftAssets.where((asset) => asset.amount > 0).toList();
          break;
        default:
          return 0;
      }

      if (portfolioAssets.isEmpty) return 0;

      double totalValue = 0;
      double weightedChange = 0;

      for (var asset in portfolioAssets) {
        final valueUSD = asset.valueUSD;
        final changePercent = asset.changePercent;
        totalValue += valueUSD;
        weightedChange += valueUSD * changePercent;
      }

      return totalValue > 0 ? weightedChange / totalValue : 0;
    } catch (e) {
      _logError('Failed to calculate total change percent', e);
      return 0;
    }
  }

  // ==================== Error Handling ====================
  bool _canAutoRefresh() {
    if (_rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!)) {
      return false;
    }
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      return false;
    }
    return true;
  }

  void _trackError(AppError error) {
    final now = DateTime.now();

    if (_lastErrorTime != null && now.difference(_lastErrorTime!) > _errorResetDuration) {
      _consecutiveErrors = 0;
      _logInfo('Error counter reset after ${_errorResetDuration.inMinutes} minutes');
    }

    _consecutiveErrors++;
    _lastErrorTime = now;
    _logWarning('Error count: $_consecutiveErrors/$_maxConsecutiveErrors (${error.type.name})');

    if (error.type == ErrorType.rateLimit) {
      _rateLimitUntil = now.add(_rateLimitCooldown);
      _logWarning('Rate limited until $_rateLimitUntil');
    }

    if (_consecutiveErrors >= _maxConsecutiveErrors && !error.isFatal) {
      _logError('Maximum consecutive errors reached!');
    } else if (error.isFatal) {
      // Handled in UI layer
    }

    notifyListeners();
  }

  void _resetErrorTracking() {
    if (_consecutiveErrors > 0) {
      _logSuccess('Error tracking reset - successful operation');
      _consecutiveErrors = 0;
      _lastErrorTime = null;
      _lastSuccessTime = DateTime.now();
      _currentError = null;
      notifyListeners();
    }
  }

  // ==================== Logout ====================
  Future<bool> logout(AuthService authService) async {
    _logInfo('Logout initiated by user');
    try {
      _logInfo('Signing out user...');
      await authService.signOut();
      _logSuccess('User logged out successfully');
      return true;
    } catch (e) {
      _logError('Failed to logout', e);
      return false;
    }
  }

  // ==================== Logging ====================
  void _logInfo(String message) {
    if (const bool.fromEnvironment('dart.vm.product')) return;
    debugPrint('[HomeScreen] $message');
  }

  void _logSuccess(String message) {
    if (const bool.fromEnvironment('dart.vm.product')) return;
    debugPrint('[HomeScreen] ✓ $message');
  }

  void _logWarning(String message) {
    if (const bool.fromEnvironment('dart.vm.product')) return;
    debugPrint('[HomeScreen] ⚠ $message');
  }

  void _logError(String message, [dynamic error]) {
    debugPrint('[HomeScreen] ✗ $message');
    if (error != null && !const bool.fromEnvironment('dart.vm.product')) {
      debugPrint('   Details: ${error.toString().split('\n').first}');
    }
  }

  // ==================== Snackbar Methods (Placeholders) ====================
  void _showErrorSnackBar(AppError error) {
    // Akan dipanggil dari UI
  }

  void _showInfoSnackBar(String message) {
    // Akan dipanggil dari UI
  }

  void _showSuccessSnackBar(String message) {
    // Akan dipanggil dari UI
  }
}

// ==================== Home Screen Widget ====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeScreenProvider _provider;
  int _currentIndex = 0;

  final CryptoService _cryptoService = CryptoService();
  final StockService _stockService = StockService();
  final NFTService _nftService = NFTService();
  final AuthService _authService = AuthService();
  final WalletService _walletService = WalletService();

  @override
  void initState() {
    super.initState();
    _provider = HomeScreenProvider(
      cryptoService: _cryptoService,
      stockService: _stockService,
      nftService: _nftService,
      authService: _authService,
      walletService: _walletService,
    );
    _provider.initialize();
    _provider.startAutoRefresh();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(AppError error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error.icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (error.type == ErrorType.rateLimit && _provider.rateLimitUntil != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Try again in ${_provider.rateLimitUntil!.difference(DateTime.now()).inSeconds}s',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: error.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: error.type == ErrorType.rateLimit ? 6 : 4),
        action: error.type != ErrorType.rateLimit
            ? SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _provider._loadCurrentTabData(),
        )
            : null,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleLogout() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Logout',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final success = await _provider.logout(_authService);
        if (success && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        } else if (!success && mounted) {
          _showErrorSnackBar(
            AppError(
              type: ErrorType.unknown,
              message: 'Failed to logout. Please try again.',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
          AppError(
            type: ErrorType.unknown,
            message: 'Failed to logout. Please try again.',
            technicalDetails: e.toString(),
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${_authService.currentUser?.displayName ?? 'User'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                    onPressed: _handleLogout,
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_provider.portfolio.isEmpty && !_provider.isLoading) ...[
              const DatabaseInitializerWidget(),
              const SizedBox(height: 12),
            ],
            WalletCard(
              balance: _provider.getTotalBalance(),
              changePercent: _provider.getTotalChangePercent(),
              walletAddress: _provider.walletAddress,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTab('Cash', 0),
                  _buildTab('Crypto', 1),
                  _buildTab('Stocks', 2),
                  _buildTab('NFT', 3),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 20),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //     children: [
            //       Row(
            //         children: [
            //           const Text(
            //             'Total',
            //             style: TextStyle(
            //               color: AppColors.textSecondary,
            //               fontSize: 16,
            //               fontWeight: FontWeight.w500,
            //             ),
            //           ),
            //           if (_provider.isUsingFallbackData) ...[
            //             const SizedBox(width: 8),
            //             Tooltip(
            //               message: 'Using demo data',
            //               child: Icon(
            //                 Icons.info_outline,
            //                 size: 16,
            //                 color: AppColors.textSecondary.withOpacity(0.6),
            //               ),
            //             ),
            //           ],
            //           if (_provider.consecutiveErrors > 0) ...[
            //             const SizedBox(width: 8),
            //             Tooltip(
            //               message: 'Connection issues detected',
            //               child: Icon(
            //                 Icons.warning_amber_rounded,
            //                 size: 16,
            //                 color: AppColors.red.withOpacity(0.8),
            //               ),
            //             ),
            //           ],
            //           if (_provider.rateLimitUntil != null &&
            //               DateTime.now().isBefore(_provider.rateLimitUntil!)) ...[
            //             const SizedBox(width: 8),
            //             Tooltip(
            //               message: 'Rate limited',
            //               child: Icon(
            //                 Icons.speed,
            //                 size: 16,
            //                 color: AppColors.yellow.withOpacity(0.8),
            //               ),
            //             ),
            //           ],
            //         ],
            //       ),
            //       Row(
            //         children: [
            //           if (!_provider.isLoading) ...[
            //             Text(
            //               '\${_provider.getTotalBalance().toStringAsFixed(2)}',
            //               style: const TextStyle(
            //                 color: AppColors.textPrimary,
            //                 fontSize: 16,
            //                 fontWeight: FontWeight.w600,
            //               ),
            //             ),
            //             const SizedBox(width: 8),
            //             Text(
            //               '${_provider.getTotalChangePercent() >= 0 ? '+' : ''}${_provider.getTotalChangePercent().toStringAsFixed(1)}%',
            //               style: TextStyle(
            //                 color: _provider.getTotalChangePercent() >= 0
            //                     ? AppColors.green
            //                     : AppColors.red,
            //                 fontSize: 14,
            //                 fontWeight: FontWeight.w600,
            //               ),
            //             ),
            //             const SizedBox(width: 12),
            //           ],
            //           IconButton(
            //             icon: Icon(
            //               Icons.refresh,
            //               color: _provider.isLoading
            //                   ? AppColors.primary
            //                   : AppColors.textSecondary,
            //               size: 20,
            //             ),
            //             onPressed: _provider.isLoading
            //                 ? null
            //                 : () => _provider._loadCurrentTabData(),
            //             tooltip: 'Refresh data',
            //           ),
            //         ],
            //       ),
            //     ],
            //   ),
            // ),
            // Ganti bagian Row yang menampilkan Total balance (sekitar baris 700-750)
// dengan kode ini:

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Total label with indicators
                  Flexible(
                    flex: 2,
                    child: Row(
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_provider.isUsingFallbackData) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Using demo data',
                            child: Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppColors.textSecondary.withOpacity(0.6),
                            ),
                          ),
                        ],
                        if (_provider.consecutiveErrors > 0) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Connection issues detected',
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: AppColors.red.withOpacity(0.8),
                            ),
                          ),
                        ],
                        if (_provider.rateLimitUntil != null &&
                            DateTime.now().isBefore(_provider.rateLimitUntil!)) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Rate limited',
                            child: Icon(
                              Icons.speed,
                              size: 14,
                              color: AppColors.yellow.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Right side - Balance and refresh
                  Flexible(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!_provider.isLoading) ...[
                          Flexible(
                            child: Text(
                              '\$${_provider.getTotalBalance().toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_provider.getTotalChangePercent() >= 0 ? '+' : ''}${_provider.getTotalChangePercent().toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: _provider.getTotalChangePercent() >= 0
                                  ? AppColors.green
                                  : AppColors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: _provider.isLoading
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _provider.isLoading
                              ? null
                              : () => _provider._loadCurrentTabData(),
                          tooltip: 'Refresh data',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildAssetList()),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ActivityScreen()),
            ).then((_) => setState(() => _currentIndex = 0));
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ExchangeScreen()),
            ).then((_) => setState(() => _currentIndex = 0));
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DiscoverScreen()),
            ).then((_) => setState(() => _currentIndex = 0));
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ).then((_) => setState(() => _currentIndex = 0));
          }
        },
      ),
    );
  }

  Widget _buildAssetList() {
    if (_provider.selectedTab == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cash/Fiat Coming Soon',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_provider.isLoading && _provider.getCurrentList().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Loading data...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            if (_provider.lastSuccessTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last updated: ${_formatTimestamp(_provider.lastSuccessTime!)}',
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_provider.currentError != null && _provider.getCurrentList().isEmpty) {
      final error = _provider.currentError!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                error.icon,
                color: error.color,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                error.message,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_provider.consecutiveErrors > 0)
                Text(
                  'Failed attempts: ${_provider.consecutiveErrors}/3',
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              if (_provider.rateLimitUntil != null &&
                  DateTime.now().isBefore(_provider.rateLimitUntil!)) ...[
                const SizedBox(height: 8),
                Text(
                  'Try again in ${_provider.rateLimitUntil!.difference(DateTime.now()).inSeconds}s',
                  style: TextStyle(
                    color: AppColors.yellow.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: (_provider.rateLimitUntil != null &&
                    DateTime.now().isBefore(_provider.rateLimitUntil!))
                    ? null
                    : () => _provider._loadCurrentTabData(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (error.type == ErrorType.network) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    _showInfoSnackBar('Check your WiFi or mobile data');
                  },
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Connection Help'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final currentList = _provider.getCurrentList();
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.cardBackground,
      onRefresh: () {
        return _provider._loadCurrentTabData(showLoading: false);
      },
      child: currentList.isEmpty
          ? ListView(
        padding: const EdgeInsets.all(40),
        children: [
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No assets found',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add some assets to your portfolio',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: currentList.length,
        itemBuilder: (context, index) {
          try {
            switch (_provider.selectedTab) {
              case 1:
                return CryptoListItem(asset: _provider.cryptoAssets[index]);
              case 2:
                return StockListItem(asset: _provider.stockAssets[index]);
              case 3:
                return NFTListItem(asset: _provider.nftAssets[index]);
              default:
                return const SizedBox();
            }
          } catch (e) {
            return const SizedBox();
          }
        },
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _provider.selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _provider.setSelectedTab(index);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}