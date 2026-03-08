import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sofi_test_connect/presentation/mood/mood_mode.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';

/// Subscription plan types
enum SubscriptionPlan {
  free,
  weekly,
  monthly,
  annual,
}

/// Premium service that manages subscription state and daily limits
/// Refactored to use Apple In-App Purchases (IAP) for Guideline 3.1.1 compliance.
class PremiumService extends ChangeNotifier {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  // App Store Product IDs (Replace these with your real IDs from App Store Connect)
  static const String _idWeekly = 'sofi_premium_weekly';
  static const String _idMonthly = 'sofi_premium_monthly';
  static const String _idAnnual = 'sofi_premium_annual';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];

  // Coupon codes mapping
  static const Map<String, SubscriptionPlan> _validCoupons = {
    'FREE_PREMIUM': SubscriptionPlan.monthly,
    'STUDIO_ACCESS': SubscriptionPlan.weekly,
    'SOPHIE_GIFT': SubscriptionPlan.annual,
  };

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
  static const String _abKey = 'ab_default_mode';
  
  // Pricing (Fallbacks if StoreKit is unavailable)
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
  List<ProductDetails> get products => _products;
  
  /// Initialize the service and load saved state
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Setup IAP Listener
      final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        _subscription?.cancel();
      }, onError: (error) {
        debugPrint('IAP Stream Error: $error');
      });

      // Fetch Products
      final bool available = await _iap.isAvailable();
      if (available) {
        final ProductDetailsResponse response = await _iap.queryProductDetails({
          _idWeekly, _idMonthly, _idAnnual
        });
        _products = response.productDetails;
        debugPrint('Fetched ${_products.length} IAP products');
      }

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
      _isInitialized = true;
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show loading indicator in UI if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase Error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          // Verify purchase (server-side check recommended)
          final plan = _getPlanFromId(purchaseDetails.productID);
          if (plan != SubscriptionPlan.free) {
            await activateSubscription(plan);
          }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    });
  }

  SubscriptionPlan _getPlanFromId(String id) {
    if (id == _idWeekly) return SubscriptionPlan.weekly;
    if (id == _idMonthly) return SubscriptionPlan.monthly;
    if (id == _idAnnual) return SubscriptionPlan.annual;
    return SubscriptionPlan.free;
  }

  /// Trigger a purchase for the selected plan
  Future<void> buyPlan(SubscriptionPlan plan) async {
    String? productId;
    switch (plan) {
      case SubscriptionPlan.weekly: productId = _idWeekly; break;
      case SubscriptionPlan.monthly: productId = _idMonthly; break;
      case SubscriptionPlan.annual: productId = _idAnnual; break;
      default: return;
    }

    final ProductDetails productDetails = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product $productId not found'),
    );

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Restore historical purchases
  Future<void> restorePurchases() async {
    debugPrint('Restoring purchases...');
    await _iap.restorePurchases();
  }
  
  /// Check if daily count should be reset (at midnight local time)
  void _checkAndResetDailyCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_lastResetDate == null) {
      _lastResetDate = today;
      _dailyGenerationsUsed = 0;
      _saveState();
      return;
    }
    
    final lastReset = DateTime(_lastResetDate!.year, _lastResetDate!.month, _lastResetDate!.day);
    if (today.isAfter(lastReset)) {
      _dailyGenerationsUsed = 0;
      _lastResetDate = today;
      _saveState();
    }
  }
  
  /// Record a generation
  Future<bool> recordGeneration() async {
    await initialize();
    _checkAndResetDailyCount();
    
    if (!canGenerate) return false;
    
    if (!isPremium) {
      _dailyGenerationsUsed++;
      await _saveState();
      notifyListeners();
    }
    return true;
  }

  /// DEBUG: Clear premium status
  Future<void> debugClearPremium() async {
    _currentPlan = SubscriptionPlan.free;
    _subscriptionExpiryDate = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_planKey);
    await prefs.remove(_expiryKey);
    notifyListeners();
  }
  
  bool tryUseGeneration() {
    _checkAndResetDailyCount();
    if (isPremium) return true;
    if (_dailyGenerationsUsed >= freeUserDailyLimit) return false;
    return true;
  }
  
  /// Activate a subscription local state
  Future<void> activateSubscription(SubscriptionPlan plan) async {
    _currentPlan = plan;
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
    debugPrint('Subscription UI updated: $plan');
  }

  /// Redeem a coupon code (stays for demo purposes)
  Future<bool> redeemCoupon(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (_validCoupons.containsKey(normalizedCode)) {
      final plan = _validCoupons[normalizedCode]!;
      await activateSubscription(plan);
      return true;
    }
    return false;
  }
  
  /// Restore a subscription (legacy manual call)
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
  
  static String getPriceString(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.weekly: return '\$${weeklyPrice.toStringAsFixed(2)}/week';
      case SubscriptionPlan.monthly: return '\$${monthlyPrice.toStringAsFixed(2)}/month';
      case SubscriptionPlan.annual: return '\$${annualPrice.toStringAsFixed(2)}/year';
      case SubscriptionPlan.free: return 'Free';
    }
  }
  
  static String getSavingsString(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.monthly: return 'Save 52%';
      case SubscriptionPlan.annual: return 'Save 80%';
      default: return '';
    }
  }
  
  static double getMonthlyEquivalent(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.weekly: return weeklyPrice * 4.33;
      case SubscriptionPlan.monthly: return monthlyPrice;
      case SubscriptionPlan.annual: return annualPrice / 12;
      case SubscriptionPlan.free: return 0;
    }
  }
  
  Future<void> debugResetDailyCount() async {
    _dailyGenerationsUsed = 0;
    _lastResetDate = DateTime.now();
    await _saveState();
    notifyListeners();
  }
  
  bool canUseDailyPreview() {
    _checkAndResetDailyCount();
    return _dailyGenerationsUsed == 0;
  }
  
  Future<void> markPreviewUsed() async {
    _dailyGenerationsUsed = 1;
    await _saveState();
    notifyListeners();
  }
  
  Future<MoodMode> getDefaultMoodForUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_abKey);
      if (saved != null) {
        try {
          return MoodMode.values.byName(saved);
        } catch (_) {}
      }
      final assigned = DateTime.now().millisecondsSinceEpoch % 2 == 0
          ? MoodMode.human
          : MoodMode.doll;
      await prefs.setString(_abKey, assigned.name);
      return assigned;
    } catch (e) {
      debugPrint('A/B test assignment error: $e');
      return MoodMode.human;
    }
  }
}
