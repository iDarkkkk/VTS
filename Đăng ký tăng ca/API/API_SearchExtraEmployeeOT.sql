USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_SearchExtraEmployeeOT]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_SearchExtraEmployeeOT] as select 1')
GO

ALTER PROCEDURE [dbo].[API_SearchExtraEmployeeOT]
    @LoginID VARCHAR(50),
    @FromDate DATE,
    @ToDate DATE,
    @Keyword NVARCHAR(MAX),
    @TypeRegister INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF (LTRIM(RTRIM(ISNULL(@Keyword, ''))) = '' OR LEN(LTRIM(RTRIM(@Keyword))) < 2)
    BEGIN
        SELECT TOP 0 1 AS EmployeeID, '' AS FullName, '' AS DepartmentName, '' AS GroupName, 0 AS GroupID,
               1 AS EmployeeTypeID, '' AS PositionID, 0 AS BaseOT_Before, 0 AS ShiftID, '' AS ShiftName,
               NULL AS WorkStart, NULL AS WorkEnd, NULL AS OTBeforeStart, NULL AS OTBeforeEnd,
               NULL AS OTAfterStart, NULL AS OTAfterEnd, 0 AS HolidayStatus,
               0 AS RegisteredCount, 0 AS TotalDays, '' AS RegisteredDates_VN, '' AS RegisteredDates_SYS,
               -1 AS IsAllowLate;
        RETURN;
    END

    DECLARE @LeaderEmpID VARCHAR(50);
    DECLARE @DivisionID VARCHAR(50);
    DECLARE @TotalDays INT = DATEDIFF(day, @FromDate, @ToDate) + 1;

    SELECT * INTO #tblEmployee FROM dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', NULL);

    IF CHARINDEX(';', @Keyword) > 0
    BEGIN
        SELECT LTRIM(RTRIM(Items)) AS EmpID
        INTO #SearchKeys
        FROM dbo.SplitString(@Keyword, ';')
        WHERE LTRIM(RTRIM(Items)) <> '';

        DELETE e FROM #tblEmployee e
        WHERE NOT EXISTS (SELECT 1 FROM #SearchKeys k WHERE e.EmployeeID = k.EmpID);

        DROP TABLE #SearchKeys;
    END
    ELSE
    BEGIN
        DELETE FROM #tblEmployee
        WHERE EmployeeID NOT LIKE '%' + LTRIM(RTRIM(@Keyword)) + '%'
          AND FullName NOT LIKE N'%' + LTRIM(RTRIM(@Keyword)) + '%';
    END

    SELECT * INTO #StatusRange FROM dbo.fn_EmployeeStatusRange(1) WHERE EmployeeStatusID IN (1, 20);

    DELETE FROM #tblEmployee
    WHERE @ToDate < HireDate OR @FromDate > ISNULL(LastWorkingDate, '2099-12-31');

    DELETE e
    FROM #tblEmployee e
    INNER JOIN #StatusRange sr ON e.EmployeeID = sr.EmployeeID
    WHERE sr.ChangedDate <= @ToDate AND sr.StatusEndDate >= @FromDate;

    SELECT TOP 1 @LeaderEmpID = LTRIM(RTRIM(EmployeeID))
    FROM tblSc_Login WHERE LoginName = @LoginID OR CAST(LoginID AS VARCHAR(50)) = @LoginID;

    SELECT TOP 1 @DivisionID = DivisionID FROM #tblEmployee WHERE EmployeeID = @LeaderEmpID;

    SELECT * INTO #MaternityStatus FROM dbo.fn_EmployeeStatusRange(0) WHERE EmployeeStatusID = 11 AND EmployeeID IN (SELECT EmployeeID FROM #tblEmployee);

    DECLARE @StartOfMonth DATE = DATEFROMPARTS(YEAR(@FromDate), MONTH(@FromDate), 1);

    SELECT ed.EmployeeID,
           SUM(CASE WHEN ISNULL(s.HolidayStatus, 0) = 0 THEN 1 ELSE 0 END) AS NormalDays,
           SUM(CASE WHEN ISNULL(s.HolidayStatus, 0) > 0 THEN 1 ELSE 0 END) AS HolidayDays
    INTO #EmpDayTypes
    FROM (SELECT e.EmployeeID, d.Date AS OTDate FROM #tblEmployee e CROSS JOIN dbo.fn_datelist(@FromDate, @ToDate) d) ed
    LEFT JOIN tblAttendanceSummary s ON ed.EmployeeID = s.EmployeeID AND ed.OTDate = CAST(s.AttDate AS DATE)
    GROUP BY ed.EmployeeID;
    -- =========================================================================


    SELECT e.EmployeeID, e.FullName, d.DepartmentName, g.GroupTeamName AS GroupName, e.GroupTeamID AS GroupID,
        ISNULL(e.EmployeeTypeID, 1) AS EmployeeTypeID,
        ISNULL(e.PositionID, '') AS PositionID,
        ISNULL((
            SELECT SUM(ISNULL(ApprovedHours, 0)) FROM tblAttendanceSummary
            WHERE EmployeeID = e.EmployeeID AND AttDate >= @StartOfMonth AND AttDate < @FromDate
        ), 0) AS BaseOT_Before,
        s.ShiftID, ss.ShiftName, ss.WorkStart, ss.WorkEnd, ss.OTBeforeStart, ss.OTBeforeEnd, ss.OTAfterStart, ss.OTAfterEnd,

        CASE
            WHEN @TypeRegister = 1 THEN CASE WHEN ISNULL(edt.NormalDays, 0) > 0 THEN 0 ELSE 1 END
            WHEN @TypeRegister = 2 THEN CASE WHEN ISNULL(edt.HolidayDays, 0) > 0 THEN 1 ELSE 0 END
            ELSE 0
        END AS HolidayStatus,


        @TotalDays AS TotalDays,
        ISNULL(reg.RegisteredCount, 0) AS RegisteredCount,
        ISNULL(reg.RegisteredDates_VN, '') AS RegisteredDates_VN,
        ISNULL(reg.RegisteredDates_SYS, '') AS RegisteredDates_SYS,

        cast(ISNULL(et.Direct, 1) as varchar) AS IsDirect,

        ISNULL((SELECT TOP 1 isAllowLate FROM #MaternityStatus ms WHERE ms.EmployeeID = e.EmployeeID AND @FromDate BETWEEN ms.ChangedDate AND ms.StatusEndDate ORDER BY ms.ChangedDate DESC), -1) AS IsAllowLate

    FROM #tblEmployee e
    LEFT JOIN #EmpDayTypes edt ON e.EmployeeID = edt.EmployeeID
    LEFT JOIN tblDepartment d ON e.DepartmentID = d.DepartmentID
    LEFT JOIN tblGroupTeam g ON e.GroupTeamID = g.GroupTeamID
    LEFT JOIN tblAttendanceSummary s ON s.EmployeeID = e.EmployeeID AND CAST(s.AttDate AS DATE) = @FromDate
    LEFT JOIN tblShiftSetting ss ON s.ShiftID = ss.ShiftID
    LEFT JOIN tblEmployeeType et ON e.EmployeeTypeID = et.EmployeeTypeID
    OUTER APPLY (
        SELECT
            COUNT(DISTINCT od.OTDate) AS RegisteredCount,
            STUFF((
                SELECT DISTINCT CHAR(10) + '• ' + CONVERT(VARCHAR, od2.OTDate, 103) + ' (Mã: ' + LEFT(om2.Identity_ID, 8) + ' | ' + ISNULL(td2.DivisionName, ISNULL(tg2.GroupTeamName, 'N/A')) + ' | Tạo: ' + ISNULL(emp2.FullName, om2.RegisterBy) + ')'
                FROM tblOTListRegisteredNIVS_Detail od2
                JOIN tblOTListRegisteredNIVS om2 ON od2.Identity_ID = om2.Identity_ID
                LEFT JOIN tblGroupTeam tg2 ON om2.GroupID = tg2.GroupTeamID
                LEFT JOIN tblDivision td2 ON om2.DivisionID = td2.DivisionID
                LEFT JOIN tblSc_Login sc2 ON om2.RegisterBy = sc2.LoginID
                LEFT JOIN tblEmployee emp2 ON sc2.EmployeeID = emp2.EmployeeID
                WHERE od2.EmployeeID = e.EmployeeID AND od2.OTDate BETWEEN @FromDate AND @ToDate AND om2.Approve_Status IN (1, 2)
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS RegisteredDates_VN,
            STUFF((SELECT DISTINCT ';' + CONVERT(VARCHAR, od2.OTDate, 23)
                   FROM tblOTListRegisteredNIVS_Detail od2
                   JOIN tblOTListRegisteredNIVS om2 ON od2.Identity_ID = om2.Identity_ID
                   WHERE od2.EmployeeID = e.EmployeeID AND od2.OTDate BETWEEN @FromDate AND @ToDate AND om2.Approve_Status IN (1, 2)
                   FOR XML PATH('')), 1, 1, '') AS RegisteredDates_SYS
        FROM tblOTListRegisteredNIVS_Detail od
        JOIN tblOTListRegisteredNIVS om ON od.Identity_ID = om.Identity_ID
        WHERE od.EmployeeID = e.EmployeeID
          AND od.OTDate BETWEEN @FromDate AND @ToDate
          AND om.Approve_Status IN (1, 2)
    ) reg
    ORDER BY e.EmployeeID;

    DROP TABLE #tblEmployee, #StatusRange, #MaternityStatus, #EmpDayTypes;
END
GO