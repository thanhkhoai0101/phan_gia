import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'auth_event.dart';
import 'auth_state.dart';
import '../services/auth_service.dart';
import '../../../core/models/user_model.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;
  late StreamSubscription<UserModel?> _authSubscription;

  AuthBloc({required this.authService}) : super(AuthInitial()) {
    on<CheckAuthRequested>(_onCheckAuthRequested);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    
    on<_AuthUserChanged>((event, emit) => emit(AuthAuthenticated(event.user)));
    on<_AuthUserLoggedOut>((event, emit) => emit(AuthUnauthenticated()));

    _authSubscription = authService.authStateChanges().listen((userModel) {
      if (userModel != null) {
        add(_AuthUserChanged(userModel));
      } else {
        add(_AuthUserLoggedOut());
      }
    });
  }

  void _onCheckAuthRequested(CheckAuthRequested event, Emitter<AuthState> emit) {
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    String? error = await authService.login(event.email, event.password);
    if (error != null) {
      emit(AuthError(error));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRegisterRequested(RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    String? error = await authService.register(event.email, event.password, event.displayName);
    if (error != null) {
      emit(AuthError(error));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await authService.logout();
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }
}

class _AuthUserChanged extends AuthEvent {
  final UserModel user;
  const _AuthUserChanged(this.user);
  @override
  List<Object> get props => [user];
}

class _AuthUserLoggedOut extends AuthEvent {}
