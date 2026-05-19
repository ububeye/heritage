import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/shared_prefs_service.dart';

class PremiumCubit extends Cubit<PremiumState> {
  PremiumCubit() : super(const PremiumState());

  Future<void> checkPremiumStatus() async {
    final showOffer = SharedPrefsService.instance.showPremiumOffer;
    emit(state.copyWith(showPremiumOffer: showOffer));
  }

  Future<void> subscribe() async {
    emit(state.copyWith(isLoading: true));
    await Future.delayed(const Duration(seconds: 1));
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

  void setPremium(bool isPremium) {
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