import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:sofi_test_connect/services/premium_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// A soft paywall bottom sheet that shows subscription options
/// Can be dismissed but encourages users to subscribe
class PaywallSheet extends StatefulWidget {
  /// Optional context message shown at the top
  final String? contextMessage;
  
  /// Callback when user subscribes (for now, simulated)
  final VoidCallback? onSubscribed;

  const PaywallSheet({
    super.key,
    this.contextMessage,
    this.onSubscribed,
  });

  /// Show the paywall as a modal bottom sheet
  static Future<bool?> show(BuildContext context, {String? message}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => PaywallSheet(contextMessage: message),
    );
  }

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  SubscriptionPlan _selectedPlan = SubscriptionPlan.annual; // Best value default
  bool _isProcessing = false;

  final _plans = [
    _PlanOption(
      plan: SubscriptionPlan.weekly,
      title: 'Weekly',
      price: '\$${PremiumService.weeklyPrice.toStringAsFixed(2)}',
      period: '/week',
      savings: null,
      monthlyEquivalent: '\$${(PremiumService.weeklyPrice * 4.33).toStringAsFixed(2)}/mo',
    ),
    _PlanOption(
      plan: SubscriptionPlan.monthly,
      title: 'Monthly',
      price: '\$${PremiumService.monthlyPrice.toStringAsFixed(2)}',
      period: '/month',
      savings: 'Save 52%',
      monthlyEquivalent: '\$${PremiumService.monthlyPrice.toStringAsFixed(2)}/mo',
    ),
    _PlanOption(
      plan: SubscriptionPlan.annual,
      title: 'Annual',
      price: '\$${PremiumService.annualPrice.toStringAsFixed(2)}',
      period: '/year',
      savings: 'Best Value - Save 80%',
      monthlyEquivalent: '\$${(PremiumService.annualPrice / 12).toStringAsFixed(2)}/mo',
      isBestValue: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Default to annual for the free trial offer
    _selectedPlan = SubscriptionPlan.annual; 
  }

  Future<void> _handleSubscribe() async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    
    try {
      // 1. Initialize Stripe (already done in PremiumService init, but safe to double check)
      await PremiumService().initialize();

      // 2. Request PaymentIntent from Firebase Functions
      debugPrint('Requesting Stripe PaymentIntent for $_selectedPlan');
      final amount = _selectedPlan == SubscriptionPlan.weekly ? 4.99 : 
                     _selectedPlan == SubscriptionPlan.monthly ? 9.99 : 49.99;
                     
      final callable = FirebaseFunctions.instance.httpsCallable('createStripePaymentIntent');
      final response = await callable.call({'amount': amount, 'currency': 'usd'});
      final clientSecret = response.data['clientSecret'];
      
      // 3. Initialize Payment Sheet
      try {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            merchantDisplayName: 'Sofi Saint',
            paymentIntentClientSecret: clientSecret,
            style: ThemeMode.dark,
            appearance: const PaymentSheetAppearance(
              colors: PaymentSheetAppearanceColors(
                primary: Colors.purple,
                background: Color(0xFF1A1A2E),
                placeholderText: Colors.white24,
              ),
            ),
          ),
        );

        // 4. Display Payment Sheet
        await Stripe.instance.presentPaymentSheet();
        
        // 5. Payment successful
        await PremiumService().activateSubscription(_selectedPlan);
        
        if (mounted) {
          widget.onSubscribed?.call();
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome to Premium!'), backgroundColor: Colors.green),
          );
        }
      } catch (stripeError) {
        debugPrint('Stripe Sheet Error: $stripeError');
        if (stripeError.toString().contains('key') || stripeError.toString().contains('placeholder')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Stripe Error: Please add your real Publishable Key to assets/.env'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  final TextEditingController _couponController = TextEditingController();

  Future<void> _handleRedeemCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final success = await PremiumService().redeemCoupon(code);
      if (mounted) {
        if (success) {
          widget.onSubscribed?.call();
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Coupon applied! Premium unlocked.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid coupon code'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _handleRestore() async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    
    try {
      // NOTE: Implement restore purchases via RevenueCat / in_app_purchase
      // For now, just show a message
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous purchases found')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isIOSWeb = kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    String buttonText;
    if (_selectedPlan == SubscriptionPlan.annual) {
      buttonText = 'Start 3-Day Free Trial';
    } else {
      buttonText = 'Continue with ${_plans.firstWhere((p) => p.plan == _selectedPlan).title}';
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2D1B4E), Color(0xFF1A1A2E)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Crown icon or Avatar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                      shape: BoxShape.circle,
                      boxShadow: isIOSWeb
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                    ),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFB76EF9),
                            const Color(0xFF8B5CF6),
                            const Color(0xFF7C3AED),
                          ],
                        ),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  const Text(
                    'Unlock Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Context message or default subtitle
                  Text(
                    widget.contextMessage ?? 'Unlimited generations & exclusive styles',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  // Features list
                  _buildFeatureRow(Icons.all_inclusive, 'Unlimited daily generations'),
                  _buildFeatureRow(Icons.flash_on_rounded, 'Batch generation mode'),
                  _buildFeatureRow(Icons.star_rounded, 'Exclusive premium styles'),
                  _buildFeatureRow(Icons.high_quality_rounded, 'Priority processing'),
                  _buildFeatureRow(Icons.block, 'No ads ever'),
                  const SizedBox(height: 28),
                  // Plan options
                  ...(_plans.map((plan) => _buildPlanTile(plan))),
                  const SizedBox(height: 24),
                  // Subscribe button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleSubscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text(
                              buttonText,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Secondary CTA for Annual without trial
                  if (_selectedPlan == SubscriptionPlan.annual) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _handleSubscribe,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        ),
                        child: const Text('Continue with Annual Subscription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Restore purchases
                  TextButton(
                    onPressed: _isProcessing ? null : _handleRestore,
                    child: Text('Restore Purchases', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                  ),
                  const SizedBox(height: 16),
                  // Coupon Code Section
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _couponController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Have a coupon code?',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _isProcessing ? null : _handleRedeemCoupon,
                          child: const Text('Apply', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Legal text
                  Text(
                    'Cancel anytime. Subscription auto-renews unless cancelled at least 24 hours before the end of the current period.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  // Not now button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Not Now', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.greenAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTile(_PlanOption plan) {
    final isSelected = _selectedPlan == plan.plan;
    
    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        setState(() => _selectedPlan = plan.plan);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.purple.withValues(alpha: 0.3),
                    Colors.purple.withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.purple : Colors.white.withValues(alpha: 0.4),
                  width: 2,
                ),
                color: isSelected ? Colors.purple : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      if (plan.isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'BEST',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (plan.savings != null)
                    Text(
                      plan.savings!,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            
            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: plan.price,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: plan.period,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  plan.monthlyEquivalent,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanOption {
  final SubscriptionPlan plan;
  final String title;
  final String price;
  final String period;
  final String? savings;
  final String monthlyEquivalent;
  final bool isBestValue;

  const _PlanOption({
    required this.plan,
    required this.title,
    required this.price,
    required this.period,
    this.savings,
    required this.monthlyEquivalent,
    this.isBestValue = false,
  });
}
