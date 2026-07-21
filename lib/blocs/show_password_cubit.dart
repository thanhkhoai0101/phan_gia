import 'package:bloc/bloc.dart';

class ShowPasswordCubit extends Cubit<bool> {
  ShowPasswordCubit() : super(true);

  void toggle() {
    emit(!state);
  }
}
