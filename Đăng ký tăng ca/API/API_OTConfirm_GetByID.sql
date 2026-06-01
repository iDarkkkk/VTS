USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTConfirm_GetByID]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTConfirm_GetByID] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTConfirm_GetByID]
    @Identity_ID varchar(100)
as
begin
    set nocount on;
    begin try
        declare @GroupID int, @DivisionID int, @OTDate date, @PlanType int, @IsDivision int, @PlanMasterID varchar(100);

        select top 1
            @GroupID = GroupID, @DivisionID = DivisionID, @OTDate = OTDate,
            @PlanType = TypeRegister, @IsDivision = isnull(IsDivision, 0),
            @PlanMasterID = Plan_Identity_ID
        from tblOTActualMasterNIVS
        where Identity_ID = @Identity_ID;

        select m.*,
            case when isnull(m.IsDivision, 0) = 1 then isnull((select DivisionName from tblDivision where DivisionID = m.DivisionID), 'N/A')
                 else isnull(g.GroupTeamName, 'N/A') end as GroupName,
            concat(sc.EmployeeID,' - ',e1.FullName) as RegisterByNew,
            concat(a1.EmployeeID, ' - ', a1.FullName) as Approver1_Name,
            concat(a2.EmployeeID, ' - ', a2.FullName) as Approver2_Name,
            concat(a3.EmployeeID, ' - ', a3.FullName) as Approver3_Name,
            concat(a4.EmployeeID, ' - ', a4.FullName) as Approver4_Name,
            concat(a5.EmployeeID, ' - ', a5.FullName) as Approver5_Name
        from tblOTActualMasterNIVS m
        left join tblGroupTeam g on m.GroupID = g.GroupTeamID
        left join tblSC_Login sc on m.RegisterBy = sc.LoginID
        left join tblEmployee e1 on sc.EmployeeID = e1.EmployeeID
        left join tblEmployee a1 on m.Approver_1 = a1.EmployeeID
        left join tblEmployee a2 on m.Approver_2 = a2.EmployeeID
        left join tblEmployee a3 on m.Approver_3 = a3.EmployeeID
        left join tblEmployee a4 on m.Approver_4 = a4.EmployeeID
        left join tblEmployee a5 on m.Approver_5 = a5.EmployeeID
        where m.Identity_ID = @Identity_ID;

        if object_id('tempdb..#tmpEmpsDetail') is not null drop table #tmpEmpsDetail;
        create table #tmpEmpsDetail (EmployeeID varchar(50));

        insert into #tmpEmpsDetail
        select distinct EmployeeID from tblOTActualDetailNIVS where Identity_ID = @Identity_ID;

        if object_id('tempdb..#MaternityStatusDet') is not null drop table #MaternityStatusDet;
        select * into #MaternityStatusDet
        from dbo.fn_EmployeeStatusRange(0)
        where EmployeeStatusID = 11
          and EmployeeID in (select EmployeeID from #tmpEmpsDetail);

        if object_id('tempdb..#empDivRange') is not null drop table #empDivRange;
        select * into #empDivRange from dbo.fn_DivDepSecPosRange(0) where EmployeeID in (select EmployeeID from #tmpEmpsDetail);

        select a.EmployeeID, isnull(e.FullName, 'N/A') as FullName,
            isnull(p.ShiftID, a.ShiftID) as ShiftID,
            s.ShiftCode as shiftCode,
            s.ShiftName, s.WorkStart, s.WorkEnd, s.OTBeforeStart, s.OTBeforeEnd, s.OTAfterStart, s.OTAfterEnd,

            a.Planned_OTFrom, a.Planned_OTTo,
            isnull(p.OTHours, 0) as Plan_OTHours,
            a.Actual_OTFrom, a.Actual_OTTo,
            a.Actual_OTFrom as Saved_OTFrom, a.Actual_OTTo as Saved_OTTo,
            isnull(a.Actual_OTHours, 0) as Actual_OTHours,

            isnull(e.EmployeeTypeID, 1) as EmployeeTypeID, isnull(e.PositionID, '') as PositionID,
            isnull(map.HolidayStatusID, 0) as HolidayStatus,
            isnull(p.IsExceed, 0) as IsExceed,
            isnull(p.IsExtraEmp, 0) as IsExtraEmp,
            isnull(a.IsIndirectEmp, @IsDivision) as IsIndirectEmp,
            p.PlanGroupID, p.PlanDivisionID, p.PlanIsDivision,
            isnull(p.PlanGroupName, case when p.PlanIsDivision = 1 then isnull((select DivisionName from tblDivision where DivisionID = p.PlanDivisionID), 'N/A') else isnull((select GroupTeamName from tblGroupTeam where GroupTeamID = p.PlanGroupID), 'N/A') end) as PlanGroupName,
            isnull(p.LimitType, '') as LimitType,
            isnull(p.CurrentTotalOT, 0) as BaseOT_Before,
            isnull(p.ConsecutiveDays, 0) as ConsecutiveDays,
            isnull(p.WorkedHolidays, 0) as WorkedHolidays,

            cast(isnull(td.Direct, 1) as varchar) as IsDirect,

            isnull((
                select top 1 exMaster.Approve_Status
                from tblOTExceedDetailNIVS exDet
                join tblOTExceedMasterNIVS exMaster on exDet.Identity_ID = exMaster.Identity_ID
                where exDet.EmployeeID = a.EmployeeID
                  and cast(exMaster.OTDate as date) = cast(a.OTDate as date)
                order by exMaster.CreateTime desc
       ), 0) as ExceedApproveStatus,
            isnull(m.Approve_Status, 0) as Approve_Status,
            isnull(cast((
                select top 1 case when isnull(ms.isAllowLate, 0) = 1 then '1' else '0' end
                from #MaternityStatusDet ms
                where ltrim(rtrim(ms.EmployeeID)) = ltrim(rtrim(a.EmployeeID))
                  and cast(a.OTDate as date) between cast(ms.ChangedDate as date) and cast(ms.StatusEndDate as date)
                order by ms.ChangedDate desc
            ) as varchar(10)), 'NONE') as IsAllowLate

        from tblOTActualDetailNIVS a
        left join tblOTActualMasterNIVS m on a.Identity_ID = m.Identity_ID
        outer apply (
            select top 1 pd.ShiftID, pd.OTHours, pd.IsExceed, pd.IsExtraEmp, pd.LimitType, pd.CurrentTotalOT, pd.ConsecutiveDays, pd.WorkedHolidays,
                pm.GroupID as PlanGroupID, pm.DivisionID as PlanDivisionID, isnull(pm.IsDivision, 0) as PlanIsDivision,
                case when isnull(pm.IsDivision, 0) = 1 then isnull(dv.DivisionName, 'N/A') else isnull(gt.GroupTeamName, 'N/A') end as PlanGroupName
            from tblOTListRegisteredNIVS_Detail pd
            inner join tblOTListRegisteredNIVS pm on pd.Identity_ID = pm.Identity_ID
            left join tblGroupTeam gt on pm.GroupID = gt.GroupTeamID
            left join tblDivision dv on pm.DivisionID = dv.DivisionID
            where pd.EmployeeID = a.EmployeeID
              and cast(pd.OTDate as date) = cast(a.OTDate as date)
              and pm.Approve_Status = 2
              and pm.RegisterBy = m.RegisterBy
            order by case when pd.Identity_ID = @PlanMasterID then 0 else 1 end, pm.CreateTime desc
        ) p
        left join dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1',null) e on a.EmployeeID = e.EmployeeID
        left join tblShiftSetting s on s.ShiftID = isnull(p.ShiftID, a.ShiftID)
        left join tblMappingShiftHolidayStatus map on s.ShiftCode = map.ShiftCode

        left join #empDivRange dr on a.EmployeeID = dr.EmployeeID and a.OTDate between dr.ChangedDate and dr.EndDate
        left join tblDivision td on dr.DivisionID = td.DivisionID

        where a.Identity_ID = @Identity_ID;

        drop table #tmpEmpsDetail;
        drop table #MaternityStatusDet;
        drop table #empDivRange;

    end try
    begin catch
        select 'error' as result, error_message() as reason;
    end catch
end
GO
