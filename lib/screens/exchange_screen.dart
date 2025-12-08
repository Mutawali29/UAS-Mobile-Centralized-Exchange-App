import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/exchange_rate.dart';
import '../services/ExchangeService.dart';
import '../services/crypto_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/crypto_selector_bottom_sheet.dart';
import '../utils/app_colors.dart';
import 'discover_screen.dart';
import 'activity_screen.dart';
import 'profile_screen.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  int _currentIndex = 2;

  final TextEditingController _fromAmountController = TextEditingController();
  final TextEditingController _toAmountController = TextEditingController();

  final ExchangeService _exchangeService = ExchangeService();

  List<ExchangePair> _cryptoList = [];
  ExchangePair? _fromCrypto;
  ExchangePair? _toCrypto;

  double _exchangeRate = 0.0;
  double _networkFee = 0.001;

  bool _isLoading = true;
  bool _isCalculating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _fromAmountController.addListener(_onFromAmountChanged);
  }

  @override
  void dispose() {
    _fromAmountController.dispose();
    _toAmountController.dispose();
    super.dispose();
  }

  // Initialize data from Firebase & CoinGecko
  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('👤 Current user: ${user.uid}');

      // Fetch available exchange pairs dengan balance user
      print('📊 Fetching exchange pairs...');
      _cryptoList = await _exchangeService.getAvailableExchangePairs();

      if (_cryptoList.isEmpty) {
        throw Exception('No cryptocurrencies available');
      }

      // Set default crypto pairs
      // Prioritas: crypto dengan balance > 0
      final cryptoWithBalance = _cryptoList.where((c) => c.balance > 0).toList();

      if (cryptoWithBalance.isNotEmpty) {
        _fromCrypto = cryptoWithBalance.first;
        // Cari crypto berbeda untuk toCrypto
        _toCrypto = _cryptoList.firstWhere(
              (c) => c.symbol != _fromCrypto!.symbol,
          orElse: () => _cryptoList[1],
        );
      } else {
        // Jika tidak ada balance, gunakan BTC -> ETH sebagai default
        _fromCrypto = _cryptoList.firstWhere(
              (c) => c.symbol == 'BTC',
          orElse: () => _cryptoList[0],
        );
        _toCrypto = _cryptoList.firstWhere(
              (c) => c.symbol == 'ETH' && c.symbol != _fromCrypto!.symbol,
          orElse: () => _cryptoList[1],
        );
      }

      _calculateExchangeRate();

      setState(() {
        _isLoading = false;
      });

      print('✅ Exchange screen initialized successfully');
      print('   From: ${_fromCrypto!.symbol} (Balance: ${_fromCrypto!.balance})');
      print('   To: ${_toCrypto!.symbol} (Balance: ${_toCrypto!.balance})');

    } catch (e) {
      print('❌ Error initializing data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is CryptoServiceException) {
      return error.message;
    }
    return 'Failed to load data. Please try again.';
  }

  void _calculateExchangeRate() {
    if (_fromCrypto == null || _toCrypto == null) return;

    setState(() {
      _exchangeRate = _exchangeService.calculateExchangeRate(
        _fromCrypto!,
        _toCrypto!,
      );
      _networkFee = _exchangeService.calculateNetworkFee(
        double.tryParse(_fromAmountController.text) ?? 0.001,
        _fromCrypto!.priceUSD,
      );
    });
  }

  void _onFromAmountChanged() {
    if (_fromAmountController.text.isEmpty) {
      _toAmountController.text = '';
      return;
    }

    final fromAmount = double.tryParse(_fromAmountController.text) ?? 0;
    final toAmount = fromAmount * _exchangeRate;
    _toAmountController.text = toAmount.toStringAsFixed(6);

    // Recalculate network fee
    setState(() {
      _networkFee = _exchangeService.calculateNetworkFee(
        fromAmount,
        _fromCrypto!.priceUSD,
      );
    });
  }

  void _swapCryptos() {
    if (_fromCrypto == null || _toCrypto == null) return;

    setState(() {
      final temp = _fromCrypto;
      _fromCrypto = _toCrypto;
      _toCrypto = temp;

      final tempAmount = _fromAmountController.text;
      _fromAmountController.text = _toAmountController.text;
      _toAmountController.text = tempAmount;

      _calculateExchangeRate();
    });
  }

  Future<void> _selectFromCrypto() async {
    if (_toCrypto == null) return;

    final result = await showModalBottomSheet<ExchangePair>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CryptoSelectorBottomSheet(
        cryptoList: _cryptoList,
        selectedCrypto: _fromCrypto,
      ),
    );

    if (result != null && result.symbol != _toCrypto!.symbol) {
      setState(() {
        _fromCrypto = result;
        _calculateExchangeRate();
        _onFromAmountChanged();
      });
    }
  }

  Future<void> _selectToCrypto() async {
    if (_fromCrypto == null) return;

    final result = await showModalBottomSheet<ExchangePair>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CryptoSelectorBottomSheet(
        cryptoList: _cryptoList,
        selectedCrypto: _toCrypto,
      ),
    );

    if (result != null && result.symbol != _fromCrypto!.symbol) {
      setState(() {
        _toCrypto = result;
        _calculateExchangeRate();
        _onFromAmountChanged();
      });
    }
  }

  void _executeExchange() {
    if (_fromCrypto == null || _toCrypto == null) {
      _showSnackBar('Please select cryptocurrencies', isError: true);
      return;
    }

    final fromAmount = double.tryParse(_fromAmountController.text) ?? 0;

    // Validate amount
    if (!_exchangeService.validateExchange(
      fromAmount: fromAmount,
      balance: _fromCrypto!.balance,
      networkFee: _networkFee,
    )) {
      if (fromAmount <= 0) {
        _showSnackBar('Please enter a valid amount', isError: true);
      } else {
        _showSnackBar('Insufficient balance', isError: true);
      }
      return;
    }

    // Check minimum amount
    final minAmount = _exchangeService.getMinimumExchangeAmount(_fromCrypto!.symbol);
    if (fromAmount < minAmount) {
      _showSnackBar(
        'Minimum amount: $minAmount ${_fromCrypto!.symbol}',
        isError: true,
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => _buildConfirmationDialog(fromAmount),
    );
  }

  Widget _buildConfirmationDialog(double fromAmount) {
    final toAmount = double.tryParse(_toAmountController.text) ?? 0;
    final fee = _networkFee * _fromCrypto!.priceUSD;

    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Confirm Exchange',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDialogRow('From:', '$fromAmount ${_fromCrypto!.symbol}'),
          const SizedBox(height: 8),
          _buildDialogRow('To:', '$toAmount ${_toCrypto!.symbol}'),
          const SizedBox(height: 8),
          _buildDialogRow(
            'Rate:',
            '1 ${_fromCrypto!.symbol} = ${_exchangeRate.toStringAsFixed(6)} ${_toCrypto!.symbol}',
          ),
          const SizedBox(height: 8),
          _buildDialogRow('Network Fee:', '\$${fee.toStringAsFixed(2)}'),
          const Divider(color: AppColors.textSecondary, height: 24),
          const Text(
            'This exchange cannot be reversed.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _performExchange(fromAmount, toAmount);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildDialogRow(String label, String value) {
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
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Future<void> _performExchange(double fromAmount, double toAmount) async {
    setState(() {
      _isCalculating = true;
    });

    try {
      // Execute exchange in Firebase
      await _exchangeService.executeExchange(
        fromCrypto: _fromCrypto!,
        toCrypto: _toCrypto!,
        fromAmount: fromAmount,
        toAmount: toAmount,
        exchangeRate: _exchangeRate,
        networkFee: _networkFee,
      );

      // Refresh data
      await _initializeData();

      setState(() {
        _isCalculating = false;
        _fromAmountController.clear();
        _toAmountController.clear();
      });

      _showSnackBar('Exchange completed successfully!');

    } catch (e) {
      print('❌ Exchange failed: $e');
      setState(() {
        _isCalculating = false;
      });
      _showSnackBar(
        'Exchange failed: ${_getErrorMessage(e)}',
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : _buildExchangeContent(),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.pop(context);
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ActivityScreen()),
            );
          } else if (index == 2) {
            // Already on Exchange
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DiscoverScreen()),
            );
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading exchange data...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeContent() {
    if (_fromCrypto == null || _toCrypto == null) {
      return const Center(
        child: Text(
          'No cryptocurrencies available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Exchange',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                    onPressed: _initializeData,
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: AppColors.textSecondary),
                    onPressed: () {
                      // TODO: Show exchange history
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // From Card
                _buildCryptoCard(
                  label: 'From',
                  crypto: _fromCrypto!,
                  controller: _fromAmountController,
                  onTap: _selectFromCrypto,
                  isFrom: true,
                ),

                const SizedBox(height: 16),

                // Swap Button
                Center(
                  child: GestureDetector(
                    onTap: _swapCryptos,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.swap_vert,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // To Card
                _buildCryptoCard(
                  label: 'To',
                  crypto: _toCrypto!,
                  controller: _toAmountController,
                  onTap: _selectToCrypto,
                  isFrom: false,
                ),

                const SizedBox(height: 24),

                // Exchange Rate Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Exchange Rate',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '1 ${_fromCrypto!.symbol} = ${_exchangeRate.toStringAsFixed(6)} ${_toCrypto!.symbol}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Network Fee',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$_networkFee ${_fromCrypto!.symbol} (\$${(_networkFee * _fromCrypto!.priceUSD).toStringAsFixed(2)})',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Exchange Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCalculating ? null : _executeExchange,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    ),
                    child: _isCalculating
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Exchange Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCryptoCard({
    required String label,
    required ExchangePair crypto,
    required TextEditingController controller,
    required VoidCallback onTap,
    required bool isFrom,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                'Balance: ${crypto.balance.toStringAsFixed(4)}',
                style: TextStyle(
                  color: crypto.balance > 0
                      ? AppColors.green
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: crypto.balance > 0
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Crypto Selector
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (crypto.imageUrl != null)
                        Image.network(
                          crypto.imageUrl!,
                          width: 32,
                          height: 32,
                          errorBuilder: (_, __, ___) => _buildIconFallback(crypto),
                        )
                      else
                        _buildIconFallback(crypto),
                      const SizedBox(width: 8),
                      Text(
                        crypto.symbol,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Amount Input
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: !isFrom,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 24,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          if (controller.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '≈ \$${((double.tryParse(controller.text) ?? 0) * crypto.priceUSD).toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconFallback(ExchangePair crypto) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _getIconColor(crypto.symbol),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          crypto.icon,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getIconColor(String symbol) {
    switch (symbol) {
      case 'BTC':
        return AppColors.gold.withOpacity(0.2);
      case 'ETH':
        return Colors.blueGrey.withOpacity(0.2);
      case 'XRP':
        return Colors.grey.withOpacity(0.2);
      case 'BNB':
        return Colors.amber.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }
}