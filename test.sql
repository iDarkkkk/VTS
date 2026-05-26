USE Paradise_NIVS
GO
if object_id('[dbo].[sp_SalaryByDate_List]') is null
 EXEC ('CREATE PROCEDURE [dbo].[sp_SalaryByDate_List] as select 1')
GO

ALTER PROCEDURE [dbo].[sp_SalaryByDate_List]
(
 @LoginID int,
 @LanguageID varchar(2) = 'vn',
 @ViewDate date = null,
 @GetDataOnlyTempTableName nvarchar(500) = ''
)
as
begin
 set nocount on;
 set @ViewDate = isnull(@ViewDate, getdate());

 select * into #fn_vtblEmployeeList
 from dbo.fn_vtblEmployeeList_Simple_Bydate(@ViewDate, '-1', @LoginID)

 select c.EmployeeID, sh.Salary, sh.PositionID as SH_PositionID, sh.RankID, sh.LevelID,
     sh.Support_AL, sh.Support2_AL, sh.TCPN as TCPN_AL
 into #tblSalaryHistory
 from dbo.fn_CurrentSalaryHistoryIDByDate(@ViewDate) c
 inner join tblSalaryHistory sh on c.SalaryHistoryID = sh.SalaryHistoryID
 where exists(select 1 from #fn_vtblEmployeeList e where e.EmployeeID = c.EmployeeID)

 select * into #fn_PositionNormRange
 from dbo.fn_PositionNormRange()
 where @ViewDate between EffectiveDate and isnull(EndDate, '9999-12-31')

 select h.EmployeeID, sum(isnull(n.Amount, 0)) as Language_AL
 into #Language_AL
 from dbo.fn_CertificateHistory_Range() h
 outer apply (
  select top 1 n1.Amount from tblCertificateNorm n1
  where n1.CertificateTypeID = h.CertificateTypeID and n1.EffectiveDate <= @ViewDate
  order by n1.EffectiveDate desc
 ) n
 where @ViewDate between h.EffectiveDate and isnull(h.EndDate, '9999-12-31')
 group by h.EmployeeID

 select h.EmployeeID, sum(isnull(s.Amount, 0)) as TCCD_AL
 into #Stage_AL
 from dbo.fn_StageAllowance_Range() h
 outer apply (
  select top 1 s1.Amount from tblStageAllowanceSetting s1
  where s1.StageAllowanceID = h.StageAllowanceID and s1.EffectiveDate <= @ViewDate
  order by s1.EffectiveDate desc
 ) s
 where @ViewDate between h.EffectiveDate and isnull(h.EndDate, '9999-12-31')
 group by h.EmployeeID

 select h.EmployeeID, sum(isnull(s.Amount, 0)) as Responsibility_AL
 into #Responsibility_AL
 from dbo.fn_Responsibility_Range() h
 outer apply (
  select top 1 s1.Amount from tblResponsibilitySetting s1
  where s1.ResponsibilityID = h.ResponsibilityID and s1.EffectiveDate <= @ViewDate
  order by s1.EffectiveDate desc
 ) s
 where @ViewDate between h.EffectiveDate and isnull(h.EndDate, '9999-12-31')
 group by h.EmployeeID

 select h.EmployeeID, sum(isnull(s.Amount, 0)) as QualLevel_AL
 into #QualLevel_AL
 from dbo.fn_QualLevel_Range() h
 outer apply (
  select top 1 s1.Amount from tblQualLevelSetting s1
  where s1.QualLevelID = h.QualLevelID and s1.EffectiveDate <= @ViewDate
  order by s1.EffectiveDate desc
 ) s
 where @ViewDate between h.EffectiveDate and isnull(h.EndDate, '9999-12-31')
 group by h.EmployeeID

 select h.EmployeeID, sum(isnull(s.Amount, 0)) as QualPCCC_AL
 into #QualPCCC_AL
 from dbo.fn_QualPCCC_Range() h
 outer apply (
  select top 1 s1.Amount from tblQualPCCCSetting s1
  where s1.PCCC_RoleID = h.PCCC_RoleID and s1.EffectiveDate <= @ViewDate
  order by s1.EffectiveDate desc
 ) s
 where @ViewDate between h.EffectiveDate and isnull(h.EndDate, '9999-12-31')
 group by h.EmployeeID

 select h.EmployeeID, sum(isnull(s.Amount, 0)) as QualOther_AL
 into #QualOther_AL
 from dbo.fn_QualOther_Range() h
 outer apply (
  select top 1 s1.Amount from tblQualOtherSetting s1
  where s1.QualOtherID = h.QualOtherID and s1.EffectiveDate <= @ViewDate
  order by s1.EffectiveDate desc
 ) s
 where @ViewDate between h.EffectiveDate and isnull(h.EndDate, '9999-12-31')
 group by h.EmployeeID

 select h.EmployeeID, sum(isnull(s.Amount, 0)) as SkillLevel_AL
 into #SkillLevel_AL
 from dbo.fn_SkillLevel_Range() h
 outer apply (
  select top 1 s1.Amount from tblSkillLevelSetting s1
  where s1.SkillLevelID = h.SkillLevelID and s1.EffectiveDate <= @ViewDate
  order by s1.EffectiveDate desc
 ) s
 where @ViewDate between h.EffectiveDate and isnull(h.EndDate, '9999-12-31')
 group by h.EmployeeID

 select h.EmployeeID, sum(isnull(s.Amount, 0)) as SkillOther_AL
 into #SkillOther_AL
 from dbo.fn_SkillOther_Range() h
 outer apply (
  select top 1 s1.Amount from tblSkillOtherSetting s1
  where s1.SkillOtherID = h.SkillOtherID and s1.EffectiveDate <= @ViewDate
  order by s1.EffectiveDate desc
 ) s
 where @ViewDate between h.EffectiveDate and isnull(h.EndDate, '9999-12-31')
 group by h.EmployeeID

 select h.EmployeeID, sum(isnull(s.Amount, 0)) as UnionPos_AL
 into #UnionPos_AL
 from dbo.fn_UnionPos_Range() h
 outer apply (
  select top 1 s1.Amount from tblUnionPosSetting s1
  where s1.UnionPosID = h.UnionPosID and s1.EffectiveDate <= @ViewDate
  order by s1.EffectiveDate desc
 ) s
 where @ViewDate between h.EffectiveDate and isnull(h.EndDate, '9999-12-31')
 group by h.EmployeeID

 select h.EmployeeID,
     sum(case when h.AllowanceOtherID = 7 then p.Amount else 0 end) as FORKLIFT_AL,
     sum(case when h.AllowanceOtherID = 8 then p.Amount else 0 end) as BMC_AL,
     sum(case when h.AllowanceOtherID = 9 then p.Amount else 0 end) as PCCC_AL,
     sum(case when h.AllowanceOtherID = 10 then p.Amount else 0 end) as ATVSV_AL
 into #AllowanceOther_AL
 from dbo.fn_AllowanceDefaultAmount_Range() h
 inner join fn_ParameterAllowance_Range() p on h.AllowanceOtherID = p.ParameterAllowanceID and @ViewDate between p.EffectiveDate and isnull(p.EndDate, '9999-12-31')
 where @ViewDate between h.EffectiveDate and isnull(h.EndDate, '9999-12-31')
 group by h.EmployeeID

 select top 1 Amount as PerfectAtt_Amount into #PerfectAtt
 from fn_ParameterAllowance_Range()
 where ParameterAllowanceID = 2 and @ViewDate between EffectiveDate and isnull(EndDate, '9999-12-31') order by EffectiveDate desc

 select top 1 Amount as BaseTransport_Amount into #BaseTransport
 from fn_ParameterAllowance_Range()
 where ParameterAllowanceID = 3 and @ViewDate between EffectiveDate and isnull(EndDate, '9999-12-31') order by EffectiveDate desc

 select top 1 Amount as BaseBreakfast_Amount into #BaseBreakfast
 from fn_ParameterAllowance_Range()
 where ParameterAllowanceID = 6 and @ViewDate between EffectiveDate and isnull(EndDate, '9999-12-31') order by EffectiveDate desc

 select top 1 Amount as BaseHouse_Amount into #BaseHouse
 from fn_ParameterAllowance_Range()
 where ParameterAllowanceID = 12 and @ViewDate between EffectiveDate and isnull(EndDate, '9999-12-31') order by EffectiveDate desc

 select * into #tblSenioritySetting from tblSeniorityAllwanceSetting
 select * into #Transportation from dbo.fn_Transportation_ByDate(@ViewDate)

 select row_number() over (order by te.EmployeeID) as ORD, te.EmployeeID, te.FullName, div.DivisionName, pos.PositionName, convert(varchar(10), te.HireDate, 103) as HireDate,
  (datediff(month, te.HireDate, @ViewDate) - case when day(te.HireDate) >= 15 then 1 else 0 end) as SeniorityMonths,
  case when isnull(st.RankID, 0) <> 0 and isnull(st.LevelID, 0) <> 0 then cast(st.RankID as varchar) + '-' + cast(st.LevelID as varchar) else '0' end as Scale,
  isnull(st.Salary, 0) as Salary, isnull(st.Support_AL, 0) as Support_AL, isnull(st.Support2_AL, 0) as Support2_AL, isnull(pn.PositionAmount, 0) as Pos_AL,
  (isnull(ql.QualLevel_AL, 0) + isnull(qp.QualPCCC_AL, 0) + isnull(qo.QualOther_AL, 0)) as Qualification_AL,
  (isnull(skl.SkillLevel_AL, 0) + isnull(sko.SkillOther_AL, 0)) as Skill_AL,
  isnull(res.Responsibility_AL, 0) as Responsibility_AL, isnull(lang.Language_AL, 0) as Language_AL,
  cast(0 as money) as Livingsupport1_AL, isnull(stage.TCCD_AL, 0) as TCCD_AL,
  isnull(ao.FORKLIFT_AL, 0) as FORKLIFT_AL, isnull(ao.BMC_AL, 0) as BMC_AL,
  isnull(ao.PCCC_AL, 0) as PCCC_AL, isnull(ao.ATVSV_AL, 0) as ATVSV_AL,
  case when isnull(pos.IsManager, 0) = 1 then 0 else isnull(pa.PerfectAtt_Amount, 0) end as PerfectAtt_AL,
  case when isnull(te.EmployeeTypeID, 0) in (1, 2) then isnull(bb.BaseBreakfast_Amount, 0) else 0 end as Breakfast_AL,
  case when isnull(tr.Kilometer, 0) = 2 then isnull(bh.BaseHouse_Amount, 0) else 0 end as House_AL,
  case
   when isnull(pos.IsManager, 0) = 1 then 0
   when isnull(tr.Kilometer, 0) in (3, 6, 9, 12, 15) then (tr.Kilometer / 3) * isnull(bt.BaseTransport_Amount, 0)
   else 0
  end as Transport_AL,
  isnull(st.TCPN_AL, 0) as TCPN_AL, isnull(up.UnionPos_AL, 0) as Union_AL, cast(0 as money) as TotalIncome
 into #DataView
 from #fn_vtblEmployeeList te
 left join tblDivision div on te.DivisionID = div.DivisionID
 left join tblPosition pos on te.PositionID = pos.PositionID
 left join #tblSalaryHistory st on te.EmployeeID = st.EmployeeID
 left join #fn_PositionNormRange pn on pn.PositionID = te.PositionID
 left join #Language_AL lang on te.EmployeeID = lang.EmployeeID
 left join #Stage_AL stage on te.EmployeeID = stage.EmployeeID
 left join #Responsibility_AL res on te.EmployeeID = res.EmployeeID
 left join #QualLevel_AL ql on te.EmployeeID = ql.EmployeeID
 left join #QualPCCC_AL qp on te.EmployeeID = qp.EmployeeID
 left join #QualOther_AL qo on te.EmployeeID = qo.EmployeeID
 left join #SkillLevel_AL skl on te.EmployeeID = skl.EmployeeID
 left join #SkillOther_AL sko on te.EmployeeID = sko.EmployeeID
 left join #UnionPos_AL up on te.EmployeeID = up.EmployeeID
 left join #AllowanceOther_AL ao on te.EmployeeID = ao.EmployeeID
 left join #Transportation tr on te.EmployeeID = tr.EmployeeID
 cross join #PerfectAtt pa
 cross join #BaseTransport bt
 cross join #BaseBreakfast bb
 cross join #BaseHouse bh

 update d set d.Livingsupport1_AL = isnull(s.AllowanceAmt, 0)
 from #DataView d
 left join #tblSenioritySetting s on d.SeniorityMonths between s.FromMonth and s.ToMonth

 update #DataView
 set TotalIncome = isnull(Salary, 0) + isnull(Support_AL, 0) + isnull(Support2_AL, 0) + isnull(Pos_AL, 0) + isnull(Qualification_AL, 0) +
       isnull(Skill_AL, 0) + isnull(Responsibility_AL, 0) + isnull(Language_AL, 0) + isnull(Livingsupport1_AL, 0) +
       isnull(TCCD_AL, 0) + isnull(FORKLIFT_AL, 0) + isnull(BMC_AL, 0) + isnull(PCCC_AL, 0) + isnull(ATVSV_AL, 0) +
       isnull(PerfectAtt_AL, 0) + isnull(Breakfast_AL, 0) + isnull(House_AL, 0) + isnull(Transport_AL, 0) + isnull(TCPN_AL, 0) + isnull(Union_AL, 0)

 -----------------------------
 -- XUẤT HOẶC ĐẨY VÀO BẢNG TẠM
 -----------------------------
 if isnull(@GetDataOnlyTempTableName, '') = ''
 begin
  select * from #DataView order by ORD
 end

 if exists(select 1 from tempdb.sys.tables where object_id = object_id('tempdb..' + @GetDataOnlyTempTableName))
 begin
  declare @insertQuery varchar(max) = ''

  select @insertQuery += ',[' + name + ']'
  from tempdb.sys.columns
  where object_id = object_id('tempdb..' + @GetDataOnlyTempTableName)
    and name in (select c1.name from tempdb.sys.columns c1 where c1.object_id = object_id('tempdb..#DataView'))

  set @insertQuery = 'insert into ' + @GetDataOnlyTempTableName + '(' + substring(@insertQuery, 2, 999999) + ')
       select ' + substring(@insertQuery, 2, 9999) + ' from #DataView'
  exec(@insertQuery)
 end
end
GO
exec sp_SalaryByDate_List 3,'vn','20260331'