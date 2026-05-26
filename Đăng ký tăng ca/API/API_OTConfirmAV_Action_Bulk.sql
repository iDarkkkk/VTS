if object_id('[dbo].[API_OTConfirmAV_Action_Bulk]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTConfirmAV_Action_Bulk] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTConfirmAV_Action_Bulk]
    @Identity_IDs nvarchar(max),
    @LoginID varchar(50),
    @Action varchar(20),
    @Remark nvarchar(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @value varchar(100);
    DECLARE @pos INT;
    
    SET @Identity_IDs = LTRIM(RTRIM(@Identity_IDs)) + ',';
    SET @pos = CHARINDEX(',', @Identity_IDs, 1);
    
    WHILE @pos > 0
    BEGIN
        SET @value = LTRIM(RTRIM(SUBSTRING(@Identity_IDs, 1, @pos - 1)));
        
        IF @value <> ''
        BEGIN
            EXEC [dbo].[API_OTConfirmAV_Action] @Identity_ID = @value, @LoginID = @LoginID, @Action = @Action, @Remark = @Remark;
        END
        
        SET @Identity_IDs = SUBSTRING(@Identity_IDs, @pos + 1, LEN(@Identity_IDs));
        SET @pos = CHARINDEX(',', @Identity_IDs, 1);
    END
    
    SELECT 'success' AS result, N'Thao tác hàng loạt thành công' AS reason;
END
GO
