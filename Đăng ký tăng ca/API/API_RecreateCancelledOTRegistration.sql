use Paradise_NIVS_Cloud
go
if object_id('[dbo].[API_RecreateCancelledOTRegistration]') is null
    exec ('create procedure [dbo].[API_RecreateCancelledOTRegistration] as select 1')
go

alter procedure [dbo].[API_RecreateCancelledOTRegistration]
    @SourceIdentity_ID varchar(100),
    @LoginID varchar(50)
as
begin
    set nocount on;

    begin try
        declare @NewIdentity_ID varchar(100) = cast(newid() as varchar(100));
        declare @Status int;

        set @SourceIdentity_ID = ltrim(rtrim(@SourceIdentity_ID));

        select @Status = Approve_Status
        from tblOTListRegisteredNIVS
        where cast(Identity_ID as varchar(100)) = @SourceIdentity_ID;

        if @Status is null
        begin
            select 'error' as result, N'Không tìm thấy đơn cần khởi tạo lại.' as reason;
            return;
        end

        if @Status not in (3, 4)
        begin
            select 'error' as result, N'Chỉ được khởi tạo lại đơn đã bị từ chối hoặc đã hủy thành công.' as reason;
            return;
        end

        if not exists (select 1 from tblOTListRegisteredNIVS_Detail where cast(Identity_ID as varchar(100)) = @SourceIdentity_ID)
        begin
            select 'error' as result, N'Đơn hiện tại không có dữ liệu chi tiết để khởi tạo lại.' as reason;
            return;
        end

        begin tran;

        insert into tblOTListRegisteredNIVS (
            Identity_ID, GroupID, DivisionID, RegisterBy, OTDateFrom, OTDateTo, Approve_Status, TypeRegister, CreateTime, Current_Approved_Level, IsDivision,
            Approver_1, Approver_2, Approver_3, Approver_4, Remark
        )
        select @NewIdentity_ID, GroupID, DivisionID, @LoginID, OTDateFrom, OTDateTo, 0, TypeRegister, getdate(), 1, isnull(IsDivision, 0),
            Approver_1, Approver_2, Approver_3, Approver_4, Remark
        from tblOTListRegisteredNIVS
        where cast(Identity_ID as varchar(100)) = @SourceIdentity_ID;

        insert into tblOTListRegisteredNIVS_Detail (
            Identity_ID, EmployeeID, OTDate, ShiftID, Approve_Status, OTFrom, OTTo, OTHours, GroupID, DivisionID, IsExceed, LimitType, CurrentTotalOT,
            IsExtraEmp, ConsecutiveDays, WorkedHolidays, IsIndirectEmp
        )
        select @NewIdentity_ID, EmployeeID, OTDate, ShiftID, 0, OTFrom, OTTo, OTHours, GroupID, DivisionID, IsExceed, LimitType, CurrentTotalOT,
            isnull(IsExtraEmp, 0), isnull(ConsecutiveDays, 0), isnull(WorkedHolidays, 0), isnull(IsIndirectEmp, 0)
        from tblOTListRegisteredNIVS_Detail
        where cast(Identity_ID as varchar(100)) = @SourceIdentity_ID;

        commit tran;

        select 'success' as result, '' as reason, @NewIdentity_ID as NewIdentity_ID;
        select @NewIdentity_ID as NewIdentity_ID;
    end try
    begin catch
        if @@trancount > 0 rollback tran;
        select 'error' as result, error_message() as reason;
    end catch
end
go
