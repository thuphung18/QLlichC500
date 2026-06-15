/// Model [ScheduleItem] mô tả một lịch công tác hoặc lịch giảng dạy trong hệ thống.
/// Khi API trả dữ liệu JSON về, ứng dụng sẽ map dữ liệu đó thành đối tượng này để hiển thị lên UI.
class ScheduleItem {
  /// Mã định danh duy nhất của lịch biểu
  final String id;
  
  /// Tiêu đề của lịch biểu
  final String title;
  
  /// Tên giáo viên / Người chủ trì
  final String teacher;
  
  /// Phòng học / Địa điểm
  final String room;
  
  /// Chuỗi hiển thị ngày (VD: "12/06")
  final String dateLabel;
  
  /// Giờ bắt đầu (VD: "07:30")
  final String startTime;
  
  /// Giờ kết thúc (VD: "09:30")
  final String endTime;
  
  /// Buổi diễn ra (Sáng/Chiều/Tối)
  final String session;
  
  /// Ghi chú chi tiết
  final String note;
  
  /// Đơn vị phụ trách
  final String unit;
  
  /// Mã định danh phòng ban
  final String departmentId;
  
  /// Tên phòng ban
  final String departmentName;
  
  /// Thể loại lịch
  final String category;
  
  /// Danh sách tên những người tham gia
  final List<String> participants;
  
  /// Danh sách ID của những người tham gia
  final List<String> participantUserIds;

  /// Đánh dấu xem đây có phải là lịch CỦA CHÍNH MÌNH không (isMine = true)
  /// (Dùng để tô màu hoặc lọc dữ liệu trên UI)
  final bool isMine;
  
  /// Đánh dấu xem đây có phải là lịch CỦA KHOA/PHÒNG BAN mình không (isDepartment = true)
  final bool isDepartment;

  /// Chỉ số ngày trong tuần (2 = Thứ 2, 3 = Thứ 3, ..., 8 = Chủ nhật).
  /// Dùng để phân chia lịch vào đúng cột khi hiển thị theo dạng bảng tuần.
  final int dayIndex;

  const ScheduleItem({
    required this.id,
    required this.title,
    required this.teacher,
    required this.room,
    required this.dateLabel,
    required this.startTime,
    required this.endTime,
    required this.session,
    required this.note,
    required this.unit,
    required this.departmentId,
    required this.departmentName,
    required this.category,
    required this.participants,
    required this.participantUserIds,
    required this.isMine,
    required this.isDepartment,
    required this.dayIndex,
  });

  /// Getter trả về chuỗi hiển thị khoảng thời gian (VD: "07:30 - 09:30")
  String get timeRange => '$startTime - $endTime';

  /// Getter tính toán thời gian bắt đầu của lịch này dưới dạng [DateTime].
  /// Dùng để sắp xếp lịch theo thời gian thực hoặc kiểm tra quá hạn.
  DateTime? get startDateTime {
    try {
      // Dùng Regex để tách ngày và tháng từ chuỗi dateLabel (VD: "12/06")
      final RegExp dateRegex = RegExp(r'(\d{1,2})/(\d{1,2})');
      final match = dateRegex.firstMatch(dateLabel);
      if (match == null) return null;

      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      
      // Tách giờ và phút từ chuỗi startTime (VD: "07:30")
      final timeParts = startTime.split(':');
      if (timeParts.length < 2) return null;
      
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      
      final now = DateTime.now();
      // Tạo đối tượng DateTime. Giả định lấy năm hiện tại (now.year).
      return DateTime(now.year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  /// Kiểm tra xem lịch này ĐÃ KẾT THÚC (quá hạn) so với thời điểm hiện tại hay chưa.
  bool get isPassed {
    try {
      // Tìm mẫu ngày/tháng (ví dụ: 08/06)
      final RegExp dateRegex = RegExp(r'(\d{1,2})/(\d{1,2})');
      final match = dateRegex.firstMatch(dateLabel);
      if (match == null) return false;

      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      
      // Tách giờ và phút từ giờ kết thúc
      final timeParts = endTime.split(':');
      if (timeParts.length < 2) return false;
      
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      
      final now = DateTime.now();
      final scheduleTime = DateTime(now.year, month, day, hour, minute);
      
      // Nếu thời gian hiện tại lớn hơn thời gian kết thúc của lịch thì trả về true
      return now.isAfter(scheduleTime);
    } catch (e) {
      return false;
    }
  }

  /// Factory [fromJson] dùng để parse (phân tích) một Map (JSON) thành object [ScheduleItem].
  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      teacher: json['teacher']?.toString() ?? '',
      room: json['room']?.toString() ?? '',
      dateLabel: json['dateLabel']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      session: json['session']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      departmentId: json['departmentId']?.toString() ?? '',
      departmentName: json['departmentName']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      participants: _toStringList(json['participants']),
      participantUserIds: _toStringList(json['participantUserIds']),
      isMine: json['isMine'] == true,
      isDepartment: json['isDepartment'] == true,
      dayIndex: int.tryParse(json['dayIndex']?.toString() ?? '') ?? 2,
    );
  }

  /// Hàm phụ trợ (helper) chuyển đổi một danh sách dynamic thành List<String> an toàn
  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return [];
  }
}