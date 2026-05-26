USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTConfirmAV_GetList]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTConfirmAV_GetList] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTConfirmAV_GetList]
    @LoginID VARCHAR(50),
    @FromDate DATE,
    @ToDate DATE,
    @Status INT,            -- -1: All, 1: Chờ duyệt, 2: Đã duyệt, 3: Từ chối
    @TypeRegister INT = -1  -- -1: All, 1: Ngày thường, 2: Ngày nghỉ/lễ
AS
BEGIN
    SET NOCOUNT ON;

    -- Bẫy Logic: Vượt rào ngày tháng cho đơn chờ duyệt (@Status = 1)
    -- Nếu lọc đơn chờ duyệt, lấy sạch sành sanh không kể ngày tháng.
    -- Nếu lọc đơn khác, áp dụng range ngày.
    
    DECLARE @ActualFrom DATE = CASE WHEN @Status = 1 THEN '2000-01-01' ELSE @FromDate END;
    DECLARE @ActualTo DATE = CASE WHEN @Status = 1 THEN '2099-12-31' ELSE @ToDate END;

    SELECT 
        m.Identity_ID,
        m.OTDate,
        m.TypeRegister,
        m.GroupID,
        m.DivisionID,
        m.IsDivision,
        m.Approve_Status,
        m.Current_Approved_Level,
        m.Remark,
        m.RegisterBy,
        concat(e_reg.EmployeeID, ' - ', e_reg.FullName) AS CreatorName,
        m.CreateTime,
        
        CASE WHEN ISNULL(m.IsDivision, 0) = 1 THEN ISNULL((SELECT DivisionName FROM tblDivision WHERE DivisionID = m.DivisionID), 'N/A')
             ELSE ISNULL(g.GroupTeamName, 'N/A') END AS GroupName,

        -- Đếm số nhân viên và tổng giờ
        ISNULL((SELECT COUNT(1) FROM tblOTActualDetailNIVS d WHERE d.Identity_ID = m.Identity_ID), 0) AS TotalEmployees,
        ISNULL((SELECT SUM(ISNULL(d.OTHours, 0)) FROM tblOTActualDetailNIVS d WHERE d.Identity_ID = m.Identity_ID), 0) AS TotalHours,
        
        -- Đếm số ca lệch rủi ro (Risk) so với kế hoạch
        ISNULL((
            SELECT COUNT(1)
            FROM tblOTActualDetailNIVS act
            LEFT JOIN tblOTListRegisteredNIVS_Detail p 
                ON p.EmployeeID = act.EmployeeID 
                AND p.Identity_ID = m.Plan_Identity_ID
            WHERE act.Identity_ID = m.Identity_ID
            AND (ISNULL(act.Actual_OTFrom, '') <> ISNULL(p.OTFrom, '') OR ISNULL(act.Actual_OTTo, '') <> ISNULL(p.OTTo, ''))
        ), 0) AS RiskEmployeesCount,

        -- Cờ xác định có phải đến lượt User này duyệt hay không
        CASE WHEN 
            (@Status = 1 AND (
                (m.Current_Approved_Level = 1 AND m.Approver_1 = @LoginID) OR
                (m.Current_Approved_Level = 2 AND m.Approver_2 = @LoginID) OR
                (m.Current_Approved_Level = 3 AND m.Approver_3 = @LoginID) OR
                (m.Current_Approved_Level = 4 AND m.Approver_4 = @LoginID) OR
                (m.Current_Approved_Level = 5 AND m.Approver_5 = @LoginID)
            )) THEN 1 ELSE 0 END AS IsMyTurnToApprove,
            
        -- Thông tin người duyệt
        m.Approver_1, a1.FullName AS Approver1_Name, m.ApproveDate_1, m.ApproverRemark_1,
        m.Approver_2, a2.FullName AS Approver2_Name, m.ApproveDate_2, m.ApproverRemark_2,
        m.Approver_3, a3.FullName AS Approver3_Name, m.ApproveDate_3, m.ApproverRemark_3,
        m.Approver_4, a4.FullName AS Approver4_Name, m.ApproveDate_4, m.ApproverRemark_4,
        m.Approver_5, a5.FullName AS Approver5_Name, m.ApproveDate_5, m.ApproverRemark_5

    FROM tblOTActualMasterNIVS m
    LEFT JOIN tblSC_Login sc ON m.RegisterBy = sc.LoginID
    LEFT JOIN tblEmployee e_reg ON sc.EmployeeID = e_reg.EmployeeID
    LEFT JOIN tblGroupTeam g ON m.GroupID = g.GroupTeamID
    LEFT JOIN tblEmployee a1 ON m.Approver_1 = a1.EmployeeID
    LEFT JOIN tblEmployee a2 ON m.Approver_2 = a2.EmployeeID
    LEFT JOIN tblEmployee a3 ON m.Approver_3 = a3.EmployeeID
    LEFT JOIN tblEmployee a4 ON m.Approver_4 = a4.EmployeeID
    LEFT JOIN tblEmployee a5 ON m.Approver_5 = a5.EmployeeID
    
    WHERE 
        m.OTDate >= @ActualFrom 
        AND m.OTDate <= @ActualTo
        AND (@Status = -1 OR m.Approve_Status = @Status)
        AND (@TypeRegister = -1 OR m.TypeRegister = @TypeRegister)
        AND (
            -- User này là 1 trong các người duyệt
            m.Approver_1 = @LoginID OR 
            m.Approver_2 = @LoginID OR 
            m.Approver_3 = @LoginID OR 
            m.Approver_4 = @LoginID OR 
            m.Approver_5 = @LoginID
        )
    ORDER BY m.CreateTime DESC;
END
GO
