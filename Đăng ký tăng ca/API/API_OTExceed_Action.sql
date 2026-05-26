
if object_id('[dbo].[API_OTExceed_Action]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTExceed_Action] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTExceed_Action]
    @Identity_ID VARCHAR(100),
    @LoginID VARCHAR(50),
    @Action VARCHAR(20), -- 'APPROVE' hoặc 'REJECT'
    @Remark NVARCHAR(500),
    @LanguageID VARCHAR(2) = 'VN'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @CurrentLevel INT, @Status INT, @TypeRegister INT, @MaxLevel INT = 4;
        DECLARE @ActualEmployeeID VARCHAR(50);

        DECLARE @RegisterBy VARCHAR(50), @GroupID INT, @IsDivision INT, @OTDate DATE;
        DECLARE @App1 VARCHAR(50), @App2 VARCHAR(50), @App3 VARCHAR(50), @App4 VARCHAR(50);

        SELECT TOP 1 @ActualEmployeeID = LTRIM(RTRIM(EmployeeID)) FROM tblSc_Login WHERE LoginName = @LoginID OR CAST(LoginID AS VARCHAR(50)) = @LoginID;

        SELECT @CurrentLevel = Current_Approved_Level, @Status = Approve_Status, @TypeRegister = ISNULL(TypeRegister, 1),
               @RegisterBy = ISNULL(RegisterBy, ''),
               @GroupID = CASE WHEN ISNULL(IsDivision,0)=1 THEN DivisionID ELSE GroupID END,
               @IsDivision = ISNULL(IsDivision, 0), @OTDate = OTDate,
               @App1 = ISNULL(Approver_1, ''), @App2 = ISNULL(Approver_2, ''), @App3 = ISNULL(Approver_3, ''),
               @App4 = ISNULL(Approver_4, '')
        FROM tblOTExceedMasterNIVS WHERE Identity_ID = @Identity_ID;

        SET @MaxLevel = 4;
        IF NULLIF(LTRIM(RTRIM(@App4)), '') IS NULL SET @MaxLevel = 3;
        IF NULLIF(LTRIM(RTRIM(@App3)), '') IS NULL AND @MaxLevel = 3 SET @MaxLevel = 2;

        set @RegisterBy = (select EmployeeID from tblSC_Login where LoginID = @RegisterBy)
        DECLARE @GroupName NVARCHAR(250);
        IF @IsDivision = 1 SELECT @GroupName = DivisionName FROM tblDivision WHERE DivisionID = @GroupID;
        ELSE SELECT @GroupName = GroupTeamName FROM tblGroupTeam WHERE GroupTeamID = @GroupID;

        DECLARE @TotalEmp INT;
        SELECT @TotalEmp = COUNT(DISTINCT EmployeeID) FROM tblOTExceedDetailNIVS WHERE Identity_ID = @Identity_ID;

        DECLARE @Recipient VARCHAR(50) = NULL;
        DECLARE @CurLang VARCHAR(2) = 'VN';
        DECLARE @NotifyText NVARCHAR(MAX) = '';

        IF @Status = 1
        BEGIN
            IF @Action = 'APPROVE'
            BEGIN
                IF @CurrentLevel = 1 UPDATE tblOTExceedMasterNIVS SET ApproveDate_1 = GETDATE(), ApproverRemark_1 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 2 UPDATE tblOTExceedMasterNIVS SET ApproveDate_2 = GETDATE(), ApproverRemark_2 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 3 UPDATE tblOTExceedMasterNIVS SET ApproveDate_3 = GETDATE(), ApproverRemark_3 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 4 UPDATE tblOTExceedMasterNIVS SET ApproveDate_4 = GETDATE(), ApproverRemark_4 = @Remark WHERE Identity_ID = @Identity_ID;

                IF @CurrentLevel < @MaxLevel
                BEGIN
                    DECLARE @NextLevel INT = @CurrentLevel + 1;

                    IF @CurrentLevel = 1 AND @App2 = 'SKIP'
                    BEGIN
                        SET @NextLevel = 3;
                        SET @Recipient = @App3;
                        UPDATE tblOTExceedMasterNIVS SET ApproveDate_2 = GETDATE(), ApproverRemark_2 = N'Hệ thống tự động bỏ qua do Cấp 2 là Khác' WHERE Identity_ID = @Identity_ID;
                    END
                    ELSE
                    BEGIN
                        SET @Recipient = CASE WHEN @CurrentLevel = 1 THEN @App2 WHEN @CurrentLevel = 2 THEN @App3 WHEN @CurrentLevel = 3 THEN @App4 END;
                    END

                    UPDATE tblOTExceedMasterNIVS SET Current_Approved_Level = @NextLevel WHERE Identity_ID = @Identity_ID;

                    SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient OR CAST(LoginID AS VARCHAR(50)) = @Recipient;

             SET @NotifyText = CASE
                        WHEN @CurLang = 'EN' THEN N'OT Limit Exceed request needs approval:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103)
                        WHEN @CurLang = 'JP' THEN N'超過残業申請の承認待ち:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103)
                        ELSE N'Đơn ĐK Vượt Định Mức OT cần duyệt:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103)
                    END;
                END
                ELSE
                BEGIN
                    UPDATE tblOTExceedMasterNIVS SET Approve_Status = 2 WHERE Identity_ID = @Identity_ID;
                    UPDATE tblOTExceedDetailNIVS SET Approve_Status = 2 WHERE Identity_ID = @Identity_ID;

                    SET @Recipient = @RegisterBy;
                    SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient OR CAST(LoginID AS VARCHAR(50)) = @Recipient;

                    SET @NotifyText = CASE
                        WHEN @CurLang = 'EN' THEN N'OT Limit Exceed request is FULLY APPROVED:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103)
                        WHEN @CurLang = 'JP' THEN N'超過残業申請が最終承認されました:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103)
                        ELSE N'Đơn ĐK Vượt Định Mức OT ĐÃ ĐƯỢC DUYỆT XONG:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103)
                    END;
                END
            END
            ELSE IF @Action = 'REJECT'
            BEGIN
                IF @CurrentLevel = 1 UPDATE tblOTExceedMasterNIVS SET ApproveDate_1 = GETDATE(), ApproverRemark_1 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 2 UPDATE tblOTExceedMasterNIVS SET ApproveDate_2 = GETDATE(), ApproverRemark_2 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 3 UPDATE tblOTExceedMasterNIVS SET ApproveDate_3 = GETDATE(), ApproverRemark_3 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 4 UPDATE tblOTExceedMasterNIVS SET ApproveDate_4 = GETDATE(), ApproverRemark_4 = @Remark WHERE Identity_ID = @Identity_ID;

                UPDATE tblOTExceedMasterNIVS SET Approve_Status = 3 WHERE Identity_ID = @Identity_ID;
                UPDATE tblOTExceedDetailNIVS SET Approve_Status = 3 WHERE Identity_ID = @Identity_ID;

                SET @Recipient = @RegisterBy;
                SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient OR CAST(LoginID AS VARCHAR(50)) = @Recipient;

                SET @NotifyText = CASE
                    WHEN @CurLang = 'EN' THEN N'OT Limit Exceed request was REJECTED:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Reason: ' + ISNULL(@Remark, 'N/A')
                    WHEN @CurLang = 'JP' THEN N'超過残業申請が却下されました:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'理由: ' + ISNULL(@Remark, 'N/A')
                    ELSE N'Đơn ĐK Vượt Định Mức OT ĐÃ BỊ TỪ CHỐI:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Lý do: ' + ISNULL(@Remark, 'Không có')
                END;
            END
        END
        ELSE IF @Status = 5
        BEGIN
            IF @Action = 'APPROVE'
            BEGIN
                IF @CurrentLevel = 1 UPDATE tblOTExceedMasterNIVS SET ApproveDate_1 = GETDATE(), ApproverRemark_1 = @Remark WHERE Identity_ID = @Identity_ID;
         ELSE IF @CurrentLevel = 2 UPDATE tblOTExceedMasterNIVS SET ApproveDate_2 = GETDATE(), ApproverRemark_2 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 3 UPDATE tblOTExceedMasterNIVS SET ApproveDate_3 = GETDATE(), ApproverRemark_3 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 4 UPDATE tblOTExceedMasterNIVS SET ApproveDate_4 = GETDATE(), ApproverRemark_4 = @Remark WHERE Identity_ID = @Identity_ID;

                DECLARE @IsCancelFinalLevel BIT = 0;
                IF @CurrentLevel >= @MaxLevel SET @IsCancelFinalLevel = 1;

                IF @IsCancelFinalLevel = 0
                BEGIN
                    DECLARE @NextCancelLevel INT = @CurrentLevel + 1;
                    IF @CurrentLevel = 1 AND @App2 = 'SKIP'
                    BEGIN
                        SET @NextCancelLevel = 3; SET @Recipient = @App3;
                        UPDATE tblOTExceedMasterNIVS SET ApproveDate_2 = GETDATE(), ApproverRemark_2 = N'Hệ thống tự động bỏ qua do Cấp 2 là Khác' WHERE Identity_ID = @Identity_ID;
                    END
                    ELSE BEGIN SET @Recipient = CASE WHEN @CurrentLevel = 1 THEN @App2 WHEN @CurrentLevel = 2 THEN @App3 WHEN @CurrentLevel = 3 THEN @App4 END; END

                    UPDATE tblOTExceedMasterNIVS SET Current_Approved_Level = @NextCancelLevel WHERE Identity_ID = @Identity_ID;

                    SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient OR CAST(LoginID AS VARCHAR(50)) = @Recipient;

                    SET @NotifyText = CASE
                        WHEN @CurLang = 'EN' THEN N'OT Limit Exceed CANCEL REQUEST needs approval:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103)
                        WHEN @CurLang = 'JP' THEN N'超過残業のキャンセル申請 承認待ち:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103)
                        ELSE N'YÊU CẦU HỦY Đơn Vượt Định Mức cần duyệt:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103)
                    END;
                END
                ELSE
                BEGIN
                    UPDATE tblOTExceedMasterNIVS SET Approve_Status = 4 WHERE Identity_ID = @Identity_ID;
                    UPDATE tblOTExceedDetailNIVS SET Approve_Status = 4 WHERE Identity_ID = @Identity_ID;

                    SET @Recipient = @RegisterBy;
                    SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient OR CAST(LoginID AS VARCHAR(50)) = @Recipient;

                    SET @NotifyText = CASE
                        WHEN @CurLang = 'EN' THEN N'OT Limit Exceed CANCEL REQUEST is APPROVED:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103)
                        WHEN @CurLang = 'JP' THEN N'超過残業のキャンセル申請が承認されました:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103)
                        ELSE N'Yêu cầu Xin Hủy Đơn Vượt Định Mức ĐÃ ĐƯỢC CHẤP THUẬN:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103)
                    END;
                END
            END
            ELSE IF @Action = 'REJECT'
            BEGIN
                UPDATE tblOTExceedMasterNIVS
                SET Approve_Status = 2, Current_Approved_Level = @MaxLevel,
                    ApproveDate_1 = ApproveDate_1_Old, ApproverRemark_1 = ApproverRemark_1_Old,
                    ApproveDate_2 = ApproveDate_2_Old, ApproverRemark_2 = ApproverRemark_2_Old,
                    ApproveDate_3 = ApproveDate_3_Old, ApproverRemark_3 = ApproverRemark_3_Old,
                    ApproveDate_4 = ApproveDate_4_Old, ApproverRemark_4 = ApproverRemark_4_Old
                WHERE Identity_ID = @Identity_ID;

                UPDATE tblOTExceedDetailNIVS SET Approve_Status = 2 WHERE Identity_ID = @Identity_ID;

                SET @Recipient = @RegisterBy;
                SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient OR CAST(LoginID AS VARCHAR(50)) = @Recipient;

                SET @NotifyText = CASE
                    WHEN @CurLang = 'EN' THEN N'OT Limit Exceed CANCEL REQUEST was REJECTED:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Reason: ' + ISNULL(@Remark, 'N/A')
                    WHEN @CurLang = 'JP' THEN N'超過残業のキャンセル申請が却下されました:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'理由: ' + ISNULL(@Remark, 'N/A')
                    ELSE N'Yêu cầu Xin Hủy Đơn Vượt Định Mức ĐÃ BỊ TỪ CHỐI:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Lý do: ' + ISNULL(@Remark, 'Không có')
                END;
            END
        END

        IF ISNULL(@Recipient, '') <> '' AND @Recipient <> 'SKIP'
        BEGIN
            INSERT INTO tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
            VALUES ('Nivs_App_Notify', 0, 1, @Identity_ID, @Recipient, 1, @NotifyText);
        END

        UPDATE Taskschedule set LastTryDay = '20190101', NextRunDate = '20190101' where FunctionName = 'SendPendingEmail';

        DECLARE @MsgSuccess NVARCHAR(200) = CASE
            WHEN @LanguageID = 'EN' THEN N'Action processed successfully!'
            WHEN @LanguageID = 'JP' THEN N'正常に処理されました！'
            ELSE N'Xử lý thao tác thành công!'
        END;
        SELECT 'success' AS result, @MsgSuccess AS reason;

    END TRY
    BEGIN CATCH
        SELECT 'error' AS result, ERROR_MESSAGE() AS reason;
    END CATCH
END
GO