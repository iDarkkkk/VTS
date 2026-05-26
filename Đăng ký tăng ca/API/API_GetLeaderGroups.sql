USE Paradise_NIVS_Cloud
GO
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
        DECLARE @EmpID VARCHAR(50);
        SELECT @EmpID = EmployeeID FROM tblSC_Login WHERE LoginID = @LoginID;
         --if @LoginID = 3 begin  set @EmpID ='19226' end
        SELECT GroupTeamID AS GroupID, GroupTeamName AS GroupName, 0 AS IsDivision
        INTO #tmpGroups
        FROM dbo.fn_GetLeaderGroups(@LoginID);

        IF @EmpID IS NOT NULL
        BEGIN
            INSERT INTO #tmpGroups (GroupID, GroupName, IsDivision)
            SELECT DivisionID AS GroupID, DivisionName AS GroupName, 1 AS IsDivision
            FROM tblDivision
            CROSS APPLY STRING_SPLIT(CAST(ClerkEmployeeID AS VARCHAR(500)), '&')
            WHERE LTRIM(RTRIM(value)) = @EmpID;
        END

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