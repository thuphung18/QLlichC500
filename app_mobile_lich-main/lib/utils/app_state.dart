import 'package:flutter/foundation.dart';

class AppState {
  static final AppState _instance = AppState._internal();
  
  factory AppState() {
    return _instance;
  }
  
  AppState._internal() {
    final now = DateTime.now();
    final index = now.weekday + 1; // DateTime.monday = 1 -> Thứ 2 là 2
    selectedDayNotifier = ValueNotifier<int>(index > 8 ? 8 : index); 
  }

  late final ValueNotifier<int> selectedDayNotifier;
}
