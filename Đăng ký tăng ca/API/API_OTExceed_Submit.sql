USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTExceed_Submit]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTExceed_Submit] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTExceed_Submit]
    @TargetID INT,
    @OTDate DATE,
    @LoginID VARCHAR(50),
    @Approver1 VARCHAR(50),
    @Approver2 VARCHAR(50),
    @Approver3 VARCHAR(50),
    @Remark NVARCHAR(500),
    @JSONData NVARCHAR(MAX),
    @IsDivision INT = 0,
    @LanguageID VARCHAR(2) = 'VN'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;



        DECLARE @GroupID INT = CASE WHEN @IsDivision = 0 THEN @TargetID ELSE NULL END;
        DECLARE @DivisionID INT = CASE WHEN @IsDivision = 1 THEN @TargetID ELSE NULL END;

        DECLARE @TypeReg INT = 1;
        SELECT TOP 1 @TypeReg = ISNULL(TypeRegister, 1)
        FROM tblOTListRegisteredNIVS
        WHERE ISNULL(GroupID, 0) = ISNULL(@GroupID, 0) AND ISNULL(DivisionID, 0) = ISNULL(@DivisionID, 0)
          AND @OTDate >= OTDateFrom AND @OTDate <= OTDateTo AND Approve_Status = 2;

        IF @TypeReg IS NULL SET @TypeReg = 1;

        DECLARE @NewID VARCHAR(100) = NEWID();
        DECLARE @StartLevel INT = 1;
        DECLARE @D1 DATETIME = NULL, @R1 NVARCHAR(200) = NULL;

        IF @Approver1 = 'SKIP'
        BEGIN
            SET @StartLevel = 2; SET @D1 = GETDATE();
            SET @R1 = CASE
                WHEN @LanguageID = 'EN' THEN N'System automatically skipped because there is no Level 1'
                WHEN @LanguageID = 'JP' THEN N'1次承認者がいないため、システムが自動スキップしました'
                ELSE N'Hệ thống tự động bỏ qua do không có Cấp 1'
            END;
        END

        INSERT INTO tblOTExceedMasterNIVS (Identity_ID, GroupID, DivisionID, IsDivision, OTDate, RegisterBy, CreateTime, Approve_Status, Current_Approved_Level, TypeRegister, Approver_1, ApproveDate_1, ApproverRemark_1, Approver_2, Approver_3, Remark)
        VALUES (@NewID, @GroupID, @DivisionID, @IsDivision, @OTDate, @LoginID, GETDATE(), 1, @StartLevel, @TypeReg, @Approver1, @D1, @R1, @Approver2, @Approver3, @Remark);

        SELECT EmployeeID, LimitType, CurrentTotalOT, PlannedOT_Hours
        INTO #tmpExceedData
        FROM OPENJSON(@JSONData)
        WITH (
            EmployeeID VARCHAR(50) '$.EmployeeID',
            LimitType NVARCHAR(100) '$.LimitType',
            CurrentTotalOT FLOAT '$.CurrentTotalOT',
            PlannedOT_Hours FLOAT '$.PlannedOT_Hours'
        );

        INSERT INTO tblOTExceedDetailNIVS (Identity_ID, EmployeeID, LimitType, CurrentTotalOT, PlannedOT_Hours, ApprovedOT_Hours, Approve_Status, IsIndirectEmp, DivisionID)
        SELECT @NewID, EmployeeID, LimitType, CurrentTotalOT, PlannedOT_Hours, PlannedOT_Hours, 1, @IsDivision, @DivisionID
        FROM #tmpExceedData;

        DECLARE @GroupName NVARCHAR(250);
        IF @IsDivision = 1
            SELECT @GroupName = DivisionName FROM tblDivision WHERE DivisionID = @TargetID;
        ELSE
            SELECT @GroupName = GroupTeamName FROM tblGroupTeam WHERE GroupTeamID = @TargetID;

        DECLARE @TotalEmp INT;
        SELECT @TotalEmp = COUNT(DISTINCT EmployeeID) FROM #tmpExceedData;

        DECLARE @NextApprover VARCHAR(50) = CASE WHEN @Approver1 = 'SKIP' THEN @Approver2 ELSE @Approver1 END;

        DECLARE @CurLang VARCHAR(2) = 'VN';
        IF ISNULL(@NextApprover, '') <> '' AND @NextApprover <> 'SKIP'
        BEGIN
            SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN')
            FROM tblSC_Login
            WHERE LoginID = @NextApprover OR EmployeeID = @NextApprover OR CAST(LoginID AS VARCHAR(50)) = @NextApprover;
        END

        DECLARE @NotifyText NVARCHAR(MAX);

        SET @NotifyText = CASE
            WHEN @CurLang = 'EN' THEN
                N'OT Limit Exceed Request needs approval:' + CHAR(10) +
                N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) +
                N'Date: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                N'Emps exceeding limit: ' + CAST(@TotalEmp AS VARCHAR) + N' people' + CHAR(10) +
                N'Reason: ' + ISNULL(@Remark, 'N/A')
            WHEN @CurLang = 'JP' THEN
                N'超過残業申請の承認待ち:' + CHAR(10) +
                N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) +
                N'日付: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                N'超過対象者: ' + CAST(@TotalEmp AS VARCHAR) + N' 名' + CHAR(10) +
                N'理由: ' + ISNULL(@Remark, 'N/A')
            ELSE
                N'Đơn ĐK Vượt Định Mức OT cần duyệt:' + CHAR(10) +
                N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) +
                N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                N'Nhân viên vượt: ' + CAST(@TotalEmp AS VARCHAR) + N' người' + CHAR(10) +
                N'Lý do: ' + ISNULL(@Remark, 'Không có')
        END;

        IF ISNULL(@NextApprover, '') <> '' AND @NextApprover <> 'SKIP'
        BEGIN
            INSERT INTO tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
            VALUES ('Nivs_App_Notify', 0, 1, @NewID, @NextApprover, 1, @NotifyText);
        END

        UPDATE Taskschedule set LastTryDay = '20190101', NextRunDate = '20190101' where FunctionName = 'SendPendingEmail'


        DROP TABLE #tmpExceedData;

        COMMIT TRANSACTION;
        DECLARE @MsgSuccess NVARCHAR(200) = CASE
            WHEN @LanguageID = 'EN' THEN N'Exceed Limit request submitted successfully!'
            WHEN @LanguageID = 'JP' THEN N'超過残業申請の送信に成功しました！'
            ELSE N'Gửi đăng ký Vượt định mức thành công!'
        END;
        SELECT 'success' AS result, @MsgSuccess AS reason;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 'error' AS result, ERROR_MESSAGE() AS reason;
    END CATCH
END
GO