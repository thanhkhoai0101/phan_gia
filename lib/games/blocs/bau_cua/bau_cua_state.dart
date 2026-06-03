import 'package:equatable/equatable.dart';

import '../../models/bau_cua_model.dart';

class BauCuaState extends Equatable {
  final BauCuaRoom? room;
  final bool isLoading;
  final String? error;

  const BauCuaState({this.room, this.isLoading = false, this.error});

  @override
  List<Object?> get props => [room, isLoading, error];

  BauCuaState copyWith({BauCuaRoom? room, bool? isLoading, String? error}) {
    return BauCuaState(
      room: room ?? this.room,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
