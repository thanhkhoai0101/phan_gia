import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class CheckAuthRequested extends AuthEvent {}
class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  const LoginRequested(this.email, this.password);
  @override
  List<Object> get props => [email, password];
}
class RegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  const RegisterRequested(this.email, this.password, this.displayName);
  @override
  List<Object> get props => [email, password, displayName];
}
class LogoutRequested extends AuthEvent {}

class UpdateProfileRequested extends AuthEvent {
  final String? displayName;
  final String? avatarUrl;
  final String? coverUrl;

  const UpdateProfileRequested({this.displayName, this.avatarUrl, this.coverUrl});

  @override
  List<Object?> get props => [displayName, avatarUrl, coverUrl];
}
