import 'dart:async';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  
  factory EventBus() {
    return _instance;
  }
  
  EventBus._internal();

  final _scheduleDeletedController = StreamController<String>.broadcast();

  Stream<String> get onScheduleDeleted => _scheduleDeletedController.stream;

  void fireScheduleDeleted(String scheduleId) {
    _scheduleDeletedController.add(scheduleId);
  }
}
