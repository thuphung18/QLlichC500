import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    final response = await http.get(Uri.parse('http://apiqlcb.6pg.org/api/canbo/getall'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      print("SUCCESS:");
      if (json is List && json.isNotEmpty) {
        print(jsonEncode(json[0]));
      } else if (json is Map && json['data'] != null) {
        print(jsonEncode(json['data'][0]));
      } else {
        print(response.body);
      }
    } else {
      print("FAILED: \${response.statusCode}");
    }
  } catch (e) {
    print("ERROR: \$e");
  }
}
