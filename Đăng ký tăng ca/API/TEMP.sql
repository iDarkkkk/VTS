--tên cột
MessageID	Language	Content
Visible	CN	顯示
Visible	EN	Visible
Visible	VN	Hiển thị
--bảng
select * from tblMD_Message
insert into tblMD_Message(MessageID,Language,Content,Frequency,IgnorePending)
select MessageID,Language,Content,Frequency,IgnorePending
select @MessageID,@Language,@Content,@Frequency,@IgnorePending

insert into tblMD_Message(MessageID,Language,Content) values
('RecreateLoadingTitle_OTConfirm','VN',N'Đang khởi tạo đơn...'),
('RecreateLoadingTitle_OTConfirm','EN',N'Initializing form...'),
('RecreateLoadingSubtitle_OTConfirm','VN',N'Đang đồng bộ dữ liệu và cấp duyệt'),
('RecreateLoadingSubtitle_OTConfirm','EN',N'Syncing data and approval levels'),
('RecreateButton_OTConfirm','VN',N'Khởi tạo lại'),
('RecreateButton_OTConfirm','EN',N'Recreate'),
('RecreatedDraftSuccess_OTConfirm','VN',N'Đã khởi tạo lại đơn nháp mới.'),
('RecreatedDraftSuccess_OTConfirm','EN',N'Recreated a new draft form.'),
('RecreateConfirmTitle_OTConfirm','VN',N'Khởi tạo lại đơn'),
('RecreateConfirmTitle_OTConfirm','EN',N'Recreate form'),
('RecreateConfirmMessage_OTConfirm','VN',N'Hệ thống sẽ tạo một đơn nháp mới với nội dung giống đơn hiện tại. Đơn cũ vẫn được giữ nguyên.'),
('RecreateConfirmMessage_OTConfirm','EN',N'The system will create a new draft form with the same content as the current form. The old form will remain unchanged.'),
('Creating_OTConfirm','VN',N'Đang tạo...'),
('Creating_OTConfirm','EN',N'Creating...'),
('Level5_OTConfirm','VN',N'Cấp 5'),
('Level5_OTConfirm','EN',N'Level 5'),
('CancelApprovedText_OTConfirm','VN',N'Đã duyệt Hủy'),
('CancelApprovedText_OTConfirm','EN',N'Cancel approved'),
('ApprovedText_OTConfirm','VN',N'Đã duyệt'),
('ApprovedText_OTConfirm','EN',N'Approved'),
('RejectedText_OTConfirm','VN',N'Từ chối'),
('RejectedText_OTConfirm','EN',N'Rejected'),
('WaitingCancelApproveText_OTConfirm','VN',N'Đợi duyệt Hủy...'),
('WaitingCancelApproveText_OTConfirm','EN',N'Waiting for cancel approval...'),
('WaitingText_OTConfirm','VN',N'Đang chờ...'),
('WaitingText_OTConfirm','EN',N'Waiting...'),
('PendingApprovalText_OTConfirm','VN',N'Đợi duyệt'),
('PendingApprovalText_OTConfirm','EN',N'Pending approval'),
('RequireLevel1Actual_OTConfirm','VN',N'Vui lòng chọn Cấp 1 (Hoặc Bỏ qua)!'),
('RequireLevel1Actual_OTConfirm','EN',N'Please select Level 1 (or Skip)!'),
('RequireLevel2Actual_OTConfirm','VN',N'Vui lòng chọn Duyệt Cấp 2!'),
('RequireLevel2Actual_OTConfirm','EN',N'Please select Level 2 approver!'),
('RequireLevel3WhenSkip12_OTConfirm','VN',N'Phải chọn người duyệt Cấp 3 khi bỏ qua Cấp 1 và Cấp 2!'),
('RequireLevel3WhenSkip12_OTConfirm','EN',N'Level 3 approver is required when Level 1 and Level 2 are skipped!'),
('LastLevelCannotSkip_OTConfirm','VN',N'Cấp duyệt cuối cùng không được phép chọn Khác!'),
('LastLevelCannotSkip_OTConfirm','EN',N'The final approval level cannot be Other!'),
('RequireNormalLevel4_OTConfirm','VN',N'Tăng ca ngày thường cần thiết lập đến Cấp 4!'),
('RequireNormalLevel4_OTConfirm','EN',N'Normal day overtime requires approval up to Level 4!'),
('RequireHolidayLevel5_OTConfirm','VN',N'Tăng ca Lễ cần thiết lập đến Cấp 5!'),
('RequireHolidayLevel5_OTConfirm','EN',N'Holiday overtime requires approval up to Level 5!'),
('HasUnapprovedOverLimitEmp_OTConfirm','VN',N'Có nhân viên Vượt định mức chưa duyệt. Chờ duyệt xong mới gửi được.'),
('HasUnapprovedOverLimitEmp_OTConfirm','EN',N'There are employees with unapproved over-limit overtime. Please wait until approval is completed before submitting.'),
('EmptyOrZeroHourActual_OTConfirm','VN',N'Đơn rỗng hoặc tổng giờ = 0!'),
('EmptyOrZeroHourActual_OTConfirm','EN',N'The form is empty or total hours = 0!'),
('RequireDetailRemark_OTConfirm','VN',N'Vui lòng nhập Ghi chú chi tiết!'),
('RequireDetailRemark_OTConfirm','EN',N'Please enter detailed remarks!'),
('ConfirmSubmitActualMessage_OTConfirm','VN',N'Xác nhận gửi Đơn Thực Tế? Dữ liệu sẽ không thể sửa sau khi gửi.'),
('ConfirmSubmitActualMessage_OTConfirm','EN',N'Confirm submitting the actual overtime form? Data cannot be edited after submission.'),
('ConfirmSubmitActualWarningMessage_OTConfirm','VN',N'<b class="text-danger">Có {0} NV bị Cảnh báo.</b><br><br>Xác nhận vẫn gửi đi?'),
('ConfirmSubmitActualWarningMessage_OTConfirm','EN',N'<b class="text-danger">There are {0} employees with warnings.</b><br><br>Confirm submission anyway?'),
('ConfirmSubmitActualTitle_OTConfirm','VN',N'Xác nhận Gửi Duyệt'),
('ConfirmSubmitActualTitle_OTConfirm','EN',N'Confirm submission'),
('Submitting_OTConfirm','VN',N'Đang gửi...'),
('Submitting_OTConfirm','EN',N'Submitting...'),
('Success_OTConfirm','VN',N'Thành công!'),
('Success_OTConfirm','EN',N'Success!'),
('ErrorPrefix_OTConfirm','VN',N'Lỗi:'),
('ErrorPrefix_OTConfirm','EN',N'Error:'),
('NoDataByFilter_OTConfirm','VN',N'Không có dữ liệu phù hợp với bộ lọc.'),
('NoDataByFilter_OTConfirm','EN',N'No data matches the filter.');

insert into tblMD_Message(MessageID,Language,Content) values
('FeedbackPlaceholder_ExceedOT','VN',N'Nhập ý kiến phản hồi...'),
('FeedbackPlaceholder_ExceedOT','EN',N'Enter feedback...'),
('RequireLevel3WhenSkip12_ExceedOT','VN',N'Phải chọn người duyệt Cấp 3 khi bỏ qua Cấp 1 và 2!'),
('RequireLevel3WhenSkip12_ExceedOT','EN',N'Level 3 approver is required when Level 1 and 2 are skipped!'),
('LastLevelCannotSkip_ExceedOT','VN',N'Cấp duyệt cuối không được phép chọn Khác!'),
('LastLevelCannotSkip_ExceedOT','EN',N'The final approval level cannot be Other!');
