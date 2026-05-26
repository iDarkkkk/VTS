USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTConfirm_GetHistory]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTConfirm_GetHistory] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTConfirm_GetHistory]
    @LoginID VARCHAR(50),
    @FromDate DATE,
    @ToDate DATE,
    @Status INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        m.Identity_ID, m.GroupID,

        CASE WHEN ISNULL(m.IsDivision, 0) = 1 THEN ISNULL((SELECT DivisionName FROM tblDivision WHERE DivisionID = m.DivisionID), 'N/A')
             ELSE ISNULL(g.GroupTeamName, 'N/A') END AS GroupName,

        m.TypeRegister,
        ISNULL(m.IsDivision, 0) AS IsDivision,

        m.OTDate, m.Approve_Status, m.Current_Approved_Level, m.CreateTime,
        m.Approver_1, a1.FullName AS Approver1_Name, m.ApproveDate_1,
        m.Approver_2, a2.FullName AS Approver2_Name, m.ApproveDate_2,
        m.Approver_3, a3.FullName AS Approver3_Name, m.ApproveDate_3,
        m.Approver_4, a4.FullName AS Approver4_Name, m.ApproveDate_4,
        m.Approver_5, a5.FullName AS Approver5_Name, m.ApproveDate_5,

        ISNULL((
            SELECT COUNT(1)
            FROM tblOTActualDetailNIVS act
            LEFT JOIN tblOTListRegisteredNIVS_Detail p
                ON p.EmployeeID = act.EmployeeID
                AND p.Identity_ID = ISNULL(m.Plan_Identity_ID, (SELECT TOP 1 Identity_ID FROM tblOTListRegisteredNIVS WHERE ((ISNULL(m.IsDivision,0)=0 AND GroupID = m.GroupID) OR (ISNULL(m.IsDivision,0)=1 AND DivisionID = m.DivisionID)) AND @FromDate= OTDateFrom AND @ToDate <= OTDateTo AND Approve_Status = 2 ORDER BY CreateTime DESC))
            WHERE act.Identity_ID = m.Identity_ID
            AND (ISNULL(act.Actual_OTFrom, '') <> ISNULL(p.OTFrom, '') OR ISNULL(act.Actual_OTTo, '') <> ISNULL(p.OTTo, ''))
        ), 0) AS HasRisk_Deviated

    FROM tblOTActualMasterNIVS m
    LEFT JOIN tblGroupTeam g ON m.GroupID = g.GroupTeamID
    LEFT JOIN tblEmployee a1 ON m.Approver_1 = a1.EmployeeID
    LEFT JOIN tblEmployee a2 ON m.Approver_2 = a2.EmployeeID
    LEFT JOIN tblEmployee a3 ON m.Approver_3 = a3.EmployeeID
    LEFT JOIN tblEmployee a4 ON m.Approver_4 = a4.EmployeeID
    LEFT JOIN tblEmployee a5 ON m.Approver_5 = a5.EmployeeID
    WHERE
        m.RegisterBy = @LoginID
        AND m.OTDate >= @FromDate
        AND m.OTDate <= @ToDate
        AND (@Status = -1 OR m.Approve_Status = @Status)
        AND m.Approve_Status <> 0
    ORDER BY m.CreateTime DESC;
END
GO