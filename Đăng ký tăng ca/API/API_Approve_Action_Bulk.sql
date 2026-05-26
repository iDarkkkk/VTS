ALTER PROCEDURE [dbo].[API_Approve_Action_Bulk]
    @Identity_IDs nvarchar(max),
    @LoginID varchar(50),
    @Action varchar(20),
    @Remark nvarchar(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @value varchar(100);
    DECLARE @pos INT;

    CREATE TABLE #TempResult (
        result varchar(50),
        reason nvarchar(max)
    );
    
    SET @Identity_IDs = LTRIM(RTRIM(@Identity_IDs)) + ',';
    SET @pos = CHARINDEX(',', @Identity_IDs, 1);
    
    WHILE @pos > 0
    BEGIN
        SET @value = LTRIM(RTRIM(SUBSTRING(@Identity_IDs, 1, @pos - 1)));
        
        IF @value <> ''
        BEGIN
            INSERT INTO #TempResult (result, reason)
            EXEC [dbo].[API_Approve_Action] @Identity_ID = @value, @LoginID = @LoginID, @Action = @Action, @Remark = @Remark, @ModifiedJSON = NULL;
        END
        
        SET @Identity_IDs = SUBSTRING(@Identity_IDs, @pos + 1, LEN(@Identity_IDs));
        SET @pos = CHARINDEX(',', @Identity_IDs, 1);
    END
    
    DROP TABLE #TempResult;
    
    SELECT 'success' AS result, N'Thao tác hàng loạt thành công' AS reason;
END
GO
