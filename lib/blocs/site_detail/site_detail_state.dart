import 'package:equatable/equatable.dart';
import '../../data/models/site_model.dart';
import '../../data/models/audio_state.dart';

enum SiteDetailStatus { initial, loading, loaded, error }

class SiteDetailState extends Equatable {
  final SiteDetailStatus status;
  final SiteModel? site;
  final AudioState audioState;
  final bool isFavorited;
  final String? errorMessage;

  const SiteDetailState({
    this.status = SiteDetailStatus.initial,
    this.site,
    this.audioState = const AudioState(),
    this.isFavorited = false,
    this.errorMessage,
  });

  SiteDetailState copyWith({
    SiteDetailStatus? status,
    SiteModel? site,
    AudioState? audioState,
    bool? isFavorited,
    String? errorMessage,
  }) {
    return SiteDetailState(
      status: status ?? this.status,
      site: site ?? this.site,
      audioState: audioState ?? this.audioState,
      isFavorited: isFavorited ?? this.isFavorited,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, site, audioState, isFavorited, errorMessage];
}