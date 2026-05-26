USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_GetScheduleForExtraEmp]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_GetScheduleForExtraEmp] as select 1')
GO
ALTER PROCEDURE [dbo].[API_GetScheduleForExtraEmp]
    @EmpIDs varchar(max),
    @FromDate date,
    @ToDate date
as
begin
    set nocount on;
    begin try
        declare @xml xml = cast('<x>' + replace(@EmpIDs, ',', '</x><x>') + '</x>' as xml);
        select ltrim(rtrim(t.c.value('.', 'varchar(50)'))) as EmployeeID
        into #SelectedEmps
        from @xml.nodes('/x') t(c)
        where ltrim(rtrim(t.c.value('.', 'varchar(50)'))) <> '';

        select Date as OTDate into #DateList from dbo.fn_datelist(@FromDate, @ToDate);

        select e.EmployeeID, e.FullName, e.EmployeeTypeID, e.PositionID, e.GroupTeamID
        into #EmpInfo
        from fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e
        inner join #SelectedEmps s on e.EmployeeID = s.EmployeeID;

        select * into #MaternityStatus from dbo.fn_EmployeeStatusRange(0) where EmployeeStatusID = 11 and EmployeeID in (select EmployeeID from #SelectedEmps);

        select * into #empDivRange from dbo.fn_DivDepSecPosRange(0) where EmployeeID in (select EmployeeID from #SelectedEmps);

        declare @LookBackDate date = dateadd(day, -100, @FromDate);
        declare @StartOfMonth date = datefromparts(year(@FromDate), month(@FromDate), 1);
        declare @EndOfMonth date = eomonth(@ToDate);

        create table #EmpHolidayWorked (EmployeeID varchar(50), WorkDate date, primary key (EmployeeID, WorkDate));

        insert into #EmpHolidayWorked (EmployeeID, WorkDate)
        select distinct EmployeeID, cast(AttDate as date)
        from tblAttendanceSummary
        where AttDate >= @StartOfMonth and AttDate <= @EndOfMonth
          and isnull(HolidayStatus, 0) > 0
          and AttStart is not null and AttEnd is not null
          and EmployeeID in (select EmployeeID from #SelectedEmps);

        insert into #EmpHolidayWorked (EmployeeID, WorkDate)
        select distinct d.EmployeeID, cast(d.OTDate as date)
        from tblOTListRegisteredNIVS_Detail d
        join tblOTListRegisteredNIVS m on d.Identity_ID = m.Identity_ID
        where m.Approve_Status = 2 and m.TypeRegister = 2
          and d.OTDate >= @StartOfMonth and d.OTDate <= @EndOfMonth
          and d.EmployeeID in (select EmployeeID from #SelectedEmps)
          and not exists (select 1 from #EmpHolidayWorked w where w.EmployeeID = d.EmployeeID and w.WorkDate = cast(d.OTDate as date));

        select v.EmployeeID, dl.OTDate,
               isnull((select count(*) from #EmpHolidayWorked hw where hw.EmployeeID = v.EmployeeID and hw.WorkDate >= datefromparts(year(dl.OTDate), month(dl.OTDate), 1) and hw.WorkDate < dl.OTDate), 0) as WorkedHolidays
        into #HolidayCounts
        from #SelectedEmps v cross join #DateList dl;


        create table #EmpWorkTimeline (EmployeeID varchar(50), WorkDate date, primary key (EmployeeID, WorkDate));

        insert into #EmpWorkTimeline (EmployeeID, WorkDate)
        select distinct EmployeeID, cast(AttDate as date)
        from tblAttendanceSummary
        where AttStart is not null and AttEnd is not null
          and AttDate >= @LookBackDate and AttDate <= @ToDate
          and EmployeeID in (select EmployeeID from #SelectedEmps);

        insert into #EmpWorkTimeline (EmployeeID, WorkDate)
        select distinct d.EmployeeID, cast(d.OTDate as date)
        from tblOTListRegisteredNIVS_Detail d
        join tblOTListRegisteredNIVS m on d.Identity_ID = m.Identity_ID
        where m.Approve_Status = 2
          and d.OTDate >= @LookBackDate and d.OTDate <= @ToDate
          and d.EmployeeID in (select EmployeeID from #SelectedEmps)
          and not exists (select 1 from #EmpWorkTimeline w where w.EmployeeID = d.EmployeeID and w.WorkDate = cast(d.OTDate as date));

        select EmployeeID, WorkDate, dateadd(day, -dense_rank() over(partition by EmployeeID order by WorkDate), WorkDate) as IslandGrp into #Islands from #EmpWorkTimeline;
        select EmployeeID, WorkDate, row_number() over(partition by EmployeeID, IslandGrp order by WorkDate) as ConsecUpToThisDay into #IslandCounts from #Islands;

        create table #DailyOTBase (EmployeeID varchar(50), OTDate date, Hrs float);

        insert into #DailyOTBase (EmployeeID, OTDate, Hrs)
        select EmployeeID, cast(AttDate as date), sum(isnull(ApprovedHours, 0))
        from tblAttendanceSummary
        where AttDate >= @StartOfMonth and AttDate <= @EndOfMonth
          and EmployeeID in (select EmployeeID from #SelectedEmps)
          and ApprovedHours is not null
        group by EmployeeID, cast(AttDate as date);

        insert into #DailyOTBase (EmployeeID, OTDate, Hrs)
        select EmployeeID, OTDate, Hrs from (
            select d.EmployeeID, cast(d.OTDate as date) as OTDate, isnull(d.OTHours, 0) as Hrs,
                   row_number() over(partition by d.EmployeeID, cast(d.OTDate as date) order by m.CreateTime desc) as rn
            from tblOTListRegisteredNIVS_Detail d
            join tblOTListRegisteredNIVS m on d.Identity_ID = m.Identity_ID
            where m.Approve_Status = 2
              and d.OTDate >= @StartOfMonth and d.OTDate <= @EndOfMonth
              and d.EmployeeID in (select EmployeeID from #SelectedEmps)
        ) T
        where rn = 1
        and not exists (select 1 from #DailyOTBase b where b.EmployeeID = T.EmployeeID and b.OTDate = T.OTDate);

        select e.EmployeeID, dl.OTDate,
               isnull((select sum(Hrs) from #DailyOTBase b where b.EmployeeID = e.EmployeeID and b.OTDate >= datefromparts(year(dl.OTDate), month(dl.OTDate), 1) and b.OTDate < dl.OTDate), 0) as Calculated_BaseOT
        into #OTRunningTotals
        from #SelectedEmps e cross join #DateList dl;

        select ei.EmployeeID, ei.FullName, dl.OTDate, ei.EmployeeTypeID, ei.PositionID, ei.GroupTeamID,

            cast(isnull(td.Direct, 1) as varchar) as IsDirect,

            isnull(rt.Calculated_BaseOT, 0) as BaseOT_Before,
            s.ShiftID, ss.ShiftName, ss.WorkStart, ss.WorkEnd,
            ss.OTBeforeStart, ss.OTBeforeEnd, ss.OTAfterStart, ss.OTAfterEnd,
            isnull(m.HolidayStatusID, 0) as HolidayStatus,

            isnull(cc.ConsecUpToThisDay, 0) as ConsecutiveDays,
            isnull(hc.WorkedHolidays, 0) as WorkedHolidays,

           isnull(cast((
                    select top 1 case when isnull(ms.isAllowLate, 0) = 1 then '1' else '0' end
                    from #MaternityStatus ms
                    where ltrim(rtrim(ms.EmployeeID)) = ltrim(rtrim(ei.EmployeeID))
                      and cast(dl.OTDate as date) between cast(ms.ChangedDate as date) and cast(ms.StatusEndDate as date)
                    order by ms.ChangedDate desc
                ) as varchar(10)), 'NONE') as IsAllowLate
        from #EmpInfo ei
        cross join #DateList dl
        left join #OTRunningTotals rt on ei.EmployeeID = rt.EmployeeID and dl.OTDate = rt.OTDate
        left join #HolidayCounts hc on ei.EmployeeID = hc.EmployeeID and dl.OTDate = hc.OTDate
        left join #IslandCounts cc on ei.EmployeeID = cc.EmployeeID and cc.WorkDate = dateadd(day, -1, dl.OTDate)
        left join tblAttendanceSummary s on s.EmployeeID = ei.EmployeeID and cast(s.AttDate as date) = dl.OTDate
        left join tblShiftSetting ss on s.ShiftID = ss.ShiftID
        left join tblMappingShiftHolidayStatus m on m.ShiftCode = ss.ShiftCode
        left join #empDivRange dr on ei.EmployeeID = dr.EmployeeID and dl.OTDate between dr.ChangedDate and dr.EndDate
        left join tblDivision td on dr.DivisionID = td.DivisionID

        order by ei.EmployeeID, dl.OTDate;

        drop table #SelectedEmps;
        drop table #DateList;
        drop table #EmpInfo;
        drop table #MaternityStatus;
        drop table #DailyOTBase;
        drop table #OTRunningTotals;
        drop table #EmpHolidayWorked;
        drop table #HolidayCounts;
        drop table #EmpWorkTimeline;
        drop table #Islands;
        drop table #IslandCounts;
        drop table #empDivRange;
    end try
    begin catch
        select 'error' as result, error_message() as reason;
    end catch
end
GO