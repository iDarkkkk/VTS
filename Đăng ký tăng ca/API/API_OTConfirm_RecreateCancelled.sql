use Paradise_NIVS_Cloud
go
if object_id('[dbo].[API_OTConfirm_RecreateCancelled]') is null
    exec ('create procedure [dbo].[API_OTConfirm_RecreateCancelled] as select 1')
go

alter procedure [dbo].[API_OTConfirm_RecreateCancelled]
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
        from tblOTActualMasterNIVS
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

        if not exists (select 1 from tblOTActualDetailNIVS where cast(Identity_ID as varchar(100)) = @SourceIdentity_ID)
        begin
            select 'error' as result, N'Đơn hiện tại không có dữ liệu chi tiết để khởi tạo lại.' as reason;
            return;
        end

        begin tran;

        insert into tblOTActualMasterNIVS (
            Identity_ID, GroupID, DivisionID, IsDivision, OTDate, RegisterBy, Approve_Status, CreateTime, TypeRegister, Plan_Identity_ID,
            Current_Approved_Level, Approver_1, Approver_2, Approver_3, Approver_4, Approver_5, Remark
        )
        select @NewIdentity_ID, GroupID, DivisionID, isnull(IsDivision, 0), OTDate, @LoginID, 0, getdate(), TypeRegister, Plan_Identity_ID,
            1, Approver_1, Approver_2, Approver_3, Approver_4, Approver_5, Remark
        from tblOTActualMasterNIVS
        where cast(Identity_ID as varchar(100)) = @SourceIdentity_ID;

        insert into tblOTActualDetailNIVS (
            Identity_ID, EmployeeID, OTDate, Planned_OTFrom, Planned_OTTo, Actual_OTFrom, Actual_OTTo,
            Actual_OTHours, Approve_Status, ShiftID, DivisionID, IsIndirectEmp
        )
        select @NewIdentity_ID, EmployeeID, OTDate, Planned_OTFrom, Planned_OTTo, Actual_OTFrom, Actual_OTTo,
            Actual_OTHours, 0, ShiftID, DivisionID, isnull(IsIndirectEmp, 0)
        from tblOTActualDetailNIVS
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
