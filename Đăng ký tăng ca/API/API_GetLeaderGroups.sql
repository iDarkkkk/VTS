
if object_id('[dbo].[API_GetLeaderGroups]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_GetLeaderGroups] as select 1')
GO

ALTER PROCEDURE [dbo].[API_GetLeaderGroups]
    @LoginID VARCHAR(50)  = null
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
     -- set @LoginID = 1095
        DECLARE @EmpID VARCHAR(50), @IsProduction4Leader bit = 0;
        SELECT @EmpID = EmployeeID FROM tblSC_Login WHERE LoginID = @LoginID;

        if exists (
            select 1
            from dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1', null) e
            inner join tblPosition p on e.PositionID = p.PositionID
            where e.EmployeeID = @EmpID and p.PositionName like '%Leader%' and e.DivisionID in (11, 17)

            union

            select 1
            from tblReponLeader rl
            inner join dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1', null) e on rl.EmployeeID = e.EmployeeID
            where rl.EmployeeID = @EmpID and e.DivisionID in (11, 17)

            union

            select 1
            from tblDivision d
            cross apply string_split(cast(d.ClerkEmployeeID as varchar(500)), '&')
            inner join dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1', null) e on e.EmployeeID = @EmpID
            where d.DivisionID in (11, 17) and ltrim(rtrim(value)) = @EmpID and e.DivisionID in (11, 17)
        )
        begin
            set @IsProduction4Leader = 1;
        end

         --if @LoginID = 3 begin  set @EmpID ='19226' end
        create table #tmpGroups (GroupID int, GroupName nvarchar(255), IsDivision int);

        if @IsProduction4Leader = 1
        begin
            insert into #tmpGroups (GroupID, GroupName, IsDivision)
            select distinct leader.SectionID as GroupID, isnull(leader.SectionName, 'N/A') as GroupName, 0 as IsDivision
            from (
                select e.EmployeeID, e.SectionID, sec.SectionName
                from dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1', null) e
                inner join tblPosition p on e.PositionID = p.PositionID
                 left join tblSection sec on sec.SectionID = e.SectionID
                where e.EmployeeID = @EmpID and p.PositionName like '%Leader%' and e.DivisionID in (11, 17)

                union

                select e.EmployeeID, e.SectionID as GroupID, sec.SectionName as GroupName
                from tblReponLeader rl
                inner join dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1', null) e on rl.EmployeeID = e.EmployeeID
                  left join tblSection sec on sec.SectionID = e.SectionID
                where rl.EmployeeID = @EmpID and e.DivisionID in (11, 17)

                union

                select e.EmployeeID, e.SectionID as GroupID, sec.SectionName as GroupName
                from tblDivision d
                cross apply string_split(cast(d.ClerkEmployeeID as varchar(500)), '&')
                inner join dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1', null) e on e.EmployeeID = @EmpID
                left join tblSection sec on sec.SectionID = e.SectionID
                where d.DivisionID in (11, 17) and ltrim(rtrim(value)) = @EmpID and e.DivisionID in (11, 17)
            ) leader
            where leader.SectionID is not null;
        end
        else
        begin
            insert into #tmpGroups (GroupID, GroupName, IsDivision)
            select GroupTeamID as GroupID, GroupTeamName as GroupName, 0 as IsDivision
            from dbo.fn_GetLeaderGroups(@LoginID);
        end

        IF @EmpID IS NOT NULL and @IsProduction4Leader = 0
        BEGIN
            INSERT INTO #tmpGroups (GroupID, GroupName, IsDivision)
            SELECT DivisionID AS GroupID, DivisionName AS GroupName, 1 AS IsDivision
            FROM tblDivision
            CROSS APPLY STRING_SPLIT(CAST(ClerkEmployeeID AS VARCHAR(500)), '&')
            WHERE LTRIM(RTRIM(value)) = @EmpID;
        END
        --đám leader kiêm nhiệm
         INSERT INTO #tmpGroups (GroupID, GroupName, IsDivision)
         SELECT DISTINCT  e.GroupTeamID AS GroupID,g.GroupTeamName AS GroupName,0 AS IsDivision
            FROM tblReponLeader r INNER JOIN dbo.fn_vtblEmployeeList_Simple_ByDate(GETDATE(), '-1', NULL) e  ON r.EmployeeID = e.EmployeeID
            INNER JOIN tblGroupTeam g  ON e.GroupTeamID = g.GroupTeamID WHERE r.EmployeeID = @EmpID
                  AND e.GroupTeamID IS NOT NULL
                  AND @IsProduction4Leader = 0
                  AND NOT EXISTS ( SELECT 1 FROM #tmpGroups t WHERE t.GroupID = e.GroupTeamID AND t.IsDivision = 0
                  );

        SELECT GroupID, GroupName, IsDivision
        FROM #tmpGroups
        ORDER BY IsDivision, GroupName;

        DROP TABLE #tmpGroups;

    END TRY
    BEGIN CATCH
        SELECT 'error' AS result, ERROR_MESSAGE() AS reason;
    END CATCH
END
GO

