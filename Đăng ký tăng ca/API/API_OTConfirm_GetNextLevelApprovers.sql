USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTConfirm_GetNextLevelApprovers]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTConfirm_GetNextLevelApprovers] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTConfirm_GetNextLevelApprovers]
    @LeaderEmpID varchar(50),
    @PrevLevelEmpID varchar(50),
    @TargetLevel int,
    @TypeRegister int = 1 -- 1: Ngày thường, 2: Ngày nghỉ
as
begin
    set nocount on;
    -- OTTypeID: 3 (Thực tế ngày thường), 4 (Thực tế ngày nghỉ)
    declare @TargetOTTypeID int = case when @TypeRegister = 1 then 3 else 4 end;
    declare @ActualLeader varchar(50);
    select top 1 @ActualLeader = EmployeeID from tblSC_Login where LoginID = @LeaderEmpID;

    declare @DivisionID int;
    select @DivisionID = DivisionID from dbo.fn_vtblEmployeeList_Bydate(getdate(), '-1', null) te
    where te.EmployeeID = @ActualLeader and te.EmployeeStatusID <> 20;

    -- Kiểm tra xem cấp này có bị Admin ghim cứng không trong tblOT_ApprovalSetting
    declare @App1 varchar(20), @App2 varchar(20), @App3 varchar(20), @App4 varchar(20), @App5 varchar(20);
    -- Lưu ý: tblOT_ApprovalSetting hiện tại có thể chưa có Approver_5, nếu chưa có sẽ là NULL
    select top 1 @App1 = Approver_1, @App2 = Approver_2, @App3 = Approver_3, @App4 = Approver_4
    from tblOT_ApprovalSetting ot
    where ot.DivisionID = @DivisionID and @TargetOTTypeID = OTTypeID;

    declare @HardcodedApp varchar(20) = null;
    if @TargetLevel = 1 set @HardcodedApp = @App1;
    if @TargetLevel = 2 set @HardcodedApp = @App2;
    if @TargetLevel = 3 set @HardcodedApp = @App3;
    if @TargetLevel = 4 set @HardcodedApp = @App4;
    -- Cấp 5 mặc định là Henry nếu là ngày nghỉ (Theo logic thường lệ của hệ thống này)
    if @TargetLevel = 5 set @HardcodedApp = '10001'; 

    -- Nếu đã ghim cứng -> Trả về đúng 1 người đó và kết thúc
    if @HardcodedApp is not null
    begin
        select @TargetLevel as approver, @HardcodedApp as EmployeeID,
               @HardcodedApp + ' - ' + isnull((select FullName from tblEmployee where EmployeeID = @HardcodedApp), '') as FullName,
               null as Level;
        return;
    end

    -- Xây dựng cây sơ đồ phòng ban (Tương tự logic Plan OT)
    select u.level_id, s.Items as PositionID, u.ApproverLevel into #tblUserGroupMap
    from tblUserGroupApprovalLevel u cross apply dbo.SplitString(u.PositionIDss,'&') as s;

    create table #tblPosGrade(PositionID int, PosGrade int);
    insert into #tblPosGrade(PositionID, PosGrade) values (1466,1), (1461,2), (1463,3), (1462,4), (1488,5);

    select e.EmployeeID, e.PositionID, e.DivisionID, e.DepartmentID, e.SectionID, l.level_id, l.ApproverLevel, po.PosGrade
    into #EmpHierarchy
    from dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1', null) e
    inner join #tblUserGroupMap as l on l.PositionID = cast(e.PositionID as varchar(50))
    left join #tblPosGrade as po on po.PositionID = e.PositionID
    where e.TerminateDate is null and l.level_id is not null and e.EmployeeStatusID <> 20;

    declare @ReqDept int, @ReqDiv int, @ReqDiv2 int, @ReqSec int, @ReqLvl int, @ReqAppLvl int, @ReqPosGrade int;
    select @ReqDept = DepartmentID, @ReqDiv = DivisionID, @ReqSec = SectionID, @ReqLvl = level_id, @ReqAppLvl = ApproverLevel, @ReqPosGrade = PosGrade
    from #EmpHierarchy where EmployeeID = @ActualLeader;

    select @ReqDiv2 = DivisionID2 from tblDivisionGroup WHERE DivisionID = @ReqDiv;

    if @ReqLvl = 6
    begin
        delete from #EmpHierarchy where level_id < @ReqLvl or EmployeeID = @ActualLeader;
        delete from #EmpHierarchy where isnull(PosGrade, 0) <= isnull(@ReqPosGrade, 0);
        if exists(select 1 from #EmpHierarchy where DivisionID = @ReqDiv) delete from #EmpHierarchy where DivisionID <> @ReqDiv;
    end
    else
    begin
        delete from #EmpHierarchy where level_id <= @ReqLvl;
        if @ReqLvl > 2
        begin
            if @ReqDiv2 is not null delete from #EmpHierarchy where DivisionID <> @ReqDiv and DivisionID <> @ReqDiv2;
            else delete from #EmpHierarchy where DivisionID <> @ReqDiv;
        end
        else
        begin
            if not exists(select 1 from #EmpHierarchy where SectionID = @ReqSec and level_id < @ReqAppLvl)
            begin
                if not exists(select 1 from #EmpHierarchy where DepartmentID = @ReqDept and level_id < @ReqAppLvl)
                begin
                    if @ReqDiv2 is not null delete from #EmpHierarchy where DivisionID <> @ReqDiv and DivisionID <> @ReqDiv2 and level_id < @ReqAppLvl;
                    else delete from #EmpHierarchy where DivisionID <> @ReqDiv and level_id < @ReqAppLvl;
                end
                else delete from #EmpHierarchy where DepartmentID <> @ReqDept and level_id < @ReqAppLvl;
            end
            else delete from #EmpHierarchy where SectionID <> @ReqSec and level_id < @ReqAppLvl;

            if not exists(select 1 from #EmpHierarchy where SectionID = @ReqSec and level_id >= @ReqAppLvl)
            begin
                if not exists(select 1 from #EmpHierarchy where DepartmentID = @ReqDept and level_id >= @ReqAppLvl)
                begin
                    if @ReqDiv2 is not null delete from #EmpHierarchy where DivisionID <> @ReqDiv and DivisionID <> @ReqDiv2 and level_id >= @ReqAppLvl;
                    else delete from #EmpHierarchy where DivisionID <> @ReqDiv and level_id >= @ReqAppLvl;
                end
                else delete from #EmpHierarchy where DepartmentID <> @ReqDept and level_id >= @ReqAppLvl;
            end
            else delete from #EmpHierarchy where SectionID <> @ReqSec and level_id >= @ReqAppLvl;
        end
    end

    -- Bắt Level của Cấp trước đó
    declare @Prev_Level int = 0;
    if @PrevLevelEmpID <> 'SKIP' and @PrevLevelEmpID <> ''
    begin
        select top 1 @Prev_Level = isnull(pos.level, 0)
        from dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(),'-1',null) te left join tblPosition pos on te.PositionID = pos.PositionID
        where te.EmployeeID = @PrevLevelEmpID;
    end

    -- Xuất danh sách lớn hơn Level trước
    select distinct @TargetLevel as approver, e.EmployeeID, e.EmployeeID + ' - ' + isnull(te.FullName, '') as FullName, pos.level as Level
    from #EmpHierarchy e
    inner join dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(),'-1',null) te on e.EmployeeID = te.EmployeeID
    left join tblPosition pos on pos.PositionID = te.PositionID
    where e.level_id >= 5 and isnull(pos.level, 0) > @Prev_Level
    order by pos.level;

    drop table #tblUserGroupMap;
    drop table #tblPosGrade;
    drop table #EmpHierarchy;
end
GO
