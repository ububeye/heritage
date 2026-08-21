import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../blocs/premium/premium_cubit.dart';
import '../../blocs/premium/premium_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/payment_method_icons.dart';
import '../widgets/payment_processing_overlay.dart';

/// Full-screen secure checkout screen.
///
/// Shows:
///   - Order summary (plan name + price)
///   - Payment method selector (Card | M-Pesa | PayPal | Google Pay)
///   - Card form with live validation and brand detection
///   - Animated processing overlay on submit
///
/// Calls [PremiumCubit.purchase] on a valid form, then shows the
/// processing overlay and waits for the BlocListener result.
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.planId});

  final PlanId planId;

  static Future<void> push(BuildContext context, PlanId planId) {
    // Capture the cubit BEFORE the route push. Reading the provider
    // inside the builder closure races with the navigator's mount of
    // the new route — the caller's context can be partially torn down
    // by the time the builder runs, which throws `ProviderNotFound`
    // and silently drops the cubit reference. The result: the Pay
    // button reaches `cubit.purchase()` against a null/stale instance
    // and appears to do nothing. Same pattern as `UpgradeNavigator`.
    final cubit = context.read<PremiumCubit>();
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: PaymentSheet.routeName),
        fullscreenDialog: true,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: PaymentSheet(planId: planId),
        ),
      ),
    );
  }

  /// Stable route name so the success dialog can identify and pop
  /// this route as part of the upgrade-purchase stack unwind.
  /// See [UpgradeContent._showSuccessDialog].
  static const String routeName = '/payment-sheet';

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

// ── Payment method tabs ───────────────────────────────────────────────────────

enum _PayMethod { card, mpesa, paypal, googlePay }

// ── Card brand detection ──────────────────────────────────────────────────────

enum _CardBrand { unknown, visa, mastercard, amex }

_CardBrand _detectBrand(String number) {
  final n = number.replaceAll(' ', '');
  if (n.startsWith('4')) return _CardBrand.visa;
  if (n.startsWith('34') || n.startsWith('37')) return _CardBrand.amex;
  final prefix = int.tryParse(n.length >= 2 ? n.substring(0, 2) : '0') ?? 0;
  if (prefix >= 51 && prefix <= 55) return _CardBrand.mastercard;
  final prefix4 = int.tryParse(n.length >= 4 ? n.substring(0, 4) : '0') ?? 0;
  if (prefix4 >= 2221 && prefix4 <= 2720) return _CardBrand.mastercard;
  return _CardBrand.unknown;
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentSheetState extends State<PaymentSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Card fields
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  // Mobile money field
  final _phoneCtrl = TextEditingController();

  _PayMethod _method = _PayMethod.card;
  _CardBrand _brand = _CardBrand.unknown;

  // Overlay key so the parent can resolve the result into it
  final _overlayKey = GlobalKey<_PaymentProcessingOverlayWrapperState>();
  bool _showOverlay = false;

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _planLabel {
    switch (widget.planId) {
      case PlanId.monthly:
        return 'Explorer Monthly';
      case PlanId.yearly:
        return 'Explorer Yearly';
      case PlanId.proMonthly:
        return 'Pro Monthly';
      case PlanId.proYearly:
        return 'Pro Yearly';
      case PlanId.lifetime:
        return 'Lifetime Access';
    }
  }

  double get _planPrice {
    switch (widget.planId) {
      case PlanId.monthly:
        return AppConstants.explorerMonthlyPrice;
      case PlanId.yearly:
        return AppConstants.explorerYearlyPrice;
      case PlanId.proMonthly:
        return AppConstants.proMonthlyPrice;
      case PlanId.proYearly:
        return AppConstants.proYearlyPrice;
      case PlanId.lifetime:
        return AppConstants.lifetimePrice;
    }
  }

  bool get _isLifetime => widget.planId == PlanId.lifetime;

  // ── Card number formatting ──────────────────────────────────────────────────

  void _onCardNumberChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final maxLen = _brand == _CardBrand.amex ? 15 : 16;
    final clamped = digits.substring(0, digits.length.clamp(0, maxLen));

    // Insert spaces: Amex 4-6-5, others 4-4-4-4
    String formatted;
    if (_brand == _CardBrand.amex) {
      formatted = [
        if (clamped.isNotEmpty) clamped.substring(0, clamped.length.clamp(0, 4)),
        if (clamped.length > 4) clamped.substring(4, clamped.length.clamp(4, 10)),
        if (clamped.length > 10) clamped.substring(10, clamped.length.clamp(10, 15)),
      ].join(' ');
    } else {
      formatted = [
        if (clamped.isNotEmpty) clamped.substring(0, clamped.length.clamp(0, 4)),
        if (clamped.length > 4) clamped.substring(4, clamped.length.clamp(4, 8)),
        if (clamped.length > 8) clamped.substring(8, clamped.length.clamp(8, 12)),
        if (clamped.length > 12) clamped.substring(12, clamped.length.clamp(12, 16)),
      ].join(' ');
    }

    if (formatted != _cardNumberCtrl.text) {
      _cardNumberCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final newBrand = _detectBrand(formatted);
    if (newBrand != _brand) setState(() => _brand = newBrand);
  }

  // ── Expiry formatting ───────────────────────────────────────────────────────

  void _onExpiryChanged(String raw) {
    // Strip non-digits then cap at 4 digits (MMYY). The previous
    // version clamped raw.length (which counts the auto-inserted '/')
    // instead of the post-strip digits.length, so a 4-character input
    // that already contained a '/' produced a 3-digit string and
    // substring(0, 4) threw RangeError.
    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    final digits = digitsOnly.substring(0, digitsOnly.length.clamp(0, 4));
    String formatted = digits;
    if (digits.length >= 3) {
      formatted = '${digits.substring(0, 2)}/${digits.substring(2)}';
    } else if (digits.length == 2 && !raw.contains('/')) {
      formatted = '$digits/';
    }
    if (formatted != _expiryCtrl.text) {
      _expiryCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  String? _validateCardNumber(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final digits = v.replaceAll(' ', '');
    final minLen = _brand == _CardBrand.amex ? 15 : 16;
    if (digits.length < minLen) return 'Enter full card number';
    return null;
  }

  String? _validateExpiry(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final parts = v.split('/');
    if (parts.length != 2) return 'Use MM/YY';
    final mm = int.tryParse(parts[0]);
    final yy = int.tryParse(parts[1]);
    if (mm == null || yy == null || mm < 1 || mm > 12) return 'Invalid date';
    final now = DateTime.now();
    final century = (now.year ~/ 100) * 100;
    final expYear = century + yy;
    final expDate = DateTime(expYear, mm + 1);
    if (expDate.isBefore(now)) return 'Card expired';
    return null;
  }

  String? _validateCvv(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final len = _brand == _CardBrand.amex ? 4 : 3;
    if (v.length < len) return '$len digits required';
    return null;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!v.contains(' ')) return 'Enter full name';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return 'Enter valid phone number';
    return null;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Capture cubit reference BEFORE any async gap.
    final cubit = context.read<PremiumCubit>();

    // Show the overlay.
    setState(() => _showOverlay = true);
    // Small delay so overlay is mounted before we call purchase.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    // Delegate to cubit (which calls FakeBillingProvider).
    await cubit.purchase();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<PremiumCubit, PremiumState>(
      listenWhen: (prev, next) =>
          prev.lastOutcome != next.lastOutcome && _showOverlay,
      listener: (context, state) {
        if (!_showOverlay) return;
        final overlayState = _overlayKey.currentState;
        if (overlayState == null) return;

        if (state.lastOutcome == PurchaseOutcome.success) {
          overlayState.showResult(
            success: true,
            label: 'Payment successful!',
          );
        } else if (state.lastOutcome == PurchaseOutcome.error) {
          overlayState.showResult(
            success: false,
            label: state.errorMessage ?? 'Payment failed',
          );
        } else if (state.lastOutcome == PurchaseOutcome.cancelled) {
          // Previously silent: the overlay just hid and the user was
          // left staring at the payment sheet with no indication of
          // what happened. This is the path the fake provider hits
          // ~10 % of the time and the only path for a real user
          // tapping back in the Play / Stripe sheet. Surface a
          // gentle SnackBar so the next tap is informed.
          setState(() => _showOverlay = false);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Payment cancelled. Tap Pay to try again.'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Secure Checkout'),
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.x),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                borderRadius: AppRadius.fullBorder,
                border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsRegular.lock,
                    size: 13,
                    color: Color(0xFF22C55E),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'SSL Secured',
                    style: TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            _buildForm(context),
            if (_showOverlay)
              _OverlayWrapper(
                overlayKey: _overlayKey,
                label: 'Processing payment…',
                onDone: (success) {
                  setState(() => _showOverlay = false);
                  if (success && mounted) Navigator.of(context).maybePop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Order summary ─────────────────────────────────────────────────
          _OrderSummaryCard(
            planLabel: _planLabel,
            price: _planPrice,
            isLifetime: _isLifetime,
          ),
          const SizedBox(height: 24),

          // ── Payment method tabs ───────────────────────────────────────────
          _SectionLabel(text: 'Payment method'),
          const SizedBox(height: 10),
          _MethodSelector(
            selected: _method,
            onChanged: (m) => setState(() => _method = m),
          ),
          const SizedBox(height: 24),

          // ── Card form or mobile-money ────────────────────────────────────
          if (_method == _PayMethod.card) ...[
            _SectionLabel(text: 'Card details'),
            const SizedBox(height: 10),
            // Card number
            _CardNumberField(
              controller: _cardNumberCtrl,
              brand: _brand,
              onChanged: _onCardNumberChanged,
              validator: _validateCardNumber,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PayField(
                    controller: _expiryCtrl,
                    label: 'Expiry',
                    hint: 'MM/YY',
                    icon: PhosphorIconsRegular.calendarBlank,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    onChanged: _onExpiryChanged,
                    validator: _validateExpiry,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PayField(
                    controller: _cvvCtrl,
                    label: 'Security code',
                    hint: _brand == _CardBrand.amex ? '4 digits' : '3 digits',
                    icon: PhosphorIconsRegular.shieldCheck,
                    keyboardType: TextInputType.number,
                    maxLength: _brand == _CardBrand.amex ? 4 : 3,
                    obscureText: true,
                    validator: _validateCvv,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                        _brand == _CardBrand.amex ? 4 : 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PayField(
              controller: _nameCtrl,
              label: 'Cardholder name',
              hint: 'As printed on card',
              icon: PhosphorIconsRegular.user,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              validator: _validateName,
            ),
          ] else if (_method == _PayMethod.mpesa) ...[
            _SectionLabel(text: 'M-Pesa number'),
            const SizedBox(height: 10),
            _PayField(
              controller: _phoneCtrl,
              label: 'Phone number',
              hint: '+255 7xx xxx xxx',
              icon: PhosphorIconsRegular.phone,
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d\+\s\-]')),
                LengthLimitingTextInputFormatter(16),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00A650).withValues(alpha: 0.08),
                borderRadius: AppRadius.mdBorder,
                border: Border.all(
                  color: const Color(0xFF00A650).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.info,
                    size: 16,
                    color: Color(0xFF00A650),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You will receive an M-Pesa prompt on your phone to authorise the payment.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF00A650),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // PayPal / Google Pay — simplified (redirect-style)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Icon(
                    PhosphorIconsRegular.arrowSquareOut,
                    size: 36,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _method == _PayMethod.paypal
                        ? 'You will be redirected to PayPal to complete payment securely.'
                        : 'Google Pay will open to confirm payment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ── Pay button ────────────────────────────────────────────────────
          BlocBuilder<PremiumCubit, PremiumState>(
            builder: (context, state) {
              return SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.lgBorder,
                    ),
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(PhosphorIconsRegular.lock, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Pay \$${_planPrice.toStringAsFixed(2)} securely',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Legal
          Text(
            _isLifetime
                ? 'One-time payment, no recurring charges. Instant access.'
                : 'Includes ${AppConstants.trialDays}-day free trial. '
                    'Cancel anytime before billing starts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.55,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Brand row
          const PaymentBrandRow(iconHeight: 26),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay wrapper (bridges GlobalKey into the named state class)
// ─────────────────────────────────────────────────────────────────────────────

class _OverlayWrapper extends StatelessWidget {
  const _OverlayWrapper({
    required this.overlayKey,
    required this.label,
    required this.onDone,
  });
  final GlobalKey<_PaymentProcessingOverlayWrapperState> overlayKey;
  final String label;
  final void Function(bool success) onDone;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: _PaymentProcessingOverlayWrapper(
        key: overlayKey,
        label: label,
        onDone: onDone,
      ),
    );
  }
}

/// Wrapper so we can have a key pointing to this State.
class _PaymentProcessingOverlayWrapper extends StatefulWidget {
  const _PaymentProcessingOverlayWrapper({
    super.key,
    required this.label,
    required this.onDone,
  });

  final String label;
  final void Function(bool success) onDone;

  @override
  _PaymentProcessingOverlayWrapperState createState() =>
      _PaymentProcessingOverlayWrapperState();
}

class _PaymentProcessingOverlayWrapperState
    extends State<_PaymentProcessingOverlayWrapper> {
  final _innerKey = GlobalKey<PaymentProcessingOverlayState>();

  void showResult({required bool success, required String label}) {
    _innerKey.currentState?.showResult(success: success, label: label);
  }

  @override
  Widget build(BuildContext context) {
    return PaymentProcessingOverlay(
      key: _innerKey,
      label: widget.label,
      onDone: widget.onDone,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.planLabel,
    required this.price,
    required this.isLifetime,
  });
  final String planLabel;
  final double price;
  final bool isLifetime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.lgBorder,
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
        ),
        boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: AppRadius.smBorder,
                ),
                child: Icon(
                  Icons.workspace_premium,
                  size: 22,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stone Town Guide — $planLabel',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLifetime
                          ? 'Full access, no expiry'
                          : '${AppConstants.trialDays}-day free trial included',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: scheme.primary.withValues(alpha: 0.18)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total today',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              Text(
                isLifetime
                    ? '\$${price.toStringAsFixed(2)}'
                    : '\$0.00 (trial)',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (!isLifetime) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'After ${AppConstants.trialDays} days',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Payment method selector ───────────────────────────────────────────────────

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({
    required this.selected,
    required this.onChanged,
  });
  final _PayMethod selected;
  final ValueChanged<_PayMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final methods = [
      (_PayMethod.card, 'Card', PhosphorIconsRegular.creditCard),
      (_PayMethod.mpesa, 'M-Pesa', PhosphorIconsRegular.phone),
      (_PayMethod.paypal, 'PayPal', PhosphorIconsRegular.paypalLogo),
      (_PayMethod.googlePay, 'G Pay', PhosphorIconsRegular.googleLogo),
    ];

    return Row(
      children: methods.map((m) {
        final isSelected = m.$1 == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: AppRadius.mdBorder,
                  border: Border.all(
                    color: isSelected
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: 0.4),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      m.$3,
                      size: 22,
                      color: isSelected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.$2,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
      ),
    );
  }
}

// ── Card number field (with brand icon) ───────────────────────────────────────

class _CardNumberField extends StatelessWidget {
  const _CardNumberField({
    required this.controller,
    required this.brand,
    required this.onChanged,
    required this.validator,
  });
  final TextEditingController controller;
  final _CardBrand brand;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String> validator;

  Widget _brandIcon() {
    const size = 28.0;
    switch (brand) {
      case _CardBrand.visa:
        return PaymentMethodIcons.visa(size: size);
      case _CardBrand.mastercard:
        return PaymentMethodIcons.mastercard(size: size);
      case _CardBrand.amex:
        return PaymentMethodIcons.amex(size: size);
      case _CardBrand.unknown:
        return Icon(
          PhosphorIconsRegular.creditCard,
          size: size,
          color: Colors.grey,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]'))],
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(letterSpacing: 2, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Card number',
        hintText: '0000 0000 0000 0000',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: _brandIcon(),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 60,
          minHeight: 48,
        ),
      ),
    );
  }
}

// ── Generic payment field ────────────────────────────────────────────────────

class _PayField extends StatelessWidget {
  const _PayField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    this.maxLength,
    this.obscureText = false,
    this.onChanged,
    this.validator,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final int? maxLength;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }
}
