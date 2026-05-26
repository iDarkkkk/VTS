
if object_id('[dbo].[API_Approve_Action]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_Approve_Action] as select 1')
GO

ALTER PROCEDURE [dbo].[API_Approve_Action]
    @Identity_ID varchar(100),
    @LoginID varchar(50),
    @Action varchar(20),
    @Remark nvarchar(500),
    @ModifiedJSON nvarchar(max) = null
as
begin
    set nocount on;
    begin try

        set @Identity_ID = ltrim(rtrim(@Identity_ID));
        set @LoginID = ltrim(rtrim(@LoginID));
        set @Action = upper(ltrim(rtrim(@Action)));

        declare @ActualEmployeeID varchar(50);
        select top 1 @ActualEmployeeID = ltrim(rtrim(EmployeeID))
        from tblSC_Login
        where LoginName = @LoginID or cast(LoginID as varchar(50)) = @LoginID;

        if @ActualEmployeeID is null
        begin
            select 'error' as result, N'Lỗi hệ thống: Không tìm thấy Mã Nhân Viên!' as reason; return;
        end

        declare @CurrentLevel int, @TypeReg int, @Status int;
        declare @App1 varchar(50), @App2 varchar(50), @App3 varchar(50), @App4 varchar(50);
        declare @RegisterBy varchar(50), @GroupID int, @IsDivision int, @OTDateFrom date, @OTDateTo date;
        set @CurrentLevel = -1;

        select
            @CurrentLevel = isnull(Current_Approved_Level, 1),
            @TypeReg = isnull(TypeRegister, 1),
            @Status = Approve_Status,
            @App1 = ltrim(rtrim(isnull(Approver_1, ''))),
            @App2 = ltrim(rtrim(isnull(Approver_2, ''))),
            @App3 = ltrim(rtrim(isnull(Approver_3, ''))),
            @App4 = ltrim(rtrim(isnull(Approver_4, ''))),
            @RegisterBy = ltrim(rtrim(isnull(RegisterBy, ''))),
            @GroupID = case when isnull(IsDivision, 0) = 1 then DivisionID else GroupID end,
            @IsDivision = isnull(IsDivision, 0),
            @OTDateFrom = OTDateFrom,
            @OTDateTo = OTDateTo
        from tblOTListRegisteredNIVS
        where cast(Identity_ID as varchar(100)) = @Identity_ID;

        if @CurrentLevel = -1
        begin
            select 'error' as result, N'Lỗi: Không tìm thấy Đơn này!' as reason; return;
        end

        if @Status not in (1, 5)
        begin
            select 'error' as result, N'Đơn này không ở trạng thái chờ xử lý!' as reason; return;
        end

        if (@CurrentLevel = 1 and @App1 <> @ActualEmployeeID) or
           (@CurrentLevel = 2 and @App2 <> @ActualEmployeeID) or
           (@CurrentLevel = 3 and @App3 <> @ActualEmployeeID) or
           (@CurrentLevel = 4 and @App4 <> @ActualEmployeeID)
        begin
            select 'error' as result, N'Từ chối: Bạn không có quyền duyệt cấp ' + cast(@CurrentLevel as varchar) as reason; return;
        end

        declare @CurrentTime datetime = getdate();

        set @RegisterBy = (select EmployeeID from tblSC_Login where cast(LoginID as varchar(50)) = @RegisterBy);

        declare @GroupName nvarchar(250);
        if @IsDivision = 1
            select @GroupName = DivisionName from tblDivision where DivisionID = @GroupID;
        else
            select @GroupName = GroupTeamName from tblGroupTeam where GroupTeamID = @GroupID;

        declare @TotalEmp int, @TotalHours float;
        select @TotalEmp = count(distinct EmployeeID), @TotalHours = sum(isnull(OTHours, 0))
        from tblOTListRegisteredNIVS_Detail
        where Identity_ID = @Identity_ID;

        declare @NotifyText nvarchar(max);
        declare @CurLang varchar(2);

        if @Action = 'REJECT'
        begin
            select top 1 @CurLang = isnull(nullif(CurLang, ''), 'VN')
            from tblSC_Login where cast(LoginID as varchar(50)) = @RegisterBy or EmployeeID = @RegisterBy;

            if @Status = 1
            begin
                update tblOTListRegisteredNIVS
                set Approve_Status = 3,
                    ApproverRemark_1 = case when @CurrentLevel = 1 then @Remark else ApproverRemark_1 end,
                    ApproveDate_1    = case when @CurrentLevel = 1 then @CurrentTime else ApproveDate_1 end,
  ApproverRemark_2 = case when @CurrentLevel = 2 then @Remark else ApproverRemark_2 end,
                    ApproveDate_2    = case when @CurrentLevel = 2 then @CurrentTime else ApproveDate_2 end,
                    ApproverRemark_3 = case when @CurrentLevel = 3 then @Remark else ApproverRemark_3 end,
                    ApproveDate_3    = case when @CurrentLevel = 3 then @CurrentTime else ApproveDate_3 end,
                    ApproverRemark_4 = case when @CurrentLevel = 4 then @Remark else ApproverRemark_4 end,
                    ApproveDate_4    = case when @CurrentLevel = 4 then @CurrentTime else ApproveDate_4 end
                where cast(Identity_ID as varchar(100)) = @Identity_ID;

                update tblOTListRegisteredNIVS_Detail set Approve_Status = 3 where cast(Identity_ID as varchar(100)) = @Identity_ID;

                set @NotifyText = case
                    when @CurLang = 'EN' then
                        N'Your OT Plan form was REJECTED:' + char(10) +
                        N'Dept: ' + isnull(@GroupName, '') + char(10) +
                        N'Date: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                        N'Reason: ' + isnull(@Remark, 'N/A')
                    when @CurLang = 'JP' then
                        N'計画残業申請が却下されました:' + char(10) +
                        N'部署: ' + isnull(@GroupName, '') + char(10) +
                        N'日付: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                        N'理由: ' + isnull(@Remark, 'N/A')
                    else
                        N'Đơn ĐK Tăng ca KH của bạn ĐÃ BỊ TỪ CHỐI:' + char(10) +
                        N'Bộ phận: ' + isnull(@GroupName, '') + char(10) +
                        N'Ngày: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                        N'Lý do: ' + isnull(@Remark, 'Không có')
                end;

                insert into tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
                values ('Nivs_App_Notify', 0, 1, @Identity_ID, @RegisterBy, 1, @NotifyText);

                select 'success' as result, N'Đã TỪ CHỐI đơn thành công!' as reason;
            end
            else if @Status = 5
            begin
                update tblOTListRegisteredNIVS
                set Approve_Status = 2,
                    Current_Approved_Level = case when @TypeReg = 1 then 3 else 4 end,
                    ApproveDate_1 = ApproveDate_1_Old, ApproverRemark_1 = ApproverRemark_1_Old,
                    ApproveDate_2 = ApproveDate_2_Old, ApproverRemark_2 = ApproverRemark_2_Old,
                    ApproveDate_3 = ApproveDate_3_Old, ApproverRemark_3 = ApproverRemark_3_Old,
                    ApproveDate_4 = ApproveDate_4_Old, ApproverRemark_4 = ApproverRemark_4_Old
                where cast(Identity_ID as varchar(100)) = @Identity_ID;

                set @NotifyText = case
                    when @CurLang = 'EN' then
                        N'Your CANCEL REQUEST was REJECTED:' + char(10) +
                        N'Dept: ' + isnull(@GroupName, '') + char(10) +
                        N'Date: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                        N'Reason: ' + isnull(@Remark, 'N/A')
                    when @CurLang = 'JP' then
                        N'キャンセル申請が却下されました:' + char(10) +
                        N'部署: ' + isnull(@GroupName, '') + char(10) +
                        N'日付: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                        N'理由: ' + isnull(@Remark, 'N/A')
                    else
                        N'Yêu cầu Xin Hủy đơn ĐÃ BỊ TỪ CHỐI:' + char(10) +
                        N'Bộ phận: ' + isnull(@GroupName, '') + char(10) +
   N'Ngày: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                        N'Lý do: ' + isnull(@Remark, 'Không có')
                end;

                insert into tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
                values ('Nivs_App_Notify', 0, 1, @Identity_ID, @RegisterBy, 1, @NotifyText);

                select 'success' as result, N'Đã TỪ CHỐI yêu cầu hủy. Đơn được trả về trạng thái Đã Duyệt!' as reason;
            end
            update Taskschedule set LastTryDay = '20190101', NextRunDate = '20190101' where FunctionName = 'SendPendingEmail';
            exec API_LoadNotificationMenu @LoginID = @LoginID
            return;
        end

        if @Action = 'APPROVE'
        begin
            if @ModifiedJSON is not null and isjson(@ModifiedJSON) = 1
            begin
                update d
                set d.Original_OTFrom = case when d.Original_OTFrom is null then d.OTFrom else d.Original_OTFrom end,
                    d.Original_OTTo = case when d.Original_OTTo is null then d.OTTo else d.Original_OTTo end,
                    d.OTFrom = nullif(m.NewFrom, ''),
                    d.OTTo = nullif(m.NewTo, ''),
                    d.OTHours = m.NewHours
                from tblOTListRegisteredNIVS_Detail d
                inner join openjson(@ModifiedJSON) with (
                    EmployeeID varchar(50) '$.EmployeeID',
                    OTDate date '$.OTDate',
                    NewFrom varchar(5) '$.NewFrom',
                    NewTo varchar(5) '$.NewTo',
                    NewHours float '$.NewHours'
                ) m on d.Identity_ID = @Identity_ID and d.EmployeeID = m.EmployeeID and d.OTDate = m.OTDate;
            end


            declare @IsFinalLevel bit = 0;
            if (@TypeReg = 1 and @CurrentLevel >= 3) or (@TypeReg = 2 and @CurrentLevel >= 4)
                set @IsFinalLevel = 1;

            if @IsFinalLevel = 1
            begin
                select top 1 @CurLang = isnull(nullif(CurLang, ''), 'VN')
                from tblSC_Login where cast(LoginID as varchar(50)) = @RegisterBy or EmployeeID = @RegisterBy;

                if @Status = 1
                begin
                    update tblOTListRegisteredNIVS
                    set Approve_Status = 2,
                        ApproverRemark_1 = case when @CurrentLevel = 1 then @Remark else ApproverRemark_1 end,
                        ApproveDate_1    = case when @CurrentLevel = 1 then @CurrentTime else ApproveDate_1 end,
                        ApproverRemark_2 = case when @CurrentLevel = 2 then @Remark else ApproverRemark_2 end,
                        ApproveDate_2    = case when @CurrentLevel = 2 then @CurrentTime else ApproveDate_2 end,
                        ApproverRemark_3 = case when @CurrentLevel = 3 then @Remark else ApproverRemark_3 end,
                        ApproveDate_3    = case when @CurrentLevel = 3 then @CurrentTime else ApproveDate_3 end,
                        ApproverRemark_4 = case when @CurrentLevel = 4 then @Remark else ApproverRemark_4 end,
                        ApproveDate_4    = case when @CurrentLevel = 4 then @CurrentTime else ApproveDate_4 end
                    where cast(Identity_ID as varchar(100)) = @Identity_ID;

                    update tblOTListRegisteredNIVS_Detail set Approve_Status = 2 where cast(Identity_ID as varchar(100)) = @Identity_ID;

                    set @NotifyText = case
                        when @CurLang = 'EN' then
                            N'Your OT Plan form is FULLY APPROVED:' + char(10) +
                            N'Dept: ' + isnull(@GroupName, '') + char(10) +
                            N'Date: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                            N'Emps: ' + cast(@TotalEmp as varchar) + N' people' + char(10) +
          N'Total OT: ' + cast(cast(@TotalHours as decimal(10,1)) as varchar) + N'h'
                        when @CurLang = 'JP' then
                            N'計画残業申請が最終承認されました:' + char(10) +
                            N'部署: ' + isnull(@GroupName, '') + char(10) +
                            N'日付: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                            N'対象者: ' + cast(@TotalEmp as varchar) + N' 名' + char(10) +
                            N'合計残業: ' + cast(cast(@TotalHours as decimal(10,1)) as varchar) + N'h'
                        else
                            N'Đơn ĐK Tăng ca KH ĐÃ ĐƯỢC DUYỆT XONG:' + char(10) +
                            N'Bộ phận: ' + isnull(@GroupName, '') + char(10) +
                            N'Ngày: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103) + char(10) +
                            N'Nhân viên: ' + cast(@TotalEmp as varchar) + N' người' + char(10) +
                            N'Tổng giờ: ' + cast(cast(@TotalHours as decimal(10,1)) as varchar) + N'h'
                    end;

                    insert into tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
                    values ('Nivs_App_Notify', 0, 1, @Identity_ID, @RegisterBy, 1, @NotifyText);

                    select 'success' as result, N'Đã DUYỆT HOÀN TẤT đơn đăng ký.' as reason;
                end
                else if @Status = 5
                begin
                    update tblOTListRegisteredNIVS
                    set Approve_Status = 4,
                        ApproverRemark_1 = case when @CurrentLevel = 1 then @Remark else ApproverRemark_1 end,
                        ApproveDate_1    = case when @CurrentLevel = 1 then @CurrentTime else ApproveDate_1 end,
                        ApproverRemark_2 = case when @CurrentLevel = 2 then @Remark else ApproverRemark_2 end,
                        ApproveDate_2    = case when @CurrentLevel = 2 then @CurrentTime else ApproveDate_2 end,
                        ApproverRemark_3 = case when @CurrentLevel = 3 then @Remark else ApproverRemark_3 end,
                        ApproveDate_3    = case when @CurrentLevel = 3 then @CurrentTime else ApproveDate_3 end,
                        ApproverRemark_4 = case when @CurrentLevel = 4 then @Remark else ApproverRemark_4 end,
                        ApproveDate_4    = case when @CurrentLevel = 4 then @CurrentTime else ApproveDate_4 end
                    where cast(Identity_ID as varchar(100)) = @Identity_ID;

                    update tblOTListRegisteredNIVS_Detail set Approve_Status = 4 where cast(Identity_ID as varchar(100)) = @Identity_ID;

                    set @NotifyText = case
                        when @CurLang = 'EN' then
                            N'Your CANCEL REQUEST is APPROVED:' + char(10) +
                            N'Dept: ' + isnull(@GroupName, '') + char(10) +
                            N'Date: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103)
                        when @CurLang = 'JP' then
                            N'キャンセル申請が承認されました:' + char(10) +
                            N'部署: ' + isnull(@GroupName, '') + char(10) +
                            N'日付: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103)
                        else
                            N'Yêu cầu Xin Hủy ĐÃ ĐƯỢC CHẤP THUẬN:' + char(10) +
                            N'Bộ phận: ' + isnull(@GroupName, '') + char(10) +
                            N'Ngày: ' + convert(varchar, @OTDateFrom, 103) + N' - ' + convert(varchar, @OTDateTo, 103)
                    end;

                    insert into tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
                    values ('Nivs_App_Notify', 0, 1, @Identity_ID, @RegisterBy, 1, @NotifyText);

                    select 'success' as result, N'Đã XÁC NHẬN CHO HỦY đơn.' as reason;
                end
            end
            else
            begin
                declare @NextLevel int = @CurrentLevel + 1;
                declare @NextApproverOnApprove varchar(50) = null;

                if @CurrentLevel = 1
                begin
                    if @App2 = 'SKIP'
                    begin
                        set @NextLevel = 3;
                        set @NextApproverOnApprove = @App3;
                    end
                    else
                    begin
                        set @NextLevel = 2;
                        set @NextApproverOnApprove = @App2;
                    end
                end
                else if @CurrentLevel = 2
                begin
                    set @NextLevel = 3;
                    set @NextApproverOnApprove = @App3;
                end
                else if @CurrentLevel = 3
                begin
                    set @NextLevel = 4;
                    set @NextApproverOnApprove = @App4;
                end

                update tblOTListRegisteredNIVS
                set Current_Approved_Level = @NextLevel,
                    ApproverRemark_1 = case when @CurrentLevel = 1 then @Remark else ApproverRemark_1 end,
                    ApproveDate_1    = case when @CurrentLevel = 1 then @CurrentTime else ApproveDate_1 end,

                    ApproverRemark_2 = case when @CurrentLevel = 2 then @Remark
                                            when @CurrentLevel = 1 and @App2 = 'SKIP' then N'Hệ thống tự động bỏ qua do Cấp 2 là Khác'
                                            else ApproverRemark_2 end,
                    ApproveDate_2    = case when @CurrentLevel = 2 then @CurrentTime
                                            when @CurrentLevel = 1 and @App2 = 'SKIP' then @CurrentTime
                                            else ApproveDate_2 end,

                    ApproverRemark_3 = case when @CurrentLevel = 3 then @Remark else ApproverRemark_3 end,
                    ApproveDate_3    = case when @CurrentLevel = 3 then @CurrentTime else ApproveDate_3 end
                where cast(Identity_ID as varchar(100)) = @Identity_ID;

                select top 1 @CurLang = isnull(nullif(CurLang, ''), 'VN')
                from tblSC_Login where cast(LoginID as varchar(50)) = @NextApproverOnApprove or EmployeeID = @NextApproverOnApprove;

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

                if isnull(@NextApproverOnApprove, '') <> '' and @NextApproverOnApprove <> 'SKIP'
                begin
                    insert into tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
                    values ('Nivs_App_Notify', 0, 1, @Identity_ID, @NextApproverOnApprove, 1, @NotifyText);
                end

                select 'success' as result, N'Đã duyệt thành công! Chuyển lên cấp tiếp theo.' as reason;
            end

            update Taskschedule set LastTryDay = '20190101', NextRunDate = '20190101' where FunctionName = 'SendPendingEmail';
             exec API_LoadNotificationMenu @LoginID = @LoginID
        end
    end try
    begin catch
        select 'error' as result, error_message() as reason;
    end catch
end
GO