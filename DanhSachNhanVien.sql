USE Paradise_NIVS
GO
if object_id('[dbo].[HR_EmployeeList]') is null
 EXEC ('CREATE PROCEDURE [dbo].[HR_EmployeeList] as select 1')
GO
ALTER PROCEDURE [dbo].[HR_EmployeeList](
 @FromDate date=null,
 @ToDate date=null,
 @EmployeeStatusID int = null,
 @DivisionID int = null,
 @PositionID int = null,
 @WorkTypeID int = null,
 @IsFilterHireDate bit = 0,
  @LoginID int = 3
,@LanguageID varchar(2) = 'VN'
)
as
if @ToDate is null
set @ToDate = GETDATE()
declare @ViewDate date = @ToDate
select * into #vtblEmployeeList_Bydate from dbo.fn_vtblEmployeeList_Bydate(@ViewDate,'-1',@LoginID) te

SELECT  E.EmployeeID , E.FullName,
            CASE WHEN E.Sex = 0 THEN N'Nữ' WHEN E.Sex = 1 THEN N'Nam' ELSE '' END AS GioiTinh,
             CONVERT(varchar(10), E.Birthday, 103) as BirthDay,CONVERT(varchar(10), E.HireDate, 103) HireDate,
            P.PositionName,Div.DivisionName,Dep.DepartmentName, Sec.SectionName, G.GroupName, un.UnitName,
            E.EducationalBase,
            (ISNULL(E.ResidentAdd, '') +
             CASE WHEN E.Ward IS NOT NULL AND E.Ward <> '' THEN ', ' + E.Ward ELSE '' END +
             CASE WHEN D_Res.DistrictName IS NOT NULL THEN ', ' + D_Res.DistrictName ELSE '' END +
             CASE WHEN P_Res.ProvinceName IS NOT NULL THEN ', ' + P_Res.ProvinceName ELSE '' END
            ) AS PermanentAddress,

            (ISNULL(E.tmpAddress, '') +
             CASE WHEN E.tmpWard IS NOT NULL AND E.tmpWard <> '' THEN ', ' + E.tmpWard ELSE '' END +
             CASE WHEN D_Tmp.DistrictName IS NOT NULL THEN ', ' + D_Tmp.DistrictName ELSE '' END +
             CASE WHEN P_Tmp.ProvinceName IS NOT NULL THEN ', ' + P_Tmp.ProvinceName ELSE '' END
            ) AS TemporaryAddress,

            ISNULL(E.MobilePhone, E.HomePhone) AS [Home Phone],
            E.Email , E.BirthPlace,E.AccountNo,E.ID_Number, tps.Kilometer,E.TaxRegNo ,
            E.CostCenter , WP.WorkingPlaceName,wt.WorkTypeName,
              case when e.WorkTypeID = 2
             then substring(E.employeeid,PATINDEX('%[^0-9]%',E.EmployeeID),LEN(E.EmployeeID))
             else ''
             end as CungUng

        FROM dbo.fn_vtblEmployeeList_Bydate(@ViewDate, '-1', @LoginID) E
        left join dbo.fn_Transportation_ByDate(@ViewDate) tps on tps.EmployeeID = e.EmployeeID
        LEFT JOIN tblPosition P ON E.PositionID = P.PositionID
        LEFT JOIN tblDivision Div ON E.DivisionID = Div.DivisionID
        LEFT JOIN tblUnit un on div.UnitID = un.UnitID
        LEFT JOIN tblDepartment Dep ON E.DepartmentID = Dep.DepartmentID
        LEFT JOIN tblSection Sec ON E.SectionID = Sec.SectionID
        LEFT JOIN tblGroup G ON E.GroupID = G.GroupID
        LEFT JOIN tblDistrict D_Res ON E.DistrictID = D_Res.DistrictID
        LEFT JOIN tblProvince P_Res ON E.ProvinceID = P_Res.ProvinceID
        LEFT JOIN tblDistrict D_Tmp ON E.tmpDistrictID = D_Tmp.DistrictID
        LEFT JOIN tblProvince P_Tmp ON E.tmpProvinceID = P_Tmp.ProvinceID
        LEFT JOIN tblWorkingPlace WP ON E.WorkingPlaceID = WP.WorkingPlaceID
        LEFT JOIN tblMST_ContractType CT ON E.ContractCode = CT.ContractCode
        left join tblWorkType wt on wt.WorkTypeID = e.WorkTypeID
        WHERE ISNULL(E.EmployeeStatusID, 0) <> 20
          AND (ISNULL(@EmployeeStatusID, -1) IN (-1, 0) OR E.EmployeeStatusID = @EmployeeStatusID)
          AND (ISNULL(@DivisionID, -1) IN (-1, 0) OR E.DivisionID = @DivisionID)
          AND (ISNULL(@PositionID, -1) IN (-1, 0) OR E.PositionID = @PositionID)
          AND (ISNULL(@WorkTypeID, -1) IN (-1, 0) OR E.WorkTypeID = @WorkTypeID)
          AND (
                ISNULL(@IsFilterHireDate, 0) = 0
                OR (
                    (@FromDate IS NULL OR CAST(E.HireDate AS DATE) >= @FromDate)
                    AND (@ToDate IS NULL OR CAST(E.HireDate AS DATE) <= @ToDate)
                )
              )
        order by HireDate


GO
