USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_SubmitOTRegistration]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_SubmitOTRegistration] as select 1')
GO

ALTER PROCEDURE [dbo].[API_SubmitOTRegistration]
    @Identity_ID varchar(100),
    @TargetID int,
    @RegisterBy varchar(50),
    @TypeRegister int,
    @OTDateFrom date,
    @OTDateTo date,
    @Approver1 varchar(50),
    @Approver2 varchar(50),
    @Approver3 varchar(50),
    @Approver4 varchar(50) = null,
    @Remark nvarchar(500),
    @JSONData nvarchar(max),
    @IsDivision int = 0,
    @LanguageID varchar(2) = 'VN'
as
begin
    set nocount on;
    begin try
        declare @CurLevel int = 1;
        declare @Date1 datetime = null, @Rem1 nvarchar(200) = null;
        declare @Date2 datetime = null, @Rem2 nvarchar(200) = null;

        declare @GroupID int = case when @IsDivision = 0 then @TargetID else null end;
        declare @DivisionID int = case when @IsDivision = 1 then @TargetID else null end;

        if @Approver1 = 'SKIP' and @Approver2 = 'SKIP'
        begin
            set @CurLevel = 3;
            set @Date1 = getdate(); set @Rem1 = N'Hệ thống tự động bỏ qua do không có Cấp 1';
            set @Date2 = getdate(); set @Rem2 = N'Hệ thống tự động bỏ qua do không có Cấp 2';
        end
        else if @Approver1 = 'SKIP'
        begin
            set @CurLevel = 2;
            set @Date1 = getdate(); set @Rem1 = N'Hệ thống tự động bỏ qua do không có Cấp 1';
        end

       update tblOTListRegisteredNIVS
        set Approve_Status = 1, Current_Approved_Level = @CurLevel,
            Approver_1 = @Approver1, ApproveDate_1 = @Date1, ApproverRemark_1 = @Rem1,
            Approver_2 = @Approver2, ApproveDate_2 = @Date2, ApproverRemark_2 = @Rem2,
            Approver_3 = @Approver3,
            Approver_4 = @Approver4,
            Remark = @Remark, GroupID = @GroupID, DivisionID = @DivisionID, IsDivision = @IsDivision, RegisterBy = @RegisterBy,
            TypeRegister = @TypeRegister, OTDateFrom = @OTDateFrom, OTDateTo = @OTDateTo, CreateTime = getdate()
        where Identity_ID = @Identity_ID;

        select EmployeeID, OTDate, ShiftID, OTFrom, OTTo, OTHours, IsExceed, CurrentTotalOT, LimitType, TargetID, IsExtraEmp, ConsecutiveDays, WorkedHolidays, IsIndirectEmp
        into #tmpOTData from openjson(@JSONData)
        with (
            EmployeeID varchar(50) '$.EmployeeID', OTDate date '$.OTDate', ShiftID int '$.ShiftID', OTFrom varchar(5) '$.OTFrom', OTTo varchar(5) '$.OTTo',
            OTHours float '$.OTHours', IsExceed int '$.IsExceed', CurrentTotalOT float '$.CurrentTotalOT', LimitType nvarchar(100) '$.LimitType',
            TargetID int '$.TargetID', IsExtraEmp int '$.IsExtraEmp', ConsecutiveDays int '$.ConsecutiveDays', WorkedHolidays int '$.WorkedHolidays', IsIndirectEmp int '$.IsIndirectEmp'
        );

        delete from tblOTListRegisteredNIVS_Detail where Identity_ID = @Identity_ID;

        insert into tblOTListRegisteredNIVS_Detail (Identity_ID, EmployeeID, OTDate, ShiftID, Approve_Status, OTFrom, OTTo, OTHours, GroupID, DivisionID, IsExceed, LimitType, CurrentTotalOT, IsExtraEmp, ConsecutiveDays, WorkedHolidays, IsIndirectEmp)
        select @Identity_ID, EmployeeID, OTDate, ShiftID, 1, OTFrom, OTTo, OTHours,
               case when IsIndirectEmp = 0 then TargetID else null end,
               case when IsIndirectEmp = 1 then TargetID else null end,
               IsExceed, LimitType, CurrentTotalOT, IsExtraEmp, ConsecutiveDays, WorkedHolidays, IsIndirectEmp
        from #tmpOTData
        where OTDate between @OTDateFrom and @OTDateTo;

        declare @GroupName nvarchar(250);
        if @IsDivision = 1
            select @GroupName = DivisionName from tblDivision where DivisionID = @TargetID;
        else
            select @GroupName = GroupTeamName from tblGroupTeam where GroupTeamID = @TargetID;

        declare @TotalEmp int, @TotalHours float;
        select @TotalEmp = count(distinct EmployeeID), @TotalHours = sum(isnull(OTHours, 0))
        from #tmpOTData
        where OTDate between @OTDateFrom and @OTDateTo;

        declare @NextApprover varchar(50);
        if @Approver1 = 'SKIP' and @Approver2 = 'SKIP' set @NextApprover = @Approver3;
        else if @Approver1 = 'SKIP' set @NextApprover = @Approver2;
        else set @NextApprover = @Approver1;

        declare @CurLang varchar(2) = 'VN';
        if isnull(@NextApprover, '') <> '' and @NextApprover <> 'SKIP'
        begin
            select top 1 @CurLang = isnull(nullif(CurLang, ''), 'VN')
            from tblSC_Login
            where LoginID = @NextApprover or EmployeeID = @NextApprover;
        end

        declare @NotifyText nvarchar(max);

        set @NotifyText = case
            when @CurLang = 'EN' then
                N'Planned OT request needs approval:' + char(10) +
                N'Dept: ' + isnull(@GroupName, '') + char(10) +
                N'Date: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                N'Emps: ' + cast(@TotalEmp as varchar) + N' people' + char(10) +
                N'Total OT: ' + cast(cast(@TotalHours as decimal(10,1)) as varchar) + N'h'
            when @CurLang = 'JP' then
                N'計画残業申請の承認待ち:' + char(10) +
                N'部署: ' + isnull(@GroupName, '') + char(10) +
                N'日付: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                N'対象者: ' + cast(@TotalEmp as varchar) + N' 名' + char(10) +
                N'合計残業: ' + cast(cast(@TotalHours as decimal(10,1)) as varchar) + N'h'
            else
                N'Đơn ĐK Tăng ca Kế hoạch cần duyệt:' + char(10) +
                N'Bộ phận: ' + isnull(@GroupName, '') + char(10) +
                N'Ngày: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                N'Nhân viên: ' + cast(@TotalEmp as varchar) + N' người' + char(10) +
                N'Tổng giờ: ' + cast(cast(@TotalHours as decimal(10,1)) as varchar) + N'h'
        end;

        if isnull(@NextApprover, '') <> '' and @NextApprover <> 'SKIP'
        begin
            insert into tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
            values ('Nivs_App_Notify', 0, 1, @Identity_ID, @NextApprover, 1, @NotifyText);
        end

        update Taskschedule set LastTryDay = '20190101', NextRunDate = '20190101' where FunctionName = 'SendPendingEmail'

        drop table #tmpOTData;

        select 'success' as result, '' as reason;
    end try
    begin catch
        select 'error' as result, error_message() as reason;
    end catch
end
GO