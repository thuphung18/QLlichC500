/// Lớp [Department] mô phỏng dữ liệu của một phòng ban hoặc khoa.
class Department {
  /// Mã định danh duy nhất của phòng ban (VD: "cntt")
  final String id;
  
  /// Tên đầy đủ của phòng ban (VD: "Khoa Công nghệ thông tin")
  final String name;

  /// Constructor khởi tạo một phòng ban với id và name
  const Department({
    required this.id,
    required this.name,
  });

  /// Hàm Factory [fromJson] để khởi tạo một đối tượng [Department]
  /// từ dữ liệu JSON (dạng Map) do API trả về.
  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
