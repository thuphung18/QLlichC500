USE weekly_schedule_db;
GO

UPDATE dbo.users SET full_name = N'Nguyễn Văn Hoàng' WHERE id = 'u005';
UPDATE dbo.users SET full_name = N'Trần Phương Linh' WHERE id = 'u006';

UPDATE dbo.schedules SET title = N'Học môn Cơ sở dữ liệu', teacher = N'GV. Thành', note = N'Chuẩn bị bài tập lớn' WHERE id = '12';
UPDATE dbo.schedules SET title = N'Họp bộ môn Kinh tế học', teacher = N'Trưởng bộ môn', note = N'Thống nhất chương trình giảng dạy' WHERE id = '13';

UPDATE dbo.schedule_participants SET participant_name = N'Hoàng' WHERE schedule_id = '12' AND user_id = 'u005';
UPDATE dbo.schedule_participants SET participant_name = N'Linh' WHERE schedule_id = '13' AND user_id = 'u006';
GO
