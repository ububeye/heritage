import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/shared_prefs_service.dart';

class PremiumCubit extends Cubit<PremiumState> {
  PremiumCubit() : super(const PremiumState());

  /// Hydrate from SharedPreferences so the demo premium status survives
  /// an app restart. Real billing integration would replace this with
  /// a server-side check (RevenueCat / Cloud Function).
  Future<void> checkPremiumStatus() async {
    final prefs = SharedPrefsService.instance;
    emit(state.copyWith(
      showPremiumOffer: prefs.showPremiumOffer,
      isPremium: prefs.isPremiumDemo,
    ));
  }

  Future<void> subscribe() async {
    emit(state.copyWith(isLoading: true));
    await Future.delayed(const Duration(seconds: 1));
    await SharedPrefsService.instance.setPremiumDemo(true);
    await SharedPrefsService.instance.setShowPremiumOffer(false);
    emit(state.copyWith(
      isLoading: false,
      isPremium: true,
      showPremiumOffer: false,
    ));
  }

  Future<void> skipPremiumOffer() async {
    await SharedPrefsService.instance.setShowPremiumOffer(false);
    emit(state.copyWith(showPremiumOffer: false));
  }

  Future<void> setPremium(bool isPremium) async {
    await SharedPrefsService.instance.setPremiumDemo(isPremium);
    emit(state.copyWith(isPremium: isPremium));
  }
}

class PremiumState {
  final bool isPremium;
  final bool isLoading;
  final bool showPremiumOffer;

  const PremiumState({
    this.isPremium = false,
    this.isLoading = false,
    this.showPremiumOffer = true,
  });

  PremiumState copyWith({
    bool? isPremium,
    bool? isLoading,
    bool? showPremiumOffer,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      showPremiumOffer: showPremiumOffer ?? this.showPremiumOffer,
    );
  }
}