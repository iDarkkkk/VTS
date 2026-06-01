
if object_id('[dbo].[API_OTConfirmAV_GetList]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTConfirmAV_GetList] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTConfirmAV_GetList]
    @LoginID varchar(50),
    @FromDate date,
    @ToDate date,
    @Status int,
    @TypeRegister int
as
begin
    set nocount on;
    declare @LeaderEmpID varchar(50);
    select top 1 @LeaderEmpID = ltrim(rtrim(EmployeeID)) from tblSC_Login where LoginName = @LoginID or cast(LoginID as varchar(50)) = @LoginID;

    select m.Identity_ID, m.GroupID,
        case when isnull(m.IsDivision, 0) = 1 then isnull((select DivisionName from tblDivision where DivisionID = m.DivisionID), 'N/A')
             else isnull(g.GroupTeamName, 'N/A') end as GroupName,
        m.TypeRegister, m.OTDate as OTDateFrom, m.OTDate as OTDateTo, m.Approve_Status, m.Current_Approved_Level, m.CreateTime,
        m.Approver_1, m.Approver_2, m.Approver_3, m.Approver_4,
        m.Approver_5,
        concat(ee.EmployeeID, ' - ', ee.FullName) as CreatorName, m.RegisterBy,
        isnull(m.IsDivision, 0) as IsDivision,
        isnull((select count(EmployeeID) from tblOTActualDetailNIVS where Identity_ID = m.Identity_ID), 0) as TotalEmployees,
        isnull((select sum(a.Actual_OTHours) from tblOTActualDetailNIVS a where a.Identity_ID = m.Identity_ID), 0) as TotalHours,
        isnull((
            select count(1)
            from tblOTActualDetailNIVS a
            outer apply (
                select top 1 pd.IsExceed
                from tblOTListRegisteredNIVS_Detail pd
                inner join tblOTListRegisteredNIVS pm on pd.Identity_ID = pm.Identity_ID
                where pd.EmployeeID = a.EmployeeID
                  and cast(pd.OTDate as date) = cast(a.OTDate as date)
                  and pm.Approve_Status = 2
                  and pm.RegisterBy = m.RegisterBy
                order by case when pd.Identity_ID = m.Plan_Identity_ID then 0 else 1 end, pm.CreateTime desc
            ) p
            where a.Identity_ID = m.Identity_ID
              and isnull(p.IsExceed, 0) = 1
        ), 0) as ExceedNormEmployeesCount,

        isnull((
            select count(1)
            from tblOTActualDetailNIVS a
            outer apply (
                select top 1 pd.OTHours
                from tblOTListRegisteredNIVS_Detail pd
                inner join tblOTListRegisteredNIVS pm on pd.Identity_ID = pm.Identity_ID
                where pd.EmployeeID = a.EmployeeID
                  and cast(pd.OTDate as date) = cast(a.OTDate as date)
                  and pm.Approve_Status = 2
                  and pm.RegisterBy = m.RegisterBy
                order by case when pd.Identity_ID = m.Plan_Identity_ID then 0 else 1 end, pm.CreateTime desc
            ) p
            where a.Identity_ID = m.Identity_ID
              and p.OTHours is not null
              and isnull(a.Actual_OTHours, 0) > isnull(p.OTHours, 0)
        ), 0) as HasRisk_Deviated,

        case
            when m.Approve_Status in (1,5) and m.Current_Approved_Level = 1 and m.Approver_1 = @LeaderEmpID then 1
            when m.Approve_Status in (1,5) and m.Current_Approved_Level = 2 and m.Approver_2 = @LeaderEmpID then 1
            when m.Approve_Status in (1,5) and m.Current_Approved_Level = 3 and m.Approver_3 = @LeaderEmpID then 1
            when m.Approve_Status in (1,5) and m.Current_Approved_Level = 4 and m.Approver_4 = @LeaderEmpID then 1
            when m.Approve_Status in (1,5) and m.Current_Approved_Level = 5 and m.Approver_5 = @LeaderEmpID then 1
            else 0
        end as IsMyTurnToApprove
    from tblOTActualMasterNIVS m
    left join tblSC_Login sc on m.RegisterBy = sc.LoginID
    left join tblEmployee ee on sc.EmployeeID = ee.EmployeeID
    left join tblGroupTeam g on m.GroupID = g.GroupTeamID
    left join tblEmployee e on m.RegisterBy = e.EmployeeID
    where (m.Approver_1 = @LeaderEmpID or m.Approver_2 = @LeaderEmpID or m.Approver_3 = @LeaderEmpID or m.Approver_4 = @LeaderEmpID or m.Approver_5 = @LeaderEmpID) -- [MỚI] Điều kiện Where
      and m.Approve_Status <> 0
      and (@TypeRegister = -1 or m.TypeRegister = @TypeRegister)
      and (
          (@Status = 1 and m.Approve_Status in (1, 5))
          or
          (
              m.OTDate >= @FromDate and m.OTDate <= @ToDate
              and (
                  @Status = -1
                  or (@Status not in (-1, 1) and m.Approve_Status = @Status)
              )
          )
      )
    order by IsMyTurnToApprove desc, m.CreateTime desc;
end
GO
