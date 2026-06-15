import '../models/schedule_item.dart';
import '../models/user_profile.dart';
import '../models/create_schedule_request.dart';
import '../models/form_data_response.dart';
import '../repositories/schedule_repository.dart';

// DemoScheduleRepository là nguồn dữ liệu lịch giả.
// Sau này bạn thay bằng ApiScheduleRepository để lấy dữ liệu từ backend/SQL Server.
class DemoScheduleRepository implements ScheduleRepository {
  static const UserProfile demoUser = UserProfile(
    id: 'u001',
    fullName: 'Thành',
    username: 'thanh',
    role: 'Giảng viên',
    unit: 'Khoa Công nghệ thông tin',
    departmentId: 'cntt',
    departmentName: 'Khoa Công nghệ thông tin',
    email: 'thanh@academy.edu.vn',
    phone: '0123 456 789',
  );

  @override
  final UserProfile currentUser;

  DemoScheduleRepository({
    UserProfile? currentUser,
  }) : currentUser = currentUser ?? demoUser;

  final List<ScheduleItem> _items = [
    const ScheduleItem(
      id: '1',
      title: 'Đi dự khai mạc triển khai đợt 1 xây dựng ngân hàng câu hỏi thi',
      teacher: 'Thành',
      room: 'Thái Nguyên',
      dateLabel: 'Thứ 2, 08/6',
      startTime: '06:30',
      endTime: '09:00',
      session: 'morning',
      note: 'Chuẩn bị tài liệu, danh sách câu hỏi và báo cáo tiến độ.',
      unit: 'QLĐT',
      departmentId: 'cntt',
      departmentName: 'Khoa Công nghệ thông tin',
      category: 'Vai trò: Có tên trong thành phần dự',
      participants: ['Thành', 'Thủy', 'Duy'],
      participantUserIds: ['u001', 'u002', 'u003'],
      isMine: true,
      isDepartment: true,
      dayIndex: 2,
    ),
    ScheduleItem(
      id: '2',
      title: 'Họp Hội đồng thi đua khen thưởng khối học viên xét thi',
      teacher: 'Phòng QLĐT',
      room: 'Phòng họp A1',
      dateLabel: 'Thứ 2, 08/6',
      startTime: '14:00',
      endTime: '16:00',
      session: 'afternoon',
      note: 'Họp xét thi đua và thống nhất danh sách đề xuất khen thưởng.',
      unit: 'QLĐT',
      departmentId: 'cntt',
      departmentName: 'Khoa Công nghệ thông tin',
      category: 'Vai trò: Theo dõi và phối hợp',
      participants: ['QLĐT', 'Khoa CNTT'],
      participantUserIds: ['u010', 'u001'],
      isMine: false,
      isDepartment: true,
      dayIndex: 2,
    ),
    ScheduleItem(
      id: '3',
      title: 'Giảng dạy môn Lập trình Mobile',
      teacher: 'Thành',
      room: 'Phòng 305',
      dateLabel: 'Thứ 3, 09/6',
      startTime: '07:30',
      endTime: '09:30',
      session: 'morning',
      note: 'Nội dung: Widget, Scaffold, tách file và tổ chức giao diện Flutter.',
      unit: 'Khoa CNTT',
      departmentId: 'cntt',
      departmentName: 'Khoa Công nghệ thông tin',
      category: 'Lịch giảng dạy',
      participants: ['Lớp CNTT K18'],
      participantUserIds: ['u001'],
      isMine: true,
      isDepartment: true,
      dayIndex: 3,
    ),
    ScheduleItem(
      id: '4',
      title: 'Sinh hoạt chuyên môn khoa Công nghệ thông tin',
      teacher: 'Trưởng khoa',
      room: 'Phòng họp khoa',
      dateLabel: 'Thứ 3, 09/6',
      startTime: '14:00',
      endTime: '15:30',
      session: 'afternoon',
      note: 'Trao đổi kế hoạch giảng dạy, nghiên cứu khoa học và phân công nhiệm vụ tuần.',
      unit: 'Khoa CNTT',
      departmentId: 'cntt',
      departmentName: 'Khoa Công nghệ thông tin',
      category: 'Lịch của khoa',
      participants: ['Toàn bộ giảng viên khoa'],
      participantUserIds: ['u001', 'u002', 'u003', 'u004'],
      isMine: false,
      isDepartment: true,
      dayIndex: 3,
    ),
    ScheduleItem(
      id: '5',
      title: 'Chấm bài kiểm tra giữa kỳ môn Cơ sở dữ liệu',
      teacher: 'Thành',
      room: 'Phòng làm việc',
      dateLabel: 'Thứ 4, 10/6',
      startTime: '08:00',
      endTime: '10:30',
      session: 'morning',
      note: 'Hoàn thiện điểm và nhập kết quả lên hệ thống.',
      unit: 'Khoa CNTT',
      departmentId: 'cntt',
      departmentName: 'Khoa Công nghệ thông tin',
      category: 'Công việc cá nhân',
      participants: ['Thành'],
      participantUserIds: ['u001'],
      isMine: true,
      isDepartment: false,
      dayIndex: 4,
    ),
    ScheduleItem(
      id: '6',
      title: 'Họp xây dựng kế hoạch tuyển sinh ngành Công nghệ thông tin',
      teacher: 'Ban tuyển sinh',
      room: 'Hội trường B',
      dateLabel: 'Thứ 4, 10/6',
      startTime: '15:00',
      endTime: '17:00',
      session: 'afternoon',
      note: 'Thảo luận nội dung truyền thông, chỉ tiêu và kế hoạch tư vấn tuyển sinh.',
      unit: 'Phòng Đào tạo',
      departmentId: 'cntt',
      departmentName: 'Khoa Công nghệ thông tin',
      category: 'Lịch của khoa',
      participants: ['Ban chủ nhiệm khoa', 'Giảng viên phụ trách'],
      participantUserIds: ['u001', 'u002'],
      isMine: false,
      isDepartment: true,
      dayIndex: 4,
    ),
    ScheduleItem(
      id: '7',
      title: 'Giảng dạy môn Phân tích thiết kế hệ thống thông tin',
      teacher: 'Thành',
      room: 'Phòng 402',
      dateLabel: 'Thứ 5, 11/6',
      startTime: '07:30',
      endTime: '10:00',
      session: 'morning',
      note: 'Nội dung: biểu đồ phân rã chức năng, biểu đồ đối tượng và chuyển đổi mô hình.',
      unit: 'Khoa CNTT',
      departmentId: 'cntt',
      departmentName: 'Khoa Công nghệ thông tin',
      category: 'Lịch giảng dạy',
      participants: ['Lớp CNTT K17'],
      participantUserIds: ['u001'],
      isMine: true,
      isDepartment: true,
      dayIndex: 5,
    ),
    ScheduleItem(
      id: '8',
      title: 'Tập huấn sử dụng hệ thống quản lý lịch công tác',
      teacher: 'Phòng CNTT',
      room: 'Phòng máy 2',
      dateLabel: 'Thứ 5, 11/6',
      startTime: '14:00',
      endTime: '16:30',
      session: 'afternoon',
      note: 'Hướng dẫn cập nhật, tra cứu và đồng bộ lịch công tác trên hệ thống mới.',
      unit: 'Phòng CNTT',
      departmentId: 'cntt',
      departmentName: 'Khoa Công nghệ thông tin',
      category: 'Lịch của khoa',
      participants: ['Giảng viên khoa CNTT'],
      participantUserIds: ['u001', 'u002', 'u003'],
      isMine: false,
      isDepartment: true,
      dayIndex: 5,
    ),
    ScheduleItem(
      id: '9',
      title: 'Tư vấn đồ án tốt nghiệp cho sinh viên',
      teacher: 'Thành',
      room: 'Phòng 305',
      dateLabel: 'Thứ 6, 12/6',
      startTime: '09:00',
      endTime: '11:00',
      session: 'morning',
      note: 'Góp ý đề tài app lịch công tác tuần và hướng dẫn kết nối API.',
      unit: 'Khoa CNTT',
      departmentId: 'cntt',
      departmentName: 'Khoa Công nghệ thông tin',
      category: 'Hướng dẫn sinh viên',
      participants: ['Nhóm đồ án 01'],
      participantUserIds: ['u001'],
      isMine: true,
      isDepartment: false,
      dayIndex: 6,
    ),
    ScheduleItem(
      id: '10',
      title: 'Tổng kết công tác tuần của khoa',
      teacher: 'Trưởng khoa',
      room: 'Phòng họp khoa',
      dateLabel: 'Thứ 6, 12/6',
      startTime: '15:30',
      endTime: '17:00',
      session: 'afternoon',
      note: 'Tổng hợp công việc đã hoàn thành và giao nhiệm vụ cho tuần tiếp theo.',
      unit: 'Khoa CNTT',
      departmentId: 'cntt',
      departmentName: 'Khoa Công nghệ thông tin',
      category: 'Lịch của khoa',
      participants: ['Ban chủ nhiệm khoa', 'Trợ lý khoa'],
      participantUserIds: ['u001', 'u002'],
      isMine: false,
      isDepartment: true,
      dayIndex: 6,
    ),
    ScheduleItem(
      id: '11',
      title: 'Bảo trì hệ thống máy chủ lịch công tác',
      teacher: 'Quản trị hệ thống',
      room: 'Phòng máy chủ',
      dateLabel: 'Thứ 2, 08/6',
      startTime: '09:00',
      endTime: '10:00',
      session: 'morning',
      note: 'Lịch mẫu dành cho tài khoản admin thuộc Phòng Công nghệ thông tin.',
      unit: 'Phòng Công nghệ thông tin',
      departmentId: 'phong_cntt',
      departmentName: 'Phòng Công nghệ thông tin',
      category: 'Lịch kỹ thuật',
      participants: ['Quản trị hệ thống'],
      participantUserIds: ['admin001'],
      isMine: true,
      isDepartment: true,
      dayIndex: 2,
    ),
  ];

  @override
  Future<List<ScheduleItem>> getAllSchedules() async {
    return _items.where(_isVisibleForCurrentUser).toList();
  }

  @override
  Future<List<ScheduleItem>> getSchedulesByDay(int dayIndex) async {
    return (await getAllSchedules())
        .where((item) => item.dayIndex == dayIndex)
        .toList();
  }

  @override
  Future<List<ScheduleItem>> getMySchedules() async {
    return _items.where(_isMineForCurrentUser).toList();
  }

  @override
  Future<List<ScheduleItem>> getDepartmentSchedules() async {
    return _items
        .where((item) => item.departmentId == currentUser.departmentId)
        .toList();
  }

  @override
  Future<List<ScheduleItem>> searchSchedules(String keyword) async {
    final key = keyword.trim().toLowerCase();

    final source = await getAllSchedules();

    if (key.isEmpty) {
      return source;
    }

    return source.where((item) {
      final text = [
        item.title,
        item.teacher,
        item.room,
        item.dateLabel,
        item.note,
        item.unit,
        item.departmentName,
        item.category,
        item.participants.join(' '),
      ].join(' ').toLowerCase();

      return text.contains(key);
    }).toList();
  }

  @override
  Future<FormDataResponse> getFormData() async {
    throw UnimplementedError('Not implemented for demo');
  }

  @override
  Future<bool> createSchedule(CreateScheduleRequest request) async {
    throw UnimplementedError('Not implemented for demo');
  }

  @override
  Future<bool> deleteSchedule(String scheduleId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _items.indexWhere((item) => item.id == scheduleId);
    if (index != -1) {
      _items.removeAt(index);
      return true;
    }
    return false;
  }

  bool _isVisibleForCurrentUser(ScheduleItem item) {
    return item.departmentId == currentUser.departmentId ||
        item.participantUserIds.contains(currentUser.id);
  }

  bool _isMineForCurrentUser(ScheduleItem item) {
    return item.participantUserIds.contains(currentUser.id);
  }
}
