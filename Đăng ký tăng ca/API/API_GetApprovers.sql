USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_GetApprovers]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_GetApprovers] as select 1')
GO

ALTER PROCEDURE [dbo].[API_GetApprovers]
    @LeaderEmpID VARCHAR(50),
    @OTType INT = 1,        -- 1: Kế hoạch, 2: Thực tế, 3: Vượt
    @TypeRegister INT = 1   -- 1: Ngày thường, 2: Ngày nghỉ/lễ
AS
BEGIN
    set nocount on;
    DECLARE @TargetOTTypeID int = 1;
    select top 1 @LeaderEmpID = EmployeeID from tblSC_Login where LoginID = @LeaderEmpID

    --Hiếu: chia lại loại đăng ký tăng ca
    if @OTType = 1 and @TypeRegister =  1 set @TargetOTTypeID = 1
    else if @OTType = 1 and @TypeRegister = 2 set @TargetOTTypeID = 2
    else if @OTType = 2 and @TypeRegister = 1 set @TargetOTTypeID = 3
    else if @OTType = 2 and @TypeRegister = 2 set @TargetOTTypeID = 4
    else if @OTType = 3 set @TargetOTTypeID = 5

    --Hiếu: lấy bộ phận của người đăng ký
    DECLARE @DivisionID int, @DivisionID2 int, @MinApproverLevel int = 4;
    select @DivisionID  = DivisionID from dbo.fn_vtblEmployeeList_Bydate(GETDATE(), '-1',null) te
    where te.EmployeeID = @LeaderEmpID and te.EmployeeStatusID <> 20

    select @DivisionID2 = DivisionID2 from tblDivisionGroup where DivisionID = @DivisionID

    select @MinApproverLevel = case
        when right(rtrim(isnull(nullif(d.DivisionNameEN, ''), d.DivisionName)), 1) = 'I' then 6
        else 4
    end
    from tblDivision d
    where d.DivisionID = @DivisionID


    -- Lấy cấp duyệt
    Declare @App2 varchar(20), @App3 varchar(20), @App4 varchar(20), @App5 varchar(20);

    select top 1 @App2 = Approver_2, @App3 = Approver_3, @App4 = Approver_4, @App5 = Approver_5
    from tblOT_ApprovalSetting ot
    where ot.DivisionID = @DivisionID and @TargetOTTypeID = OTTypeID

    IF OBJECT_ID('tempdb..#TempApprovers') IS NOT NULL DROP TABLE #TempApprovers;
    create table #TempApprovers
    (
        approver int,
        EmployeeID varchar(20),
        Level int
    )
    insert into #TempApprovers(approver, EmployeeID, Level)
    select distinct 1, te.EmployeeID, pos.level
    from dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1', null) te
    inner join tblPosition pos on pos.PositionID = te.PositionID
    where te.TerminateDate is null and te.EmployeeStatusID <> 20 and isnull(pos.level, 0) >= @MinApproverLevel
        and (te.DivisionID = @DivisionID or (@DivisionID2 is not null and te.DivisionID = @DivisionID2));

   if nullif(ltrim(rtrim(@App2)), '') is not null
    begin
         Insert into #TempApprovers(approver,EmployeeID)
         select 2,@App2
    end
    if nullif(ltrim(rtrim(@App3)), '') is not null
    begin
            Insert into #TempApprovers(approver,EmployeeID)
            select 3,@App3
    end
   if nullif(ltrim(rtrim(@App4)), '') is not null
    begin
            Insert into #TempApprovers(approver,EmployeeID)
            select 4,@App4
    end

   if nullif(ltrim(rtrim(@app5)), '') is not null
    begin
            Insert into #TempApprovers(approver,EmployeeID)
            select 5,@App5
    end

    SELECT t.approver, t.EmployeeID, t.EmployeeID + ' - ' + ISNULL(e.FullName, '') AS FullName,Level
    FROM #TempApprovers t
    LEFT JOIN tblEmployee e ON t.EmployeeID = e.EmployeeID
    ORDER BY t.approver, t.Level;

    DROP TABLE #TempApprovers;

END
GO
exec API_GetApprovers '12430',1,1
