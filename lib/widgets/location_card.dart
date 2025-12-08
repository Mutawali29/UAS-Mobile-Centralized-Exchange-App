// widgets/location_card.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../utils/app_colors.dart';

class LocationCard extends StatefulWidget {
  const LocationCard({super.key});

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  final LocationService _locationService = LocationService();

  Position? _currentPosition;
  Map<String, String>? _addressData;
  bool _isLoadingLocation = false;
  String? _locationError;

  Future<void> _getLocationData() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      print('Getting location...');

      final position = await _locationService.getCurrentLocation();

      print('Position result: $position');

      if (position != null) {
        // Get address from coordinates
        print('Getting address...');
        final addressData = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        setState(() {
          _currentPosition = position;
          _addressData = addressData;
          _locationError = null;
        });
        _showSnackBar('Location retrieved successfully');
      } else {
        setState(() {
          _locationError = 'Failed to get location. Check permissions & GPS.';
        });
        _showSnackBar('Failed to get location');
      }
    } catch (e) {
      print('Location error: $e');
      setState(() {
        _locationError = 'Error: ${e.toString()}';
      });
      _showSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'My Location',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              _isLoadingLocation
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              )
                  : GestureDetector(
                onTap: _getLocationData,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          if (_locationError != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationError!,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_currentPosition == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  style: BorderStyle.solid,
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap refresh to get your current location',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Address Section (Most Important)
                if (_addressData != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.1),
                          AppColors.primary.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.place,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Address',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _addressData!['fullAddress']!,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Coordinates & Details
                _buildDetailRow(
                  Icons.my_location,
                  'Coordinates',
                  '${LocationService.formatCoordinate(_currentPosition!.latitude)}, ${LocationService.formatCoordinate(_currentPosition!.longitude)}',
                ),
                const SizedBox(height: 8),

                _buildDetailRow(
                  Icons.speed,
                  'Accuracy',
                  '${_currentPosition!.accuracy.toStringAsFixed(2)} m',
                ),

                // Altitude (if available)
                if (_currentPosition!.altitude != 0.0) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.terrain,
                    'Altitude',
                    LocationService.formatAltitude(_currentPosition!.altitude),
                  ),
                ],

                // Speed (if moving)
                if (_currentPosition!.speed > 0) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.speed,
                    'Speed',
                    LocationService.formatSpeed(_currentPosition!.speed),
                  ),
                ],

                // Heading (if available)
                if (_currentPosition!.heading != 0.0) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.explore,
                    'Heading',
                    '${_currentPosition!.heading.toStringAsFixed(0)}° (${LocationService.getCompassDirection(_currentPosition!.heading)})',
                  ),
                ],

                const SizedBox(height: 8),

                // Timestamp
                _buildDetailRow(
                  Icons.access_time,
                  'Updated',
                  _getTimeAgo(_currentPosition!.timestamp),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.textSecondary.withOpacity(0.6),
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    }
  }
}