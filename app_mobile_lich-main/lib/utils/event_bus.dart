import 'dart:async';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  
  factory EventBus() {
    return _instance;
  }
  
  EventBus._internal();

  // Event khi một lịch bị xóa (truyền scheduleId)
  final _scheduleDeletedController = StreamController<String>.broadcast();
  Stream<String> get onScheduleDeleted => _scheduleDeletedController.stream;
  void fireScheduleDeleted(String scheduleId) {
    _scheduleDeletedController.add(scheduleId);
    // Đồng thời phát luôn event refresh chung
    _schedulesChangedController.add('deleted');
  }

  // Event chung: khi lịch thay đổi (tạo mới, import, xóa, sửa)
  // Tất cả màn hình lắng nghe event này để tự động refresh
  final _schedulesChangedController = StreamController<String>.broadcast();
  Stream<String> get onSchedulesChanged => _schedulesChangedController.stream;
  void fireSchedulesChanged([String reason = 'updated']) {
    _schedulesChangedController.add(reason);
  }
}
