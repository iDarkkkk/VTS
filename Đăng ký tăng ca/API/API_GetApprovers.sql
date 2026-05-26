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
    DECLARE @DivisionID int ;
    select @DivisionID  = DivisionID from dbo.fn_vtblEmployeeList_Bydate(GETDATE(), '-1',null) te
    where te.EmployeeID = @LeaderEmpID and te.EmployeeStatusID <> 20

    --Lấy cấp duyệt
    Declare @App1 varchar(20),@App2 varchar(20) ,@App3 varchar(20),@App4 varchar(20);

    select top 1 @App1 = Approver_1,@App2 = Approver_2,@App3  = Approver_3,@App4 = Approver_4 from tblOT_ApprovalSetting ot
    where ot.DivisionID = @DivisionID and @TargetOTTypeID = OTTypeID

    IF OBJECT_ID('tempdb..#TempApprovers') IS NOT NULL DROP TABLE #TempApprovers;
    create table #TempApprovers
    (
        approver int,
        EmployeeID varchar(20),
        Level int
    )
    if @App1 is not null
    begin
        Insert into #TempApprovers(approver,EmployeeID)
        select 1,@App1
    end
    ELSE
    BEGIN
        -- [LỌC ĐỘNG TÌM CẤP 1 TỪ LEVEL 5 TRỞ LÊN]
        SELECT u.level_id, s.Items AS PositionID, u.ApproverLevel
        INTO #tblUserGroupMap
        FROM tblUserGroupApprovalLevel u
        CROSS APPLY dbo.SplitString(u.PositionIDss,'&') AS s;

        CREATE TABLE #tblPosGrade(PositionID INT, PosGrade INT);
        INSERT INTO #tblPosGrade(PositionID, PosGrade)
        VALUES (1466,1), (1461,2), (1463,3), (1462,4), (1488,5);

        SELECT e.EmployeeID, e.PositionID, e.DivisionID, e.DepartmentID, e.SectionID,
               l.level_id, l.ApproverLevel, po.PosGrade
        INTO #EmpHierarchy
        FROM dbo.fn_vtblEmployeeList_Simple_ByDate(GETDATE(), '-1', NULL) e
        INNER JOIN #tblUserGroupMap AS l ON l.PositionID = CAST(e.PositionID AS VARCHAR(50))
        LEFT JOIN #tblPosGrade AS po ON po.PositionID = e.PositionID
        WHERE e.TerminateDate IS NULL AND l.level_id IS NOT NULL AND e.EmployeeStatusID <> 20;

        DECLARE @ReqDept INT, @ReqDiv INT, @ReqDiv2 INT, @ReqSec INT, @ReqLvl INT, @ReqAppLvl INT, @ReqPosGrade INT;
        SELECT @ReqDept = DepartmentID, @ReqDiv = DivisionID, @ReqSec = SectionID,
               @ReqLvl = level_id, @ReqAppLvl = ApproverLevel, @ReqPosGrade = PosGrade
        FROM #EmpHierarchy WHERE EmployeeID = @LeaderEmpID;

        SELECT @ReqDiv2 = DivisionID2 FROM tblDivisionGroup WHERE DivisionID = @ReqDiv;

        IF @ReqLvl = 6
        BEGIN
            DELETE FROM #EmpHierarchy WHERE level_id < @ReqLvl OR EmployeeID = @LeaderEmpID;
            DELETE FROM #EmpHierarchy WHERE ISNULL(PosGrade, 0) <= ISNULL(@ReqPosGrade, 0);

            IF EXISTS(SELECT 1 FROM #EmpHierarchy WHERE DivisionID = @ReqDiv)
            BEGIN
                DELETE FROM #EmpHierarchy WHERE DivisionID <> @ReqDiv;
            END
        END
        ELSE
        BEGIN
            DELETE FROM #EmpHierarchy WHERE level_id <= @ReqLvl;

            IF @ReqLvl > 2
            BEGIN
                IF @ReqDiv2 IS NOT NULL
                    DELETE FROM #EmpHierarchy WHERE DivisionID <> @ReqDiv AND DivisionID <> @ReqDiv2;
                ELSE
                    DELETE FROM #EmpHierarchy WHERE DivisionID <> @ReqDiv;
            END
            ELSE
            BEGIN
                -- Lọc Nhánh < ApproverLevel
                IF NOT EXISTS(SELECT 1 FROM #EmpHierarchy WHERE SectionID = @ReqSec AND level_id < @ReqAppLvl)
                BEGIN
                    IF NOT EXISTS(SELECT 1 FROM #EmpHierarchy WHERE DepartmentID = @ReqDept AND level_id < @ReqAppLvl)
                    BEGIN
                        IF @ReqDiv2 IS NOT NULL
                             DELETE FROM #EmpHierarchy WHERE DivisionID <> @ReqDiv AND DivisionID <> @ReqDiv2 AND level_id < @ReqAppLvl;
                        ELSE
                             DELETE FROM #EmpHierarchy WHERE DivisionID <> @ReqDiv AND level_id < @ReqAppLvl;
                    END
                    ELSE
                        DELETE FROM #EmpHierarchy WHERE DepartmentID <> @ReqDept AND level_id < @ReqAppLvl;
                END
                ELSE
                    DELETE FROM #EmpHierarchy WHERE SectionID <> @ReqSec AND level_id < @ReqAppLvl;

                -- Lọc Nhánh >= ApproverLevel
                IF NOT EXISTS(SELECT 1 FROM #EmpHierarchy WHERE SectionID = @ReqSec AND level_id >= @ReqAppLvl)
                BEGIN
                    IF NOT EXISTS(SELECT 1 FROM #EmpHierarchy WHERE DepartmentID = @ReqDept AND level_id >= @ReqAppLvl)
                    BEGIN
                        IF @ReqDiv2 IS NOT NULL
                              DELETE FROM #EmpHierarchy WHERE DivisionID <> @ReqDiv AND DivisionID <> @ReqDiv2 AND level_id >= @ReqAppLvl;
                        ELSE
                             DELETE FROM #EmpHierarchy WHERE DivisionID <> @ReqDiv AND level_id >= @ReqAppLvl;
                    END
                    ELSE
                         DELETE FROM #EmpHierarchy WHERE DepartmentID <> @ReqDept AND level_id >= @ReqAppLvl;
                END
                ELSE
                     DELETE FROM #EmpHierarchy WHERE SectionID <> @ReqSec AND level_id >= @ReqAppLvl;
            END
        END

        -- [CHỐT HẠ LOGIC MỚI]: CHỈ BỐC NHỮNG ÔNG TỪ LEVEL 5 TRỞ LÊN GÁN VÀO CẤP 1
        INSERT INTO #TempApprovers (approver, EmployeeID,Level)
        SELECT DISTINCT 1, e.EmployeeID,pos.level
        FROM #EmpHierarchy e
        inner join dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(),'-1',null) te on e.EmployeeID = te.EmployeeID
        left join tblPosition pos on pos.PositionID = te.PositionID
        WHERE level_id >= 5;

        DROP TABLE #tblUserGroupMap;
        DROP TABLE #tblPosGrade;
        DROP TABLE #EmpHierarchy;
    END
     if @App2 is not null
        begin
             Insert into #TempApprovers(approver,EmployeeID)
             select 2,@App2
        end
    if @App3 is not null
    begin
            Insert into #TempApprovers(approver,EmployeeID)
            select 3,@App3
    end
        if @App4 is not null
    begin
            Insert into #TempApprovers(approver,EmployeeID)
            select 4,@App4
    end
    --Hiếu: xóa nếu cấp 2 3 4  đã có người đó rồi, tránh bị 1 người duyệt 2 lần
    --delete from #TempApprovers  where approver = 1 and EmployeeID in (isnull(@App1,''),isnull(@App2,''),isnull(@App3,''),isnull(@App4,''))
    SELECT t.approver, t.EmployeeID, t.EmployeeID + ' - ' + ISNULL(e.FullName, '') AS FullName,Level
    FROM #TempApprovers t
    LEFT JOIN tblEmployee e ON t.EmployeeID = e.EmployeeID
    ORDER BY t.approver, t.Level;

    DROP TABLE #TempApprovers;

END
GO