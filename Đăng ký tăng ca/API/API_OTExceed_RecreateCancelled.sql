use Paradise_NIVS_Cloud
go
if object_id('[dbo].[API_OTExceed_RecreateCancelled]') is null
    exec ('create procedure [dbo].[API_OTExceed_RecreateCancelled] as select 1')
go

alter procedure [dbo].[API_OTExceed_RecreateCancelled]
    @Identity_ID varchar(100),
    @LoginID varchar(50),
    @LanguageID varchar(2) = 'VN'
as
begin
    set nocount on;

    begin try
        begin transaction;

        declare @OldStatus int, @NewID varchar(100) = convert(varchar(100), newid());

        select @OldStatus = Approve_Status
        from tblOTExceedMasterNIVS
        where Identity_ID = @Identity_ID;

        if @OldStatus is null
        begin
            rollback transaction;
            select 'error' as result, N'Không tìm thấy đơn cần khởi tạo lại.' as reason;
            return;
        end

        if @OldStatus not in (3, 4)
        begin
            rollback transaction;
            select 'error' as result, N'Chỉ được khởi tạo lại đơn đã hủy hoặc bị từ chối.' as reason;
            return;
        end

        insert into tblOTExceedMasterNIVS (Identity_ID, GroupID, DivisionID, IsDivision, OTDate, RegisterBy, CreateTime, Approve_Status, Current_Approved_Level, TypeRegister, Approver_1, Approver_2, Approver_3, Approver_4, Remark)
        select @NewID, GroupID, DivisionID, IsDivision, OTDate, @LoginID, getdate(), 0, 1, TypeRegister, Approver_1, Approver_2, Approver_3, Approver_4, Remark
        from tblOTExceedMasterNIVS
        where Identity_ID = @Identity_ID;

        insert into tblOTExceedDetailNIVS (Identity_ID, EmployeeID, LimitType, CurrentTotalOT, PlannedOT_Hours, ApprovedOT_Hours, Approve_Status, IsIndirectEmp, DivisionID)
        select @NewID, EmployeeID, LimitType, CurrentTotalOT, PlannedOT_Hours, ApprovedOT_Hours, 0, IsIndirectEmp, DivisionID
        from tblOTExceedDetailNIVS
        where Identity_ID = @Identity_ID;

        commit transaction;
        select 'success' as result, @NewID as NewIdentity_ID, N'Khởi tạo lại đơn thành công.' as reason;
    end try
    begin catch
        if @@trancount > 0 rollback transaction;
        select 'error' as result, error_message() as reason;
    end catch
end
go
