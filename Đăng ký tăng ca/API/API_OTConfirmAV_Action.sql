
if object_id('[dbo].[API_OTConfirmAV_Action]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTConfirmAV_Action] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTConfirmAV_Action]
    @Identity_ID VARCHAR(100),
    @LoginID VARCHAR(50),
    @Action VARCHAR(20), -- 'APPROVE' hoặc 'REJECT'
    @Remark NVARCHAR(500),
    @LanguageID VARCHAR(2) = 'VN'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @CurrentLevel INT, @Status INT, @TypeRegister INT, @MaxLevel INT;
        DECLARE @ActualEmployeeID VARCHAR(50);

        DECLARE @RegisterBy VARCHAR(50), @GroupID INT, @IsDivision INT, @OTDate DATE;
        DECLARE @App1 VARCHAR(50), @App2 VARCHAR(50), @App3 VARCHAR(50), @App4 VARCHAR(50), @App5 VARCHAR(50);

        SELECT TOP 1 @ActualEmployeeID = LTRIM(RTRIM(EmployeeID))
        FROM tblSc_Login
        WHERE LoginName = @LoginID OR CAST(LoginID AS VARCHAR(50)) = @LoginID;

        SELECT @CurrentLevel = Current_Approved_Level, @Status = Approve_Status, @TypeRegister = ISNULL(TypeRegister, 1),
               @RegisterBy = ISNULL(RegisterBy, ''),
               @GroupID = CASE WHEN ISNULL(IsDivision,0)=1 THEN DivisionID ELSE GroupID END,
               @IsDivision = ISNULL(IsDivision, 0), @OTDate = OTDate,
               @App1 = ISNULL(Approver_1, ''), @App2 = ISNULL(Approver_2, ''),
               @App3 = ISNULL(Approver_3, ''), @App4 = ISNULL(Approver_4, ''), @App5 = ISNULL(Approver_5, '')
        FROM tblOTActualMasterNIVS
        WHERE Identity_ID = @Identity_ID;

        SET @MaxLevel = CASE WHEN @TypeRegister = 2 THEN 5 ELSE 4 END;
        SET @RegisterBy = (SELECT EmployeeID FROM tblSC_Login WHERE LoginID = @RegisterBy);

        DECLARE @GroupName NVARCHAR(250);
        IF @IsDivision = 1 SELECT @GroupName = DivisionName FROM tblDivision WHERE DivisionID = @GroupID;
        ELSE SELECT @GroupName = GroupTeamName FROM tblGroupTeam WHERE GroupTeamID = @GroupID;

        DECLARE @TotalEmp INT, @TotalHours FLOAT;
        SELECT @TotalEmp = COUNT(DISTINCT EmployeeID), @TotalHours = SUM(ISNULL(Actual_OTHours, 0))
        FROM tblOTActualDetailNIVS WHERE Identity_ID = @Identity_ID;

        DECLARE @Recipient VARCHAR(50);
        DECLARE @CurLang VARCHAR(2);
        DECLARE @NotifyText NVARCHAR(MAX);

        IF @Status = 1
        BEGIN
            IF @Action = 'APPROVE'
            BEGIN
                IF @CurrentLevel = 1 UPDATE tblOTActualMasterNIVS SET ApproveDate_1 = GETDATE(), ApproverRemark_1 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 2 UPDATE tblOTActualMasterNIVS SET ApproveDate_2 = GETDATE(), ApproverRemark_2 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 3 UPDATE tblOTActualMasterNIVS SET ApproveDate_3 = GETDATE(), ApproverRemark_3 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 4 UPDATE tblOTActualMasterNIVS SET ApproveDate_4 = GETDATE(), ApproverRemark_4 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 5 UPDATE tblOTActualMasterNIVS SET ApproveDate_5 = GETDATE(), ApproverRemark_5 = @Remark WHERE Identity_ID = @Identity_ID;

                DECLARE @IsFinalLevel BIT = 0;
                IF @TypeRegister = 1 AND (@CurrentLevel >= 4 OR (@CurrentLevel = 3 AND (@App4 IS NULL OR @App4 = '')))
                    SET @IsFinalLevel = 1;
                ELSE IF @TypeRegister = 2 AND (@CurrentLevel >= 5 OR (@CurrentLevel = 4 AND (@App5 IS NULL OR @App5 = '')))
                    SET @IsFinalLevel = 1;

                IF @IsFinalLevel = 0
                BEGIN
                    DECLARE @NextLevel INT = @CurrentLevel + 1;

                    IF @CurrentLevel = 1 AND @App2 = 'SKIP'
                    BEGIN
                        SET @NextLevel = 3; SET @Recipient = @App3;
                        UPDATE tblOTActualMasterNIVS SET ApproveDate_2 = GETDATE(), ApproverRemark_2 = N'Hệ thống tự động bỏ qua do Cấp 2 là Khác' WHERE Identity_ID = @Identity_ID;
                    END
                    ELSE
            BEGIN
                        SET @Recipient = CASE WHEN @CurrentLevel = 1 THEN @App2 WHEN @CurrentLevel = 2 THEN @App3 WHEN @CurrentLevel = 3 THEN @App4 WHEN @CurrentLevel = 4 THEN @App5 END;
                    END

                    UPDATE tblOTActualMasterNIVS SET Current_Approved_Level = @NextLevel WHERE Identity_ID = @Identity_ID;

                    SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient;

                    SET @NotifyText = CASE
                        WHEN @CurLang = 'EN' THEN N'Actual OT confirmation needs approval:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Total OT: ' + CAST(CAST(@TotalHours AS DECIMAL(10,1)) AS VARCHAR) + N'h (' + CAST(@TotalEmp AS VARCHAR) + N' emps)'
                        WHEN @CurLang = 'JP' THEN N'実残業確認の承認待ち:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'合計残業: ' + CAST(CAST(@TotalHours AS DECIMAL(10,1)) AS VARCHAR) + N'h (' + CAST(@TotalEmp AS VARCHAR) + N' 名)'
                        ELSE N'Đơn Xác nhận Tăng ca Thực tế cần duyệt:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Tổng giờ: ' + CAST(CAST(@TotalHours AS DECIMAL(10,1)) AS VARCHAR) + N'h (' + CAST(@TotalEmp AS VARCHAR) + N' NV)'
                    END;
                END
                ELSE
                BEGIN
                    UPDATE tblOTActualMasterNIVS SET Approve_Status = 2 WHERE Identity_ID = @Identity_ID;
                    EXEC API_OTConfirm_PushToFinal @Identity_ID;

                    SET @Recipient = @RegisterBy;
                    SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient;

                    SET @NotifyText = CASE
                        WHEN @CurLang = 'EN' THEN N'Actual OT confirmation is FULLY APPROVED:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Total OT: ' + CAST(CAST(@TotalHours AS DECIMAL(10,1)) AS VARCHAR) + N'h'
                        WHEN @CurLang = 'JP' THEN N'実残業確認が最終承認されました:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'合計残業: ' + CAST(CAST(@TotalHours AS DECIMAL(10,1)) AS VARCHAR) + N'h'
                        ELSE N'Đơn Xác nhận Tăng ca Thực tế ĐÃ ĐƯỢC DUYỆT XONG:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Tổng giờ: ' + CAST(CAST(@TotalHours AS DECIMAL(10,1)) AS VARCHAR) + N'h'
                    END;
                END
            END
            ELSE IF @Action = 'REJECT'
            BEGIN
                IF @CurrentLevel = 1 UPDATE tblOTActualMasterNIVS SET ApproveDate_1 = GETDATE(), ApproverRemark_1 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 2 UPDATE tblOTActualMasterNIVS SET ApproveDate_2 = GETDATE(), ApproverRemark_2 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 3 UPDATE tblOTActualMasterNIVS SET ApproveDate_3 = GETDATE(), ApproverRemark_3 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 4 UPDATE tblOTActualMasterNIVS SET ApproveDate_4 = GETDATE(), ApproverRemark_4 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 5 UPDATE tblOTActualMasterNIVS SET ApproveDate_5 = GETDATE(), ApproverRemark_5 = @Remark WHERE Identity_ID = @Identity_ID;

                UPDATE tblOTActualMasterNIVS SET Approve_Status = 3 WHERE Identity_ID = @Identity_ID;

                SET @Recipient = @RegisterBy;
                SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient;

                SET @NotifyText = CASE
                    WHEN @CurLang = 'EN' THEN N'Actual OT confirmation was REJECTED:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Reason: ' + ISNULL(@Remark, 'N/A')
                    WHEN @CurLang = 'JP' THEN N'実残業確認が却下されました:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'理由: ' + ISNULL(@Remark, 'N/A')
                    ELSE N'Đơn Xác nhận Tăng ca Thực tế ĐÃ BỊ TỪ CHỐI:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Lý do: ' + ISNULL(@Remark, 'Không có')
                END;
            END
        END
        ELSE IF @Status = 5
        BEGIN
            IF @Action = 'APPROVE'
            BEGIN
                IF @CurrentLevel = 1 UPDATE tblOTActualMasterNIVS SET ApproveDate_1 = GETDATE(), ApproverRemark_1 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 2 UPDATE tblOTActualMasterNIVS SET ApproveDate_2 = GETDATE(), ApproverRemark_2 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 3 UPDATE tblOTActualMasterNIVS SET ApproveDate_3 = GETDATE(), ApproverRemark_3 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 4 UPDATE tblOTActualMasterNIVS SET ApproveDate_4 = GETDATE(), ApproverRemark_4 = @Remark WHERE Identity_ID = @Identity_ID;
                ELSE IF @CurrentLevel = 5 UPDATE tblOTActualMasterNIVS SET ApproveDate_5 = GETDATE(), ApproverRemark_5 = @Remark WHERE Identity_ID = @Identity_ID;

                DECLARE @IsCancelFinalLevel BIT = 0;
                IF (@TypeRegister = 1 AND (@CurrentLevel >= 4 OR (@CurrentLevel = 3 AND (@App4 IS NULL OR @App4 = ''))))
                   OR (@TypeRegister = 2 AND (@CurrentLevel >= 5 OR (@CurrentLevel = 4 AND (@App5 IS NULL OR @App5 = ''))))
                    SET @IsCancelFinalLevel = 1;

                IF @IsCancelFinalLevel = 0
                BEGIN
                    DECLARE @NextCancelLevel INT = @CurrentLevel + 1;
                    IF @CurrentLevel = 1 AND @App2 = 'SKIP'
                    BEGIN
                        SET @NextCancelLevel = 3; SET @Recipient = @App3;
                        UPDATE tblOTActualMasterNIVS SET ApproveDate_2 = GETDATE(), ApproverRemark_2 = N'Hệ thống tự động bỏ qua do Cấp 2 là Khác' WHERE Identity_ID = @Identity_ID;
                    END
                    ELSE BEGIN SET @Recipient = CASE WHEN @CurrentLevel = 1 THEN @App2 WHEN @CurrentLevel = 2 THEN @App3 WHEN @CurrentLevel = 3 THEN @App4 WHEN @CurrentLevel = 4 THEN @App5 END; END

                    UPDATE tblOTActualMasterNIVS SET Current_Approved_Level = @NextCancelLevel WHERE Identity_ID = @Identity_ID;

                    SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient;

                    SET @NotifyText = CASE
                        WHEN @CurLang = 'EN' THEN N'Actual OT CANCEL REQUEST needs approval:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103)
                        WHEN @CurLang = 'JP' THEN N'実残業のキャンセル申請 承認待ち:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103)
                        ELSE N'YÊU CẦU HỦY Xác Nhận Thực Tế cần duyệt:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103)
                    END;
                END
                ELSE
                BEGIN
                    UPDATE tblOTActualMasterNIVS SET Approve_Status = 4 WHERE Identity_ID = @Identity_ID;
                    DELETE f FROM tblOTActualFinal f INNER JOIN tblOTActualDetailNIVS d ON f.EmployeeID = d.EmployeeID AND f.OTDate = CAST(d.OTDate AS DATETIME) WHERE d.Identity_ID = @Identity_ID;

                    SET @Recipient = @RegisterBy;
                    SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient;

                    SET @NotifyText = CASE
                        WHEN @CurLang = 'EN' THEN N'Actual OT CANCEL REQUEST is APPROVED:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103)
                        WHEN @CurLang = 'JP' THEN N'実残業のキャンセル申請が承認されました:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103)
                        ELSE N'Yêu cầu Xin Hủy Xác Nhận Thực Tế ĐÃ ĐƯỢC CHẤP THUẬN:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103)
                    END;
                END
            END
            ELSE IF @Action = 'REJECT'
            BEGIN
                UPDATE tblOTActualMasterNIVS
                SET Approve_Status = 2,
                    Current_Approved_Level = @MaxLevel,
                    ApproveDate_1 = ApproveDate_1_Old, ApproverRemark_1 = ApproverRemark_1_Old,
                    ApproveDate_2 = ApproveDate_2_Old, ApproverRemark_2 = ApproverRemark_2_Old,
                    ApproveDate_3 = ApproveDate_3_Old, ApproverRemark_3 = ApproverRemark_3_Old,
                    ApproveDate_4 = ApproveDate_4_Old, ApproverRemark_4 = ApproverRemark_4_Old,
                    ApproveDate_5 = ApproveDate_5_Old, ApproverRemark_5 = ApproverRemark_5_Old
                WHERE Identity_ID = @Identity_ID;

                SET @Recipient = @RegisterBy;
                SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @Recipient OR EmployeeID = @Recipient;

                SET @NotifyText = CASE
                    WHEN @CurLang = 'EN' THEN N'Actual OT CANCEL REQUEST was REJECTED:' + CHAR(10) + N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Date: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Reason: ' + ISNULL(@Remark, 'N/A')
                    WHEN @CurLang = 'JP' THEN N'実残業のキャンセル申請が却下されました:' + CHAR(10) + N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) + N'日付: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'理由: ' + ISNULL(@Remark, 'N/A')
                    ELSE N'Yêu cầu Xin Hủy Xác Nhận Thực Tế ĐÃ BỊ TỪ CHỐI:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Lý do: ' + ISNULL(@Remark, 'Không có')
                END;
            END
        END

        IF ISNULL(@Recipient, '') <> '' AND @Recipient <> 'SKIP'
        BEGIN
            INSERT INTO tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
            VALUES ('Nivs_App_Notify', 0, 1, @Identity_ID, @Recipient, 1, @NotifyText);

            UPDATE Taskschedule set LastTryDay = '20190101', NextRunDate = '20190101' where FunctionName = 'SendPendingEmail';
            EXEC API_LoadNotificationMenu @LoginID = @LoginID;
        END

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