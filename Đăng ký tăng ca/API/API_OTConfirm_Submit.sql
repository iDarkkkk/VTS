USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTConfirm_Submit]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTConfirm_Submit] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTConfirm_Submit]
    @Identity_ID VARCHAR(100),
    @TargetID INT,
    @RegisterBy VARCHAR(50),
    @TypeRegister INT,
    @OTDate DATE,
    @Approver1 VARCHAR(50),
    @Approver2 VARCHAR(50),
    @Approver3 VARCHAR(50),
    @Approver4 VARCHAR(50),
    @Approver5 VARCHAR(50),
    @Remark NVARCHAR(500),
    @JSONData NVARCHAR(MAX),
    @IsDivision INT = 0,
    @LanguageID VARCHAR(2) = 'VN'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @StartLevel INT = 1;
        DECLARE @D1 DATETIME = NULL, @R1 NVARCHAR(200) = NULL;
        DECLARE @D2 DATETIME = NULL, @R2 NVARCHAR(200) = NULL;

        DECLARE @GroupID INT = CASE WHEN @IsDivision = 0 THEN @TargetID ELSE NULL END;
        DECLARE @DivisionID INT = CASE WHEN @IsDivision = 1 THEN @TargetID ELSE NULL END;

        IF @Approver1 = 'SKIP'
        BEGIN
            SET @StartLevel = 2;
            SET @D1 = GETDATE();
            SET @R1 = CASE
                WHEN @LanguageID = 'EN' THEN N'System automatically skipped because there is no Level 1'
                WHEN @LanguageID = 'JP' THEN N'1次承認者がいないため、システムが自動スキップしました'
                ELSE N'Hệ thống tự động bỏ qua do không có Cấp 1'
            END;
        END

        UPDATE tblOTActualMasterNIVS
        SET Approver_1 = @Approver1, Approver_2 = @Approver2, Approver_3 = @Approver3, Approver_4 = @Approver4, Approver_5 = @Approver5,
            Remark = @Remark,
            RegisterBy = @RegisterBy,
            Approve_Status = 1, Current_Approved_Level = @StartLevel,
            ApproveDate_1 = @D1, ApproverRemark_1 = @R1,
            ApproveDate_2 = @D2, ApproverRemark_2 = @R2,
            GroupID = @GroupID, DivisionID = @DivisionID, IsDivision = @IsDivision,
            TypeRegister = @TypeRegister, OTDate = @OTDate
        WHERE Identity_ID = @Identity_ID;

        DELETE FROM tblOTActualDetailNIVS WHERE Identity_ID = @Identity_ID;

        SELECT EmployeeID, ActualFrom, ActualTo, Actual_OTHours, TargetID, IsExtraEmp, IsIndirectEmp
        INTO #tmpOTData
        FROM OPENJSON(@JSONData)
        WITH (
            EmployeeID VARCHAR(50) '$.EmployeeID',
            ActualFrom VARCHAR(10) '$.ActualFrom',
            ActualTo VARCHAR(10) '$.ActualTo',
            Actual_OTHours FLOAT '$.Actual_OTHours',
            TargetID INT '$.TargetID',
            IsExtraEmp INT '$.IsExtraEmp',
            IsIndirectEmp INT '$.IsIndirectEmp'
        );

        INSERT INTO tblOTActualDetailNIVS (
            Identity_ID, EmployeeID, OTDate,
            Planned_OTFrom, Planned_OTTo,
            Actual_OTFrom, Actual_OTTo,
            Actual_OTHours,
            Approve_Status, ShiftID, DivisionID, IsIndirectEmp
        )
        SELECT
            @Identity_ID, jd.EmployeeID, @OTDate,
            p.OTFrom AS Planned_OTFrom, p.OTTo AS Planned_OTTo,
            CASE WHEN jd.ActualFrom = '' THEN NULL ELSE jd.ActualFrom END AS Actual_OTFrom,
            CASE WHEN jd.ActualTo = '' THEN NULL ELSE jd.ActualTo END AS Actual_OTTo,
            jd.Actual_OTHours,
            0 AS Approve_Status, p.ShiftID,
            CASE WHEN jd.IsIndirectEmp = 1 THEN @DivisionID ELSE NULL END AS DivisionID,
            jd.IsIndirectEmp
        FROM #tmpOTData jd
        OUTER APPLY (
            SELECT TOP 1 pd.OTFrom, pd.OTTo, pd.ShiftID
            FROM tblOTListRegisteredNIVS_Detail pd
            INNER JOIN tblOTListRegisteredNIVS pm ON pd.Identity_ID = pm.Identity_ID
            WHERE pd.EmployeeID = jd.EmployeeID
              AND CAST(pd.OTDate AS DATE) = CAST(@OTDate AS DATE)
              AND pm.Approve_Status = 2
              AND ((@IsDivision = 0 AND pm.GroupID = @TargetID) OR (@IsDivision = 1 AND pm.DivisionID = @TargetID))
            ORDER BY pm.CreateTime DESC
        ) p;


        DECLARE @GroupName NVARCHAR(250);
        IF @IsDivision = 1
            SELECT @GroupName = DivisionName FROM tblDivision WHERE DivisionID = @TargetID;
        ELSE
            SELECT @GroupName = GroupTeamName FROM tblGroupTeam WHERE GroupTeamID = @TargetID;

        DECLARE @TotalEmp INT, @TotalHours FLOAT;
        SELECT @TotalEmp = COUNT(DISTINCT EmployeeID), @TotalHours = SUM(ISNULL(Actual_OTHours, 0))
        FROM #tmpOTData;

        DECLARE @NextApprover VARCHAR(50) = CASE WHEN @Approver1 = 'SKIP' THEN @Approver2 ELSE @Approver1 END;

        DECLARE @CurLang VARCHAR(2) = 'VN';
        IF ISNULL(@NextApprover, '') <> '' AND @NextApprover <> 'SKIP'
        BEGIN
            SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN')
            FROM tblSC_Login
            WHERE LoginID = @NextApprover OR EmployeeID = @NextApprover;
        END

        DECLARE @NotifyText NVARCHAR(MAX);

        SET @NotifyText = CASE
            WHEN @CurLang = 'EN' THEN
                N'Actual OT confirmation needs approval:' + CHAR(10) +
                N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) +
                N'Date: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                N'Emps: ' + CAST(@TotalEmp AS VARCHAR) + N' people' + CHAR(10) +
                N'Total OT: ' + CAST(CAST(@TotalHours AS DECIMAL(10,1)) AS VARCHAR) + N'h'
            WHEN @CurLang = 'JP' THEN
                N'実残業確認の承認待ち:' + CHAR(10) +
                N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) +
                N'日付: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                N'対象者: ' + CAST(@TotalEmp AS VARCHAR) + N' 名' + CHAR(10) +
                N'合計残業: ' + CAST(CAST(@TotalHours AS DECIMAL(10,1)) AS VARCHAR) + N'h'
            ELSE
                N'Đơn Xác nhận Tăng ca Thực tế cần duyệt:' + CHAR(10) +
                N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) +
                N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                N'Nhân viên: ' + CAST(@TotalEmp AS VARCHAR) + N' người' + CHAR(10) +
                N'Tổng giờ: ' + CAST(CAST(@TotalHours AS DECIMAL(10,1)) AS VARCHAR) + N'h'
        END;

        IF ISNULL(@NextApprover, '') <> '' AND @NextApprover <> 'SKIP'
        BEGIN
            INSERT INTO tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
            VALUES ('Nivs_App_Notify', 0, 1, @Identity_ID, @NextApprover, 1, @NotifyText);
        END

        -- Kích hoạt job gửi mail
        UPDATE Taskschedule set LastTryDay = '20190101', NextRunDate = '20190101' where FunctionName = 'SendPendingEmail'

        -- =========================================================================

        DROP TABLE #tmpOTData;

        COMMIT TRANSACTION;
        SELECT 'success' AS result, N'Gửi xác nhận thành công!' AS reason;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 'error' AS result, ERROR_MESSAGE() AS reason;
    END CATCH
END
GO