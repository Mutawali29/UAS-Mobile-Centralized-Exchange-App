import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../widgets/transaction_item.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/app_colors.dart';
import 'transaction_detail_screen.dart';
import 'exchange_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 1;
  late TabController _tabController;
  final TransactionService _transactionService = TransactionService();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Filter transactions based on selected tab
  List<Transaction> _filterTransactions(List<Transaction> allTransactions) {
    final selectedTab = _tabController.index;

    if (selectedTab == 0) return allTransactions; // All

    TransactionType? filterType;
    switch (selectedTab) {
      case 1:
        filterType = TransactionType.send;
        break;
      case 2:
        filterType = TransactionType.receive;
        break;
      case 3:
        return allTransactions
            .where((t) =>
        t.type == TransactionType.buy ||
            t.type == TransactionType.sell ||
            t.type == TransactionType.swap)
            .toList();
    }

    if (filterType != null) {
      return allTransactions.where((t) => t.type == filterType).toList();
    }

    return allTransactions;
  }

  // Calculate stats from transactions
  Map<String, double> _calculateStats(List<Transaction> transactions) {
    final totalSent = transactions
        .where((t) =>
    t.type == TransactionType.send &&
        t.status == TransactionStatus.completed)
        .fold(0.0, (sum, t) => sum + t.valueUSD);

    final totalReceived = transactions
        .where((t) =>
    t.type == TransactionType.receive &&
        t.status == TransactionStatus.completed)
        .fold(0.0, (sum, t) => sum + t.valueUSD);

    final totalTrade = transactions
        .where((t) =>
    (t.type == TransactionType.buy ||
        t.type == TransactionType.sell ||
        t.type == TransactionType.swap) &&
        t.status == TransactionStatus.completed)
        .fold(0.0, (sum, t) => sum + t.valueUSD);

    return {
      'sent': totalSent,
      'received': totalReceived,
      'trade': totalTrade,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please login to view your activity',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Activity',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          // TODO: Implement search
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.filter_list,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          // TODO: Implement filter
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stats Cards with Stream
            StreamBuilder<List<Transaction>>(
              stream: _transactionService.getTransactionsStream(_userId!),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final stats = _calculateStats(snapshot.data!);
                  return _buildStatsCards(stats);
                }
                return _buildStatsCards({'sent': 0, 'received': 0, 'trade': 0});
              },
            ),

            const SizedBox(height: 20),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Sent'),
                  Tab(text: 'Received'),
                  Tab(text: 'Trade'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Transaction List with Stream
            Expanded(
              child: StreamBuilder<List<Transaction>>(
                stream: _transactionService.getTransactionsStream(_userId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }

                  final filteredTransactions =
                  _filterTransactions(snapshot.data!);

                  if (filteredTransactions.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      return TransactionItem(
                        transaction: filteredTransactions[index],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionDetailScreen(
                                transaction: filteredTransactions[index],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
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
            // Already on Activity
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ExchangeScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const DiscoverScreen(),
              ),
            );
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

  Widget _buildStatsCards(Map<String, double> stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            'Total Sent',
            '\$${stats['sent']!.toStringAsFixed(2)}',
            Icons.arrow_upward,
            AppColors.gold,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Total Received',
            '\$${stats['received']!.toStringAsFixed(2)}',
            Icons.arrow_downward,
            AppColors.green,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Total Trade',
            '\$${stats['trade']!.toStringAsFixed(2)}',
            Icons.swap_horiz,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your transaction history will appear here',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}