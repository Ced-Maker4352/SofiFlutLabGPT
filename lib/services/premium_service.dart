import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Subscription plan types
enum SubscriptionPlan {
  free,
  weekly,
  monthly,
  annual,
}

/// Premium service that manages subscription state and daily limits
class PremiumService extends ChangeNotifier {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  // Subscription state
  SubscriptionPlan _currentPlan = SubscriptionPlan.free;
  DateTime? _subscriptionExpiryDate;
  
  // Daily generation tracking
  int _dailyGenerationsUsed = 0;
  DateTime? _lastResetDate;
  
  // Constants
  static const int freeUserDailyLimit = 3;
  static const String _planKey = 'premium_plan';
  static const String _expiryKey = 'premium_expiry';
  static const String _dailyCountKey = 'daily_gen_count';
  static const String _lastResetKey = 'daily_reset_date';
  
  // Pricing (in USD)
  static const double weeklyPrice = 4.99;
  static const double monthlyPrice = 9.99;
  static const double annualPrice = 49.99;
  
  bool _isInitialized = false;
  
  // Getters
  SubscriptionPlan get currentPlan => _currentPlan;
  bool get isPremium => _currentPlan != SubscriptionPlan.free && !isExpired;
  bool get isExpired => _subscriptionExpiryDate != null && 
      DateTime.now().isAfter(_subscriptionExpiryDate!);
  DateTime? get expiryDate => _subscriptionExpiryDate;
  int get dailyGenerationsUsed => _dailyGenerationsUsed;
  int get dailyGenerationsRemaining => isPremium 
      ? 999 // Unlimited for premium
      : (freeUserDailyLimit - _dailyGenerationsUsed).clamp(0, freeUserDailyLimit);
  bool get canGenerate => isPremium || dailyGenerationsRemaining > 0;
  bool get isInitialized => _isInitialized;
  
  /// Initialize the service and load saved state
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load subscription plan
      final planIndex = prefs.getInt(_planKey) ?? 0;
      _currentPlan = SubscriptionPlan.values[planIndex.clamp(0, SubscriptionPlan.values.length - 1)];
      
      // Load expiry date
      final expiryStr = prefs.getString(_expiryKey);
      if (expiryStr != null) {
        _subscriptionExpiryDate = DateTime.tryParse(expiryStr);
      }
      
      // Load daily generation count
      _dailyGenerationsUsed = prefs.getInt(_dailyCountKey) ?? 0;
      
      // Load last reset date
      final lastResetStr = prefs.getString(_lastResetKey);
      if (lastResetStr != null) {
        _lastResetDate = DateTime.tryParse(lastResetStr);
      }
      
      // Check if we need to reset daily counter (midnight local time)
      _checkAndResetDailyCount();
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('PremiumService init error: $e');
      _isInitialized = true; // Still mark as initialized to prevent loops
    }
  }
  
  /// Check if daily count should be reset (at midnight local time)
  void _checkAndResetDailyCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_lastResetDate == null) {
      // First time - set reset date to today
      _lastResetDate = today;
      _dailyGenerationsUsed = 0;
      _saveState();
      return;
    }
    
    final lastReset = DateTime(_lastResetDate!.year, _lastResetDate!.month, _lastResetDate!.day);
    
    if (today.isAfter(lastReset)) {
      // New day - reset counter
      _dailyGenerationsUsed = 0;
      _lastResetDate = today;
      _saveState();
      debugPrint('Daily generation counter reset');
    }
  }
  
  /// Record a generation (call this when user generates an image)
  Future<bool> recordGeneration() async {
    await initialize();
    
    _checkAndResetDailyCount();
    
    if (!canGenerate) {
      return false;
    }
    
    if (!isPremium) {
      _dailyGenerationsUsed++;
      await _saveState();
      notifyListeners();
    }
    
    return true;
  }
  
  /// Attempt to use a generation credit
  /// Returns true if allowed, false if limit reached
  bool tryUseGeneration() {
    _checkAndResetDailyCount();
    
    if (isPremium) {
      return true;
    }
    
    if (_dailyGenerationsUsed >= freeUserDailyLimit) {
      return false;
    }
    
    return true;
  }
  
  /// Activate a subscription (called after successful purchase)
  Future<void> activateSubscription(SubscriptionPlan plan) async {
    _currentPlan = plan;
    
    // Set expiry date based on plan
    final now = DateTime.now();
    switch (plan) {
      case SubscriptionPlan.weekly:
        _subscriptionExpiryDate = now.add(const Duration(days: 7));
        break;
      case SubscriptionPlan.monthly:
        _subscriptionExpiryDate = DateTime(now.year, now.month + 1, now.day);
        break;
      case SubscriptionPlan.annual:
        _subscriptionExpiryDate = DateTime(now.year + 1, now.month, now.day);
        break;
      case SubscriptionPlan.free:
        _subscriptionExpiryDate = null;
        break;
    }
    
    await _saveState();
    notifyListeners();
    
    debugPrint('Subscription activated: $plan, expires: $_subscriptionExpiryDate');
  }
  
  /// Restore a subscription (called when restoring purchases)
  Future<void> restoreSubscription({
    required SubscriptionPlan plan,
    required DateTime expiryDate,
  }) async {
    if (expiryDate.isAfter(DateTime.now())) {
      _currentPlan = plan;
      _subscriptionExpiryDate = expiryDate;
      await _saveState();
      notifyListeners();
    }
  }
  
  /// Cancel subscription (revert to free)
  Future<void> cancelSubscription() async {
    // Note: In real app, subscription stays active until expiry
    // This just removes the local record
    _currentPlan = SubscriptionPlan.free;
    _subscriptionExpiryDate = null;
    await _saveState();
    notifyListeners();
  }
  
  /// Save state to shared preferences
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_planKey, _currentPlan.index);
      
      if (_subscriptionExpiryDate != null) {
        await prefs.setString(_expiryKey, _subscriptionExpiryDate!.toIso8601String());
      } else {
        await prefs.remove(_expiryKey);
      }
      
      await prefs.setInt(_dailyCountKey, _dailyGenerationsUsed);
      
      if (_lastResetDate != null) {
        await prefs.setString(_lastResetKey, _lastResetDate!.toIso8601String());
      }
    } catch (e) {
      debugPrint('PremiumService save error: $e');
    }
  }
  
  /// Get formatted price string for a plan
  static String getPriceString(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.weekly:
        return '\$${weeklyPrice.toStringAsFixed(2)}/week';
      case SubscriptionPlan.monthly:
        return '\$${monthlyPrice.toStringAsFixed(2)}/month';
      case SubscriptionPlan.annual:
        return '\$${annualPrice.toStringAsFixed(2)}/year';
      case SubscriptionPlan.free:
        return 'Free';
    }
  }
  
  /// Get savings percentage compared to weekly
  static String getSavingsString(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return 'Save 52%';
      case SubscriptionPlan.annual:
        return 'Save 80%';
      default:
        return '';
    }
  }
  
  /// Get monthly equivalent price
  static double getMonthlyEquivalent(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.weekly:
        return weeklyPrice * 4.33; // ~$21.65/month
      case SubscriptionPlan.monthly:
        return monthlyPrice;
      case SubscriptionPlan.annual:
        return annualPrice / 12; // ~$4.17/month
      case SubscriptionPlan.free:
        return 0;
    }
  }
  
  /// Debug: Reset daily count (for testing)
  Future<void> debugResetDailyCount() async {
    _dailyGenerationsUsed = 0;
    _lastResetDate = DateTime.now();
    await _saveState();
    notifyListeners();
  }
  
  /// Debug: Grant premium (for testing)
  Future<void> debugGrantPremium() async {
    await activateSubscription(SubscriptionPlan.monthly);
  }
}
