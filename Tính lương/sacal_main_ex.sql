USE Paradise_NIVS
GO
if object_id('[dbo].[SALCAL_MAIN]') is null
 EXEC ('CREATE PROCEDURE [dbo].[SALCAL_MAIN] as select 1')
GO
--exec SALCAL_MAIN 11,2025,3,0,'051',0
ALTER PROCEDURE [dbo].[SALCAL_MAIN]
(
 @Month int,
 @Year int,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20) = '-1',
 @CalculateRetro int =0
)
AS
BEGIN
--Quyền nhân sự tính lương
 declare @IsHR bit = 0
 if exists(select 1 from tblSC_Login sc
 CROSS APPLY dbo.SplitString(sc.ParentLoginID,'&') as s  where s.Items = 4 and sc.LoginID=@LoginID) or @LoginID = 3
 begin set @IsHR=1 end

    if @IsHR=0
    begin
        INSERT INTO tblProcessErrorMessage(ErrorDetail,LoginID)
     SELECT N'Nhân sự lương mới có quyền tính lại lương!', @LoginID
        return;
    end
 --Trước tháng 1/2026 thì ko tính
 if @Year*12+@Month < 2025*12+12 return;

if @CalculateRetro is null
 set @CalculateRetro =0
 declare @nextMonth int= @month+1,@nextYear int = @Year
 if(@nextMonth = 13)
 begin
  set @nextMonth = 1
  set @nextYear +=1
 end

 if ISNULL(@PeriodID,-1) < 0
  set @PeriodID =0
IF isnull(@EmployeeID,'') = '' SET @EmployeeID = '-1'
DECLARE @Query nvarchar(max),@StopUPDATE bit = 0
SET NOCOUNT ON;
SET ANSI_WARNINGS OFF;
truncate table tblProcessErrorMessage
/* Danh mục tính lương
 -- lấy 1 bảng bao gồm ngày công ,nghỉ
 - Phát sinh 2,3 mức lương trong tháng: muc luong phat sinh moi trong thang
 - Tính công chuẩn: standard working day
 - Tạo lvHistory để tính chuyên cần: tao nghi viec neu de tinh chuyen can, tru thieu cong
 - Xóa dữ liệu tính lương lần trước: Delete old data
 - Tính lương 1 ngày: Calculate salary per day
 - Tính lương 1 giờ: Calculate salary per hour
 - Tính nghỉ trả lương, trừ lương: Leave Amount
 - Tính lương cơ bản: Calculate Actual salary
 - Tính lương tăng ca: Calculate OT
 - Tính điều chỉnh trong tháng: Calculate Adjustment
 - Tính phụ cấp: Calculate Allowance
 - Tính phụ cấp thâm niên: thâm niên
 - Tính phụ cấp chuyên cần: chuyên cần, chuyen can chuyencan
 - Tính phụ cấp đồng phục, nhà ở: phụ cấp trang phục
 - Tính tiền bảo hiểm: Calculate Employee insurance
 - Phí công đoàn: Calculate Trade Union fee
 - Trừ tiền đi trễ về sớm: Calculate IO
 - Tổng lương thực lãnh lần 1: Payroll sumaried items
 - Tính thuế TNCN: Calculate tax
 - Cập nhật lại lương thực lãnh: UPDATE other sumaried items of Sumary Table
 - Cập nhật lương detail, bảng lương tổng: UPDATE salary detail records
*/
 create table #NameOfPhysicTables(TempTablename nvarchar(500),PhysicTableName nvarchar(500)
 ,ColumnNeedToBeDeduct varchar(max),PrimaryKeyCOlumns varchar(max))

 select * into #tblSal_Adjustment_des from tblSal_Adjustment where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_Adjustment_des'
 ,'tblSal_Adjustment','Amount,TaxableAmount,UntaxableAmount'

 select * into #tblSal_Allowance_des from tblSal_Allowance where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_Allowance_des','tblSal_Allowance'
 ,'Amount,AmountLastMonth,UntaxableAmount,TaxableAmount,RetroAmount,RetroAmountNonTax,MonthlyCustomAmount'

 select * into #tblSal_IO_des from tblSal_IO where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_IO_des','tblSal_IO',''

 select * into #tblSal_NS_des from tblSal_NS where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_NS_des','tblSal_NS','NSHours,NSAmount'

 select * into #tblSal_OT_des from tblSal_OT where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_OT_des','tblSal_OT'
 ,'OTAmount,TaxableOTAmount,NoneTaxableOTAmount,NightShiftAmount'

 select * into #tblSal_PaidLeave_des from tblSal_PaidLeave where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_PaidLeave_des','tblSal_PaidLeave','LeaveDays,LeaveHour,AmountDeduct,AmountPaid'
 ----from detail table
 select * into #tblSal_Allowance_Detail_des from tblSal_Allowance_Detail where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_Allowance_Detail_des','tblSal_Allowance_Detail','Amount,AmountLastMonth,TaxableAmount,UntaxableAmount,Raw_DefaultAmount,Raw_ExchangeRate,RetroAmount,RetroAmountNonTax,MonthlyCustomAmount'
 select * into #tblSal_IO_Detail_des from tblSal_IO_Detail where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_IO_Detail_des','tblSal_IO_Detail',''

 select * into #tblSal_NS_Detail_des from tblSal_NS_Detail where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_NS_Detail_des','tblSal_NS_Detail','NSHours,NSAmount'
 select * into #tblSal_OT_Detail_des from tblSal_OT_Detail where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_OT_Detail_des','tblSal_OT_Detail','OTHour,OTAmount,NightShiftAmount'
 select * into #tblSal_PaidLeave_Detail_des from tblSal_PaidLeave_Detail where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_PaidLeave_Detail_des','tblSal_PaidLeave_Detail','LeaveDays,LeaveHour,AmountDeduct,AmountPaid'

 ----other sal table
 select * into #tblSal_Error_des from tblSal_Error where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName)
 select '#tblSal_Error_des','tblSal_Error'

 select * into #tblSal_Adjustment_ForAllowance_Des from tblSal_Adjustment_ForAllowance where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName)
 select '#tblSal_Adjustment_ForAllowance_Des','tblSal_Adjustment_ForAllowance'

 select * into #tblSal_Abroad_ForTaxPurpose_des from tblSal_Abroad_ForTaxPurpose where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_Abroad_ForTaxPurpose_des','tblSal_Abroad_ForTaxPurpose','NetAmountVND,Raw_NetAmount,GrossAmountVND,Raw_GrossAmount'


 select * into #tblSal_tax_des from tblSal_tax where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_tax_des','tblSal_tax','IncomeTaxable,TaxAmt,OTDeduction,Salary13Amount,TaxableIncome_EROnly_ForNETOnly,PITAmt_ER,TaxRetroImported'

 select * into #tblSal_Sal_des from tblSal_Sal where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_Sal_des','tblSal_Sal','ActualMonthlyBasic,TaxableAllowance,NontaxableAllowance,TaxableAdjustment,NontaxableAdj,TotalIncome,IOAmt,EmpUnion,CompUnion,TaxableIncomeBeforeDeduction,IncomeAfterPIT,GrossTakeHome,TotalEarn,RemainAL,TaxableAdjustmentTotal_ForSalary,TaxableAdjustmentTotal_NotForSalary,TotalIncome_Taxable_Without_INS_Persion_family,TotalIncome_ForSalaryTaxedAdj,TotalCostComPaid,TotalPayrollFund,TotalDeduction,UnpaidLeaveAmount,EmpUnion_RETRO,CompUnion_RETRO,TotalNetIncome_Custom,GrossedUpWithoutHousing_Custom,GrossedUpWithoutHousing_WithoutGrossIncome_Custom'

 select * into #tblSal_Sal_Detail_des from tblSal_Sal_Detail where 1=0
 insert into #NameOfPhysicTables(TempTablename,PhysicTableName,ColumnNeedToBeDeduct)
 select '#tblSal_Sal_Detail_des','tblSal_Sal_Detail','ATTHours,WorkingHours,ActualMonthlyBasic,TaxableAllowance,NontaxableAllowance,TaxableAdjustment,NontaxableAdj,TotalIncome,IOAmt,EmpUnion,CompUnion,TaxableIncomeBeforeDeduction,IncomeAfterPIT,GrossTakeHome,TotalEarn,DaysOfSalEntry,TaxableAdjustmentTotal_ForSalary,TaxableAdjustmentTotal_NotForSalary,UnpaidLeaveAmount,TotalNetIncome_Custom,GrossedUpWithoutHousing_Custom,GrossedUpWithoutHousing_WithoutGrossIncome_Custom'


 DECLARE @FromDate datetime ,@ToDate datetime, @ToDateTruncate date,@CAL_SALTAX_PROGRESSIVE_ALLEMPS int,@FIXEDWORKINGDAY float = (SELECT [Value] FROM tblParameter WHERE Code = 'FIXEDWORKINGDAY')
 ,@ROUND_TAKE int,@ROUND_NET int,@ROUND_SALARY_UNIT int, @PROBATION_PERECNT float,@ROUND_OT_NS_Detail_UNIT int,@ROUND_TOTAL_WORKINGDAYS int
 ,@ROUND_ATTDAYS int
 set @ROUND_TAKE = (SELECT [Value] FROM tblParameter WHERE Code = 'ROUND_TAKE')
 set @ROUND_TAKE = ISNULL(@ROUND_TAKE,-3)

  set @ROUND_ATTDAYS = (SELECT [Value] FROM tblParameter WHERE Code = 'ROUND_ATTDAYS')
 set @ROUND_ATTDAYS = ISNULL(@ROUND_ATTDAYS,4)

 set @ROUND_NET = (SELECT [Value] FROM tblParameter WHERE Code = 'ROUND_NET')
 set @ROUND_NET = ISNULL(@ROUND_NET,-3)

set @ROUND_SALARY_UNIT = (SELECT [Value] FROM tblParameter WHERE Code = 'ROUND_SALARY_UNIT')
 set @ROUND_SALARY_UNIT = ISNULL(@ROUND_SALARY_UNIT,4)

 set @ROUND_OT_NS_Detail_UNIT = (SELECT [Value] FROM tblParameter WHERE Code = 'ROUND_OT_NS_Detail_UNIT')
 set @ROUND_OT_NS_Detail_UNIT = ISNULL(@ROUND_OT_NS_Detail_UNIT,4)

 set @ROUND_TOTAL_WORKINGDAYS = (SELECT [Value] FROM tblParameter WHERE Code = 'ROUND_TOTAL_WORKINGDAYS')
 set @ROUND_TOTAL_WORKINGDAYS = ISNULL(@ROUND_TOTAL_WORKINGDAYS,5)

 SET @FIXEDWORKINGDAY = ISNULL(@FIXEDWORKINGDAY,26.0)
 set @CAL_SALTAX_PROGRESSIVE_ALLEMPS = (SELECT [Value] FROM tblParameter WHERE Code = 'CAL_SALTAX_PROGRESSIVE_ALLEMPS')
 if(@CAL_SALTAX_PROGRESSIVE_ALLEMPS is null) set @CAL_SALTAX_PROGRESSIVE_ALLEMPS = 0

 --set @PROBATION_PERECNT = (SELECT [Value] FROM tblParameter WHERE Code = 'PROBATION_PERECNT')
 --SET @PROBATION_PERECNT = ISNULL(@PROBATION_PERECNT,100)

 select @FromDate = FromDate , @ToDate = ToDate, @ToDateTruncate = ToDate from dbo.fn_Get_SalaryPeriod_Term(@Month,@Year,@PeriodID)


CREATE TABLE #tblSalDetail(
 EmployeeID varchar(20)
 ,EmployeeTypeID int
 ,HireDate date
 ,BasicSalaryDefault float(53)
 ,BasicSalary float(53)
 ,BasicSalaryOrg float(53)
 ,Support float(53)
 ,Support2 float(53)
 ,TotalSalary float(53)
  ,WD float
 ,WD_Month float
 ,STD_WD float
 ,STD_WD_Schedule float
 ,IsProbation bit
 ,OTSalary float(53)
 ,SalaryPerDay float(53)
 ,SalaryPerHour float(53)
 ,SalaryPerDayOT float(53)
 ,SalaryPerHourOT float(53)
 ,WorkingHoursPerDay float(53)
 ,DaysOfSalEntry float
 ,ActualMonthlyBasic float(53)
 ,UnpaidLeaveAmount float(53)
 ,TaxableOTTotal float(53)
 ,NoneTaxableOTTotal float(53)
 ,TotalOTAmount float(53) --dung de round
 ,TotalNSAmt float(53)
 ,NightShiftAmount float(53)
 ,NoneTaxableNSAmt float(53)
 ,TaxableAllowanceTotal float(53)
 ,NoneTaxableAllowanceTotal float(53)
 ,TotalAllowanceForSalary float(53)
 ,TaxableAdjustmentTotal float(53)
 ,TaxableAdjustmentTotal_ForSalary float(53)
 ,TaxableAdjustmentTotal_NotForSalary float(53)
 ,NoneTaxableAdjustmentTotal float(53)
 ,TotalAdjustmentForSalary float(53)
 ,TotalAdjustment_WithoutForce float(53)
 ,TotalEarn float(53) -- Tổng thu nhập gồm toàn những khoản cộng
 ,TotalIncome float(53) -- Tổng thu nhập\
 ,TotalIncome_ForSalaryTaxedAdj float(53) -- Tổng thu nhập + allowance + adjustment trong lương chịu thuế
 ,TotalIncome_Taxable_Without_INS_Persion_family float(53) -- Tổng thu nhập + allowance + adjustment trong lương chịu thuế
 ,TaxableIncomeBeforeDeduction float(53)
 ,TaxableIncomeBeforeDeduction_EROnly_ForNETOnly float(53)
 ,OwnerDeduction float(53)
 ,DependentDeduction float(53)
 ,TaxableIncome float(53)
 ,TaxableIncome_EROnly_ForNETOnly float(53)
 ,PITAmt float(53)
 ,PITAmt_ER float(53)
 ,EmpUnion_RETRO float(53)
 ,EmpUnion float(53)
 ,CompUnion_RETRO float(53)
 ,CompUnion float(53)
 ,InsAmt float(53) --10.5% cua nhan vien dong
 ,InsAmtComp float(53)
 ,PITReturn float(53) -- điều chỉnh sau lương
 ,IncomeAfterPIT float(53)
 ,OtherDeductionAfterPIT float(53) -- mục đích thể hiện số tiền bị trừ sau thuế, giống cột tạm ứng
 ,AdvanceAmt float(53)
 ,TotalCostComPaid float(53)
 ,TotalPayrollFund float(53)
 ,Salary13thProvision float(53)
 ,FromDate datetime
 ,ToDate datetime
 ,SalaryHistoryID bigint
 ,BaseSalRegionalID int
 ,isTwoSalLevel bit
 ,SalCalRuleID int
 ,LatestSalEntry bit
 ,IOAmt float(53) -- đi trễ về sớm
 ,TotalDeduct float(53) -- tổng các khoản khấu trừ, cong đoàn, bảo hiểm,thuế, trừ khác
 ,GrossTakeHome float(53)
 ,AverageSalary float(53) -- luong binh quan khi co nhieu muc luong trong thang
 ,CurrencyCode nvarchar(20)
 ,ExchangeRate float(53)
 ,IsNet bit
 ,TotalNetIncome_Custom float(53)
 ,GrossedUpWithoutHousing_Custom float(53)
 ,GrossedUpWithoutHousing_WithoutGrossIncome_Custom float(53)
 --,SalaryCalculationDAte date
 ,STDPerSalaryHistoryId float(53)
 ,PayrollTypeCode varchar(50)
 ,ProbationSalaryHistoryID BIGINT
 ,PositionID int
,EmployeeStatusID int
,RankID varchar
,LevelID varchar
,isNotAL bit -- ko tính phụ cấp
,InsSalary float(53) --  lương tính bảo hiểm
,NotYetWork int--ngay chua vao lam
,NotTermiWork int -- số ngày nghỉ việc trong tháng
,NotWorkSalary float(53)
,LeaveCH2PH3 int
,AttDays float
,UnpaidNotBH int
,AfterMaternity date
,Maternity date
,LBIssueDate date
,TerminateDate date
,Kilometer float(10)
,WorkingDayoff float
)

if(OBJECT_ID('SALCAL_ADD_COLUMN_INTO_TMP_TABLE' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_ADD_COLUMN_INTO_TMP_TABLE
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20) = ''-1''
)
as
begin
 SET NOCOUNT ON;
end')
end
SET @StopUPDATE = 0
exec SALCAL_ADD_COLUMN_INTO_TMP_TABLE @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

select te.EmployeeID,te.FullName,te.DivisionID,te.DepartmentID,te.SectionID,te.GroupID,te.EmployeeTypeID,
te.PositionID,te.EmployeeStatusID,te.Sex
,iif(te.TerminateDate is not null,1,0) as TerminatedStaff
,te.HireDate,te.TerminateDate,te.ProbationEndDate,te.LastWorkingDate,cast(null as date) LBIssueDate -- ngày ký HĐ trong tháng khi mới lên chính thức
,iif(te.AfterMaternity between @FromDate and @ToDate,te.AfterMaternity,null ) AfterMaternity-- sau nghỉ thai sản
,iif(te.Maternity between @FromDate and @ToDate,te.Maternity,null ) Maternity--  nghỉ thai sản
,te.kilometer,te.AccountNo
,emp.WorkTypeID
into #tblEmployeeIDList
from dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDateTruncate,@EmployeeID,@LoginID) te
inner join tblDivision div on te.DivisionID = div.DivisionID
left join tblEmployee emp on te.EmployeeID = emp.EmployeeID
where not exists(select 1 from tblSal_Lock l where te.EmployeeID = l.EmployeeID and @CalculateRetro = 0 and l.Month = @Month and l.Year = @Year)
and isnull(div.IsTemp,0) = 0 and isnull(div.IsNotSalCal,0) = 0 and div.DivisionID <> 1

 delete #tblEmployeeIDList where employeeID like 'J-%' --người nước ngoài ko chơi

 --Hiếu: hợp đồng
  update e set LBIssueDate=iif(b.LBIssueDate between @FromDate and @ToDate,b.LBIssueDate,null )
 from #tblEmployeeIDList e
 inner join (
 select employeeID,min(LBIssueDate) LBIssueDate
 from tblLabourContract
 where ContractCode <> '004'
 group by employeeID
 ) b on b.employeeID=e.employeeID


  if  @PeriodID =1
  delete  #tblEmployeeIDList where EmployeeID in (select EmployeeID from tblSal_Lock_Period1 where Month = @Month and Year = @Year)



 if @CalculateRetro = 1
 begin
  delete #tblEmployeeIDList
  where EmployeeID
  not in  (select re.EmployeeID from tblSal_AttendanceData_Retro re where re.Month = @Month and re.Year= @Year
  union
  select c.EmployeeID from tblCustomAttendanceData c where c.Month= @Month and c.Year = @Year and c.IsRetro= 1
  )

  delete #tblEmployeeIDList from #tblEmployeeIDList te where exists(select 1 from tblSal_Retro re where re.Month = @nextMonth and re.Year= @nextYear and IsImported = 1 and
  re.EmployeeID = te.EmployeeID)
 END
 if not exists( select 1 from #tblEmployeeIDList)
 return;
  -- những ai chưa khóa công thì ko cho tính lương
  insert into tblProcessErrorMessage(ErrorType,ErrorDetail,LoginID)
  select 'Att lock required!','['+de.EmployeeID+'] -- Lock attendance First!',@LoginID from
  (delete #tblEmployeeIDList output deleted.EmployeeID from #tblEmployeeIDList e
  where not exists(select 1 from tblAtt_LockMonth al where e.EmployeeID = al.EmployeeID and al.Month= @Month and al.Year = @Year)
 )de




 --UPDATE #tblEmployeeIDList SET HireDate = RenewHireDate where RenewHireDate <= @ToDate --nghi viec roi vao lam lai thi tinh tu ngay vao lam lai

 --lay trang thai ben bang history cho chinh xac
 UPDATE #tblEmployeeIDList SET EmployeeStatusID = stt.EmployeeStatusID, TerminateDate = CASE WHEN stt.EmployeeStatusID =20 THEN stt.ChangedDate ELSE NULL END
 from #tblEmployeeIDList te inner join dbo.fn_EmployeeStatus_ByDate(@ToDate) stt on te.EmployeeID = stt.EmployeeID
 UPDATE #tblEmployeeIDList SET TerminatedStaff = 1 where TerminateDate is not null

 select * into #EmployeeExchangeRate
 from dbo.fn_GetExchangeRateInSalaryPeriod(@loginid,@FromDate,@ToDate) c
 where c.EmployeeID in(select EmployeeID from #tblEmployeeIDList)


 if exists(select 1 from #EmployeeExchangeRate group by EmployeeId,CurrencyCode having count(1) >1)
 begin
  RAISERROR('MultiplecurrencyCode,Please Contact VietTinSoft to fix it!',16,1)
  return;
 end

 if (select COUNT(1) from #tblEmployeeIDList) = 0
  return

 -- move SAlretro here to query on sal OT, sal NS
 select * into #tblSal_Retro from tblSal_Retro
 where Month= @Month and Year = @Year
 and EmployeeID in (select EmployeeID from #tblEmployeeIDList)

 select distinct EmployeeID,Month,Year into #tblsal_retro_Final from #tblSal_Retro

 declare @querytblSAl_Retro varchar(max) = ''
 declare @querytblSAl_Retro_update varchar(max) = ''
 declare @querytblSAl_Retro_sumQue varchar(max) = ''
 select
 @querytblSAl_Retro +=','+c.name+' money'
 ,@querytblSAl_Retro_update += ', ['+c.name+'] = [S_'+c.name+']'
 ,@querytblSAl_Retro_sumQue += ', sum(['+c.name+']) as S_'+c.name+''
 from tempdb.sys.columns c
 inner join sys.types t on c.user_type_id  =t.user_type_id and t.name = 'money'
 where c.object_id = object_id('tempdb..#tblSal_Retro')

 set @querytblSAl_Retro = 'alter table #tblsal_retro_Final add BalanceDays float ,' + SUBSTRING(@querytblSAl_Retro,2,99999)
 exec(@querytblSAl_Retro)

 set @querytblSAl_Retro_update = 'update #tblsal_retro_Final set BalanceDays= S_BalanceDays,' + SUBSTRING(@querytblSAl_Retro_update,2,99999) + '
 from #tblsal_retro_Final r
 inner join (select EmployeeID,Max(case when BalanceDays = 0 then -9999 else BalanceDays end) as S_BalanceDays'+@querytblSAl_Retro_sumQue+'
 from #tblsal_retro group by EmployeeID) sal on r.EmployeeId = sal.EmployeeID '

 exec(@querytblSAl_Retro_update )

 exec sp_InsertUpdateFromTempTableTOTable @TempTableName = N'#tblsal_retro_Final', @TableName = tblSal_Retro_Sumary
 delete tblSal_Retro_Sumary from tblSal_Retro_Sumary  re
 where  month = @month and year= @year
 and not exists(select 1 from tblSal_lock sl where  sl.EmployeeID= re.EmployeeID and sl.Month = @Month and sl.Year = @Year)
 and not exists(select 1 from tblSal_Retro re1 where re.EmployeeID = re1.EmployeeID and re1.Month= @Month and re1.Year= @Year)
 and ISNULL(re.IsImported,0) =0

 drop table #tblSal_Retro

 select EmployeeID into #EmployeeWorkingOn from tmpEmployeeTree where LoginID= @LoginID

 --SET @LoginID = @LoginID + 1000

 --delete tmpEmployeeTree where LoginID = @LoginID
 --insert into tmpEmployeeTree(EmployeeID,LoginID)
 --select EmployeeID,@LoginID from #tblEmployeeIDList


 DECLARE @SIDate datetime
 select @SIDate = cast(cast(Year(@ToDate) as nvarchar(20)) +'-' +cast(Month(@ToDate) as nvarchar(20)) +'-15' as date )
 -- nhan vien dong thue thoi vu
 -- dùng để tính thuế cho thời vụ, thử việc không có cam kết thu nhập thấp hoặc nhân viên không có hợp đồng
 select e.EmployeeID, cast (isnull(pit.FixedPercents,10)/100 as float) TaxPercentage, isnull(lb.isLowSalary,0 ) isLowSalary,ISNULL(pit.PITStatus,1) as PITStatus,DivisionID
 into #tblTemporaryContractTax
 from #tblEmployeeIDList e
 inner join
 (
 select EmployeeID,ContractID
 from dbo.fn_CurrentContractListByDate(@SIDate) c where c.EmployeeID in (select EmployeeID from #tblEmployeeIDList)
 union
select EmployeeID,ContractID
 from dbo.fn_CurrentContractListByDate(@ToDate) c where c.EmployeeID in (select EmployeeID from #tblEmployeeIDList ee where ee.HireDate >@SIDate)

 ) c on e.EmployeeID = c.EmployeeID
 inner join tblLabourContract lb on c.ContractID = lb.ContractID
 inner join tblMST_ContractType mst on lb.ContractCode = mst.ContractCode
 left join tblContract_PIT_Status pit on lb.PITStatus = pit.PITStatus
 where
 ((isnull(pit.FollowLabourContract,0) = 1 and   ISNULL(mst.ShortTermTax,0) = 1)
 or
 (isnull(pit.Progressive,0) = 0))
 and
  @CAL_SALTAX_PROGRESSIVE_ALLEMPS = 0
 and exists (select 1 from tblParameter where Code = 'DEDUCT_TAX_FOR_SHORT_TERM' AND Value = '1')



 insert  into #tblTemporaryContractTax(EmployeeID,TaxPercentage,isLowSalary,PITStatus,DivisionID)
 select  EmployeeID,0.1,0,2,DivisionID from #tblEmployeeIDList
 where TerminateDate <=@FromDate
 and EmployeeID not in(select EmployeeID from #tblTemporaryContractTax)
 --and DivisionId in(Select DivisionID from tblDivision where Terminate_Mean_10PercentTax = 1)

 --UPDATE $ set isLowSalary = 1 where EmployeeID in (
 -- select EmployeeID from dbo.fn_CurrentContractListByDate(@ToDate) where  = 1
 --)

 --if @PROBATION_PERECNT >= 100.0
  -- rmức lương cũ
 insert into #tblSalDetail(EmployeeID,HireDate,EmployeeTypeID,SalaryHistoryID,FromDate,ToDate,BasicSalaryDefault,BasicSalary,Support,Support2,BasicSalaryOrg,SalCalRuleID,LatestSalEntry,BaseSalRegionalID,CurrencyCode,IsNet
 ,PayrollTypeCode,WorkingHoursPerDay,IsProbation,PositionID,EmployeeStatusID,RankID,LevelID,
 STD_WD,STD_WD_Schedule,AfterMaternity,LBIssueDate,Maternity,TerminateDate,Kilometer)
 select sh.EmployeeID,te.HireDate,te.EmployeeTypeID,sh.SalaryHistoryID,case when sh.Date < @FromDate then @FromDate else sh.Date end ,@ToDate,isnull(sh.Salary,0) + isnull(sh.Support_AL,0) + isnull(sh.Support2_AL,0),isnull(sh.Salary,0) + isnull(sh.Support_AL,0) + isnull(sh.Support2_AL,0),sh.Support_AL,sh.Support2_AL,isnull(sh.Salary,0) + isnull(sh.Support_AL,0) + isnull(sh.Support2_AL,0),sh.SalCalRuleID,1,sh.BaseSalRegionalID
 ,sh.CurrencyCode,sh.IsNet,sh.PayrollTypeCode,ISNULL(nullif(sh.WorkingHoursPerDay,0),8),iif(te.ProbationEndDate is not null and te.ProbationEndDate > sh.date,1,0) IsProbation
 ,te.PositionID,te.EmployeeStatusID,sh.RankID,sh.LevelID,26 as STD_WD,26 as STD_WD_Schedule,te.AfterMaternity,te.LBIssueDate,te.Maternity,te.TerminateDate,te.Kilometer
 from dbo.fn_CurrentSalaryHistoryIDByDate(@FromDate) s
 inner join tblSalaryHistory sh on s.SalaryHistoryID = sh.SalaryHistoryID
 inner join #tblEmployeeIDList as te on sh.EmployeeID = te.EmployeeID
 where sh.Date >= te.HireDate


 -- muc luong phat sinh moi trong thang
 insert into #tblSalDetail(EmployeeID,HireDate,EmployeeTypeID,SalaryHistoryID,FromDate,ToDate,BasicSalaryDefault,BasicSalary,Support,Support2,BasicSalaryOrg,SalCalRuleID,LatestSalEntry,BaseSalRegionalID
 ,CurrencyCode,IsNet,PayrollTypeCode,WorkingHoursPerDay,PositionID,EmployeeStatusID,RankID,LevelID,isNotAL,IsProbation,STD_WD,STD_WD_Schedule,AfterMaternity,LBIssueDate,Maternity,TerminateDate,Kilometer)
 select sh.EmployeeID,te.HireDate,te.EmployeeTypeID,sh.SalaryHistoryID,case when sh.Date < @FromDate then @FromDate else sh.Date end ,@ToDate,isnull(sh.Salary,0) + isnull(sh.Support_AL,0) + isnull(sh.Support2_AL,0)
 ,isnull(sh.Salary,0) + isnull(sh.Support_AL,0) + isnull(sh.Support2_AL,0),sh.Support_AL,sh.Support2_AL,isnull(sh.Salary,0) + isnull(sh.Support_AL,0) + isnull(sh.Support2_AL,0),sh.SalCalRuleID,1,sh.BaseSalRegionalID
 ,sh.CurrencyCode,sh.IsNet,sh.PayrollTypeCode,ISNULL(nullif(sh.WorkingHoursPerDay,0),8),te.PositionID,te.EmployeeStatusID,sh.RankID,sh.LevelID,sh.isNotAL,0,26 as STD_WD,26 as STD_WD_Schedule,te.AfterMaternity,te.LBIssueDate,te.Maternity,te.TerminateDate,te.Kilometer
 from tblSalaryHistory sh
 inner join #tblEmployeeIDList te on sh.EmployeeID = te.EmployeeID and sh.Date >= te.HireDate
 where sh.[Date] > @FromDate
 and not exists (select 1 from #tblSalDetail s where sh.SalaryHistoryID = s.SalaryHistoryID)
 and sh.Date<= @ToDate


 --Hiếu: Cập nhật số ngày chưa vào làm
 update #tblSalDetail set NotYetWork=(
  select count(1) from dbo.fn_datelist(@FromDate,dateadd(day,-1,s.HireDate)) WHERE DATEPART(WEEKDAY, date) <> 1 --ko tính chủ nhật
 ) from #tblSalDetail s
 where s.HireDate > @FromDate

 --Hiếu: cập nhật số ngày từ ngày nghỉ việc
 update #tblSalDetail set NotTermiWork=(
  select count(1) from dbo.fn_datelist(s.TerminateDate,@ToDate) d WHERE DATEPART(WEEKDAY, date) <> 1
 -- and not exists(select 1 from tblCalendarWorking c where c.EmployeeTypeID=s.EmployeeTypeID and c.Date=d.Date
       -- and (isnull(c.LeaveCode,'') in ('CH','PH','CL') or (isnull(c.LeaveCode,'')='AL') )
   -- )
 ) from #tblSalDetail s
 where s.TerminateDate <= @ToDate

 --Cập nhật lại Todate nếu tháng có 2 dòng lương
 update s1 set ToDate=dateadd(day,-1,s2.FromDate)
 from #tblSalDetail s1
 inner join #tblSalDetail s2 on s2.EmployeeID=s1.EmployeeID
 where s2.SalaryHistoryID > s1.SalaryHistoryID




 --Cập nhật ngày công chuẩn theo từ ngày đến ngày
 select EmployeeID,AttDate,LeaveCode into #tblAttendanceSummary from tblAttendanceSummary sa
 where AttDate between @FromDate and @ToDate
 and exists(select 1 from #tblEmployeeIDList te where te.EmployeeID=sa.EmployeeID and sa.AttDate between te.HireDate and te.LastWorkingDate)

 insert into #tblAttendanceSummary(EmployeeID,AttDate,LeaveCode)
select e.EmployeeID,c.Date,c.LeaveCode
 from #tblEmployeeIDList e
 inner join tblCalendarWorking as c on c.EmployeeTypeID=e.EmployeeTypeID
 where c.Date between @fromDate and @ToDate and not exists(select 1 from #tblAttendanceSummary a where a.EmployeeID=e.EmployeeID and a.AttDate=c.Date)

 --cập nhật ngày công  chuẩn full  tháng
 update #tblSalDetail set WD_Month=s.STD_WD
 from #tblSalDetail sa
 inner join (
 select s.EmployeeID,count(1) STD_WD from #tblAttendanceSummary s where s.AttDate between @FromDate and @ToDate
  and isnull(s.LeaveCode,'') not in ('PH','CH','CL') group by s.EmployeeID
 ) s on s.EmployeeID=sa.EmployeeID

 --dbo.fn_StdWorkingDay_FromDateToDate(@FromDate,@ToDate)
 --dbo.fn_StdWorkingDay_FromDateToDate(sa.FromDate,sa.ToDate)
 update #tblSalDetail set WD=s.STD_WD
 from #tblSalDetail sa
 CROSS APPLY (
 select s.EmployeeID,count(1) STD_WD from #tblAttendanceSummary s where s.AttDate between sa.FromDate and sa.ToDate
  and isnull(s.LeaveCode,'') not in ('PH','CH','CL') group by s.EmployeeID
 ) s
 where s.EmployeeID=sa.EmployeeID

 --Gop luong de tinh trung binh: NIVS khong dung
 -- update s1 set BasicSalary=ROUND(isnull(s1.BasicSalary,0)/s1.WD_Month * isnull(s1.WD,0)+ isnull(s2.BasicSalary,0)/s2.WD_Month * isnull(s2.WD,0),@ROUND_SALARY_UNIT)
 --,BasicSalaryOrg=ROUND(isnull(s1.BasicSalary,0)/s1.WD_Month * isnull(s1.WD,0)+ isnull(s2.BasicSalary,0)/s2.WD_Month * isnull(s2.WD,0),@ROUND_SALARY_UNIT)
 --from #tblSalDetail s1
 --inner join #tblSalDetail s2 on s2.EmployeeID=s1.EmployeeID
 --where s2.SalaryHistoryID < s1.SalaryHistoryID

 ----Xóa dòng lương cũ nhất
 -- delete s1 from #tblSalDetail s1 where exists(select 1 from #tblSalDetail s2 where s2.EmployeeID=s1.EmployeeID and s2.SalaryHistoryID > s1.SalaryHistoryID)

-- lấy dữ liệu bảng custom attendance ra
   select * Into #tblCustomAttendanceData from tblCustomAttendanceData c
   where Month = @Month and Year= @Year and Approved = 1 and
    c.EmployeeID in(select EmployeeID from #tblEmployeeIDList) and IsRetro = @CalculateRetro -- nhớ where vụ retro nhé

 alter table #tblCustomAttendanceData add PaidLeaves float(53),UnPaidLeaves float(53),TotalNonWorkingDays float(53)


 declare @CustomAttendanceQuery varchar(max) = ''
 select @CustomAttendanceQuery +='+isnull('+LeaveCode +',0)*'+CAST(lt.PaidRate as varchar(10))+'/100'
 from tblLeaveType lt
 where lt.PaidRate >0 and  lt.LeaveCode in(select Column_Name from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = 'tblCustomAttendanceData')

 declare @customAttendanceQuery_Unpaid varchar(max)  = ''
 select @customAttendanceQuery_Unpaid +='+isnull('+LeaveCode +',0)'
 from tblLeaveType lt
 where ISNULL(lt.PaidRate,0)  = 0 and  lt.LeaveCode in(select Column_Name from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = 'tblCustomAttendanceData')


 set @CustomAttendanceQuery  = 'update #tblCustomAttendanceData set PaidLeaves = 0'+@CustomAttendanceQuery + ',UnpaidLeaves = 0'+@customAttendanceQuery_Unpaid

-- update các giá chị cần thiết match up mới bảng truyền thống trrc giờ
exec( @CustomAttendanceQuery)


	CREATE TABLE #tblOTList (
		EmployeeID varchar(20),
		OTDate datetime,
		ApprovedHours float,
		OTKind int
	)

	IF @Month < 5 AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ImportPayrollCheck')
	BEGIN
		DECLARE @OTKind15 int, @OTKind20 int, @OTKind30 int
		SELECT TOP 1 @OTKind15 = OTKind FROM tblOvertimeSetting WHERE OvValue = 150
		SELECT TOP 1 @OTKind20 = OTKind FROM tblOvertimeSetting WHERE OvValue = 200
		SELECT TOP 1 @OTKind30 = OTKind FROM tblOvertimeSetting WHERE OvValue = 300

		SET @OTKind15 = ISNULL(@OTKind15, 1)
		SET @OTKind20 = ISNULL(@OTKind20, 2)
		SET @OTKind30 = ISNULL(@OTKind30, 3)

		;WITH CleanedImport AS (
			SELECT 
				CAST(ipc.Emp_ID AS VARCHAR(20)) AS Emp_ID,
				TRY_CAST(ipc.[1_5] AS FLOAT) AS OT15,
				TRY_CAST(ipc.[2] AS FLOAT) AS OT20,
				TRY_CAST(ipc.[3] AS FLOAT) AS OT30,
				ROW_NUMBER() OVER (PARTITION BY ipc.Emp_ID ORDER BY TRY_CAST(ipc.RowIndex AS INT) DESC) as rn
			FROM ImportPayrollCheck ipc
			WHERE ipc.Emp_ID IS NOT NULL AND ipc.Emp_ID <> ''
		)
		INSERT INTO #tblOTList(EmployeeID, OTDate, ApprovedHours, OTKind)
		SELECT e.EmployeeID, @ToDateTruncate, ipc.OT15, @OTKind15
		FROM #tblEmployeeIDList e
		INNER JOIN CleanedImport ipc ON e.EmployeeID = ipc.Emp_ID AND ipc.rn = 1
		WHERE ISNULL(ipc.OT15, 0) > 0
		UNION ALL
		SELECT e.EmployeeID, @ToDateTruncate, ipc.OT20, @OTKind20
		FROM #tblEmployeeIDList e
		INNER JOIN CleanedImport ipc ON e.EmployeeID = ipc.Emp_ID AND ipc.rn = 1
		WHERE ISNULL(ipc.OT20, 0) > 0
		UNION ALL
		SELECT e.EmployeeID, @ToDateTruncate, ipc.OT30, @OTKind30
		FROM #tblEmployeeIDList e
		INNER JOIN CleanedImport ipc ON e.EmployeeID = ipc.Emp_ID AND ipc.rn = 1
		WHERE ISNULL(ipc.OT30, 0) > 0
	END
	ELSE
	BEGIN
		INSERT INTO #tblOTList(EmployeeID, OTDate, ApprovedHours, OTKind)
		select ot.EmployeeID,ot.OTDate,ot.ApprovedHours,ot.OTKind
		from tblOTList ot where ot.OTDate between @FromDate and @ToDate
		and  ot.Approved = 1 and ApprovedHours <>0
		and ot.EmployeeID in(select te.EmployeeID from #tblEmployeeIDList te
							except
							select c.EmployeeID from #tblCustomAttendanceData  c
							)
	END

 declare @CustomOTInsert varchar(max) = ''
 create table #tempDataForOT(EmployeeID varchar(20),OTKindID int ,OTAmountHours float(53))

 select @CustomOTInsert +='
 insert into #tempDataForOT(EmployeeID,OTKindID,OTAmountHours)
 select EmployeeID,'''+CAST(OTKind as varchar(10))+''','+ColumnNameOn_CustomAttendanceTable +' as LvAmountDays
 from #tblCustomAttendanceData where '+ColumnNameOn_CustomAttendanceTable +' <>0' from tblOvertimeSetting ov
 where ov.ColumnNameOn_CustomAttendanceTable in(select COLUMN_NAME from INFORMATION_SCHEMA.COLUMNS c where c.TABLE_NAME = 'tblCustomAttendanceData')

 exec(@CustomOTInsert)

 insert into #tblOTList(EmployeeID,OTDate,ApprovedHours,OTKind)
 select EmployeeID,@ToDateTruncate as  OTDate,OTAmountHours  as ApprovedHours,OTKindID as OTKind from #tempDataForOT



 drop table #tempDataForOT

 -- update lại theo tỷ giá nếu có
 update sal set sal.BasicSalary = sal.BasicSalary * ISNULL(cs.[ExchangeRate],1)
 ,sal.BasicSalaryOrg = sal.BasicSalary * ISNULL(cs.[ExchangeRate],1)
 ,ExchangeRate =cs.[ExchangeRate]
 from #tblSalDetail sal
 inner join #EmployeeExchangeRate cs on sal.EmployeeID = cs.EmployeeID and cs.CurrencyCode = sal.CurrencyCode

  --Cập nhật 1 số phụ cấp
if object_id('tempdb..#tmpAllowanCustom') is not null drop table #tmpAllowanCustom;

create table #tmpAllowanCustom (
 EmployeeID varchar(30), Salary money, Support_AL money, Support2_AL money, Pos_AL money,
 Qualification_AL money, Skill_AL money, Responsibility_AL money, Language_AL money,
 Livingsupport1_AL money, TCCD_AL money, FORKLIFT_AL money, BMC_AL money, PCCC_AL money, ATVSV_AL money,
 PerfectAtt_AL money, Breakfast_AL money, House_AL money, Transport_AL money, TCPN_AL money, Union_AL money,
 TotalIncome money
)

exec sp_SalaryByDate_List @LoginID, 'vn', @toDate, '#tmpAllowanCustom'

-- Select ra xem thử (hoặc mày dùng để join tiếp thì tùy)

 -- nếu có thông tin lương có currencyCode <>'VND' mà chưa thiết lập tỷ giá tháng này thì phải thiết lập tỷ giá trước khi tính lương
 if exists(select 1 from #tblSalDetail where isnull(CurrencyCode,'VND') <>'VND' and ExchangeRate is null )
 begin
 insert into tblProcessErrorMessage(ErrorType,ErrorDetail,LoginID)--,ResolveLink)
  select 'Exchange Rate not seted!','Exchange rate for "'+CurrencyCode+'" is not seted!, Please access Function "Currency Setting" first!' ,@loginID-1000
  --,N'Object=MnuMDT150|Params=txtFilter=&cbx@Month='+cast(@Month as varchar(2))+'&cbx@Year='+cast(@year as varchar(4))+'|Text=Currency Setting'
  from #tblSalDetail where isnull(CurrencyCode,'VND') <>'VND' and ExchangeRate is null
  return;
 end

 if @PROBATION_PERECNT < 100.0
 begin
  --cuoi thang hoac thang sau het thu viec
  UPDATE #tblSalDetail SET BasicSalaryOrg = BasicSalary, BasicSalary = BasicSalary*@PROBATION_PERECNT/100.0
  from #tblSalDetail sh inner join #tblEmployeeIDList te on sh.EmployeeID = te.EmployeeID
  where ProbationEndDate >= @ToDateTruncate and @PROBATION_PERECNT > 0 and te.HireDate <> te.ProbationEndDate

  --het thu viec trong thang nay
  UPDATE #tblSalDetail SET FromDate = DATEADD(day,1,ProbationEndDate)
  from #tblSalDetail sh inner join #tblEmployeeIDList te on sh.EmployeeID = te.EmployeeID
  where @PROBATION_PERECNT > 0 and te.ProbationEndDate > @FromDate and ProbationEndDate < @ToDateTruncate and te.HireDate <> te.ProbationEndDate
 DECLARE @MaxSalaryHistoryId BIGINT
 SET @MaxSalaryHistoryId = (SELECT MAX(SalaryHistoryID) FROM #tblSalDetail)
  insert into #tblSalDetail(EmployeeID,SalaryHistoryID,ProbationSalaryHistoryID,FromDate,ToDate,BasicSalaryOrg,BasicSalary,SalCalRuleID,LatestSalEntry,BaseSalRegionalID,IsNet,PayrollTypeCode,WorkingHoursPerDay,CurrencyCode)
  select sh.EmployeeID,SalaryHistoryID, SalaryHistoryID + @MaxSalaryHistoryId ,@FromDate,te.ProbationEndDate,sh.BasicSalary,sh.BasicSalary*@PROBATION_PERECNT/100.0,sh.SalCalRuleID,1,sh.BaseSalRegionalID,IsNet,PayrollTypeCode,sh.WorkingHoursPerDay,sh.CurrencyCode
  from #tblSalDetail sh inner join #tblEmployeeIDList te on sh.EmployeeID = te.EmployeeID
  where @PROBATION_PERECNT > 0 and te.ProbationEndDate > @FromDate and ProbationEndDate < @ToDateTruncate and te.HireDate <> te.ProbationEndDate
 end

 -- bao loi sai ngay hieu luc luong, hoac chua nhap thong tin luong
 insert into tblProcessErrorMessage(ErrorType,ErrorDetail,LoginID,ResolveLink)
 select 'Wrong salary info',N'Bạn chưa nhập thông tin lương hoặc ngày hiệu lực lương lớn hơn kỳ tính lương',@LoginID,'Object=MnuHRS145'
  from #tblEmployeeIDList e where not exists (select 1 from #tblSalDetail s where e.employeeID = s.employeeID )
 UPDATE s1 set ToDate = dateadd(second,-1,s2.FromDate) from #tblSalDetail s1
 cross apply (select MIN(FromDate) FromDate from #tblSalDetail s2 where s1.EmployeeID = s2.EmployeeID and s1.FromDate < s2.FromDate) s2
 where s2.FromDate is not null
 UPDATE #tblSalDetail set isTwoSalLevel = 0
 UPDATE #tblSalDetail set LatestSalEntry = 0 where ToDate < @ToDate
 UPDATE #tblSalDetail set isTwoSalLevel = 1 where EmployeeID in (
 select EmployeeID from #tblSalDetail s group by EmployeeID having COUNT(1) > 1
 )
  -- standard working day
 -- ngày công chuẩn -- người vận chuyển lên đây để chạy dc cho những thằng import custom attendance data

 --if not exists (select 1 from tblWorkingDaySetting s where Month = @Month AND YEAR = @Year
 --and (exists (select 1 from #tblEmployeeIDList e where s.EmployeeTypeID = e.EmployeeTypeID)
 --or s.EmployeeTypeID = -1)
 --)
 ----exec sp_WorkingDaySetting @Month = @Month, @Year = @Year, @LoginID = @LoginID

 ----tung nhan vien
 --UPDATE s
 -- set STD_WD = ee.WorkingDays_Std
 --, STD_WD_Schedule = ee.WorkingDays_Std
 -- from #tblSalDetail s
 -- INNER JOIN tblWorkingDaySettingPerEE ee ON s.EmployeeID = ee.EMployeeID AND ee.Month = @Month and ee.Year = @Year

 ---- tung loai nhan vien
 --UPDATE s set STD_WD = std.WorkingDays_Std, STD_WD_Schedule = std.WorkingDays_Std from #tblSalDetail s inner join #tblEmployeeIDList e on s.EmployeeID = e.EmployeeID
 --inner join tblWorkingDaySetting std on e.EmployeeTypeID = std.EmployeeTypeID and std.Month = @Month and std.Year = @Year
 -- -- toan cong ty
 --UPDATE s set STD_WD = (select std.WorkingDays_Std from tblWorkingDaySetting std where std.EmployeeTypeID = -1 and std.Month = @Month and std.Year = @Year)
 --from #tblSalDetail s
 --where s.STD_WD is null

 --UPDATE #tblSalDetail set STD_WD_Schedule = STD_WD where STD_WD_Schedule is null

 --UPDATE #tblSalDetail set STD_WD = sc.FixedStdPerMonth from #tblSalDetail s
 --inner join tblSalaryCalculationRule sc on s.SalCalRuleID = sc.SalCalRuleID and sc.IsFixedStd =1
 --and not exists (select 1 from #tblEmployeeIDList e where e.EmployeeID = s.EmployeeID and (e.NewStaff = 1 or e.TerminatedStaff = 1))
 --Hiếu: lấy cứng công chuẩn luôn: Văn phòng = 22, Sản xuất + Kíp = 26
 update s set s.STD_WD = case when e.EmployeeTypeID = 0 then 22 else 26 end,
 s.STD_WD_Schedule = case when e.EmployeeTypeID = 0 then 22 else 26 end,
 s.WorkingHoursPerDay = case when e.EmployeeTypeID = 0 then 9 else 8 end
 from #tblSalDetail s inner join #tblEmployeeIDList e on s.EmployeeID = e.EmployeeID

  -- lấy ngày công ở đây
  --create table #Tadata(EmployeeID varchar(20) ,Attdate date,HireDate date, EmployeeStatusID int
  --,HolidayStatus int
  --, WorkingTime float(53)
  --, Std_Hour_PerDays float(53)
  --, Lvamount float(53)
  --, PaidAmount_Des float(53)
  --, UnpaidAmount_Des float(53)
  --, SalaryHistoryID int
  --,CutSI bit)

  --exec sp_WorkingTimeProvider @Month = @Month,@Year = @Year, @fromdate = @FromDate,@todate = @ToDate,@loginId = @LoginID


--if(OBJECT_ID('SALCAL_CUSTOMIZE_TADATA' )is null)
--begin
--exec('CREATE PROCEDURE dbo.SALCAL_CUSTOMIZE_TADATA
--(
-- @StopUPDATE bit output,
-- @Month int,
-- @Year int,
-- @FromDate datetime,
-- @ToDate datetime,
-- @LoginID int,
-- @PeriodID int = 0,
-- @EmployeeID nvarchar(20) = ''-1''
--)
--as
--begin
-- SET NOCOUNT ON;
--end')
--end
--SET @StopUPDATE = 0
--exec SALCAL_CUSTOMIZE_TADATA @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

-- IF @StopUPDATE = 0
-- BEGIN

--  delete #Tadata where EmployeeID not in(select EmployeeID from #tblEmployeeIDList)
--  update #Tadata set SalaryHistoryID = ISNULL(sal.ProbationSalaryHistoryID, sal.SalaryHistoryID)
--  from #Tadata  ta
--  inner join #tblSalDetail sal on ta.EmployeeID= sal.EmployeeID and ta.Attdate  between sal.FromDate and sal.ToDate

--  /*
--  update #Tadata set SalaryHistoryID = ISNULL(sal.ProbationSalaryHistoryID, sal.SalaryHistoryID)
--  ,WorkingTime = case when ISNULL(sc.IsSTDMinusUnpaidLeave,0) =0 or WorkingTime is not null then WorkingTime else
--  case when
--  HolidayStatus = 0 and CutSI = 0 and ISNULL(Lvamount,0) <8 then 8 - ISNULL(Lvamount,0) else 0 end
--  end
--  from #Tadata  ta
--  inner join #tblSalDetail sal on ta.EmployeeID= sal.EmployeeID and ta.Attdate  between sal.FromDate and sal.ToDate
--  inner join tblSalaryCalculationRule sc on sal.SalCalRuleID = sc.SalCalRuleID
--  */
--  delete #Tadata where SalaryHistoryID is null


--  --delete đi để câu dưới nó đừng tính nữa mất thời gian
--  delete #Tadata  where EmployeeID in(select EmployeeID from #tblCustomAttendanceData)
-- END

-- select EmployeeID,ta.SalaryHistoryID,SUM(case when ISNULL(HolidayStatus,0)<>1 then 1 else 0 end )as STD_PerHistoryID
-- ,ROUND(SUM(case when ISNULL(HolidayStatus,0) = 0 THEN ta.WorkingTime /isnull(ta.Std_Hour_PerDays,8) ELSE 0 END),@ROUND_TOTAL_WORKINGDAYS) as AttDays
-- ,SUM(ta.PaidAmount_Des/isnull(ta.Std_Hour_PerDays,8)) as PaidLeaves
-- ,SUM(ta.UnpaidAmount_Des/isnull(ta.Std_Hour_PerDays,8)) as UnPaidLeaves
-- ,SUM(case when HolidayStatus = 1 then 1 else 0 end ) as TotalSunDay
-- ,SUM(case when CutSI = 1 and HolidayStatus <> 1 then 1 else 0 end ) TotalNonWorkingDays
-- into #tblSal_AttendanceData_PerHistory
-- from #Tadata ta
-- group by EmployeeID,ta.SalaryHistoryID

  --Hiếu: lấy công từ bảng attendaceSumarty

   select sa.*,ROUND(IOMinutesDeduct/60.0,1) DeductionHours
 ,cast(null as float) Lvamount, cast(null as float) PaidAmount_Des, cast(null as float) UnpaidAmount_Des,
 cast(null as float) PaidAmount_Allowance_Des
 --,cast(null as float) UnpaidAmount_Allowance_Des
,case when sa.HolidayStatus = 0
       and (isnull(sa.WorkingTime,0) > 0
            or (sa.AttStart is not null and sa.AttEnd is not null and datediff(minute, sa.AttStart, sa.AttEnd) > 240)
           )
       then 1 else 0 end AttDays
 ,case when isnull(sa.WorkingTime,0) = 0 and sa.HolidayStatus>0 /*and  datepart(dw,AttDate) = 1 and isnull(sa.ApprovedHours,0) > 0*/ and sa.AttStart is not null and sa.AttEnd is not null  then 1 else 0 end WorkingDayoff
 ,cast(null as int) LeaveNotTran -- nghỉ trừ ko tính trợ cấp đi lại
 ,cast(null as int) LeaveCC -- nghỉ trừ chuyên cần
 ,cast(null as int) LeaveCH2PH3
 ,cast(null as int) LeaveNN --số ngày nghỉ nửa ngày
 ,cast(null as int) UnpaidNotBH --nghỉ ko tính trừ bảo hiểm (nghỉ thai sản, sau thai sản)
 ,te.EmployeeTypeID,te.Maternity ,te.AfterMaternity
 ,cast(null as bigint) SalaryHistoryID
 into #TAData
 from tblAttendanceSummary sa
 inner join #tblEmployeeIDList as te on te.EmployeeID=sa.EmployeeID
 where AttDate between @FromDate and @ToDate
 and sa.AttDate between te.HireDate and te.LastWorkingDate
 and exists(select 1 from #tblSalDetail s where s.EmployeeID=sa.EmployeeID)

  --Hiếu: đánh dấu SalaryHistoryID cho từng dòng ngày công để tách 2 dòng lương
  update #TAData set SalaryHistoryID = ISNULL(sal.ProbationSalaryHistoryID, sal.SalaryHistoryID)
  from #TAData ta
  inner join #tblSalDetail sal on ta.EmployeeID = sal.EmployeeID and ta.AttDate between sal.FromDate and sal.ToDate
 --Hiếu: đánh dấu số giờ nghỉ nè
 update #TAData set LvAmount = 0.5,LeaveNN=1 from #TAData where LeaveStatus in (1,2)
 update #TAData set LvAmount = 1
 from #TAData where LeaveCode is not null and isnull(WorkingTime,0) = 0 and LeaveCode not in ('WK')

 update #TAData set LeaveCH2PH3 = 1 from #TAData ta where LeaveCode is not null
 and isnull(WorkingTime,0) = 0 and isnull(ApprovedHours,0)=0
 and (LeaveCode in ('PH') or (LeaveCode in ('CL','CH') and exists(select 1 from tblCalendarWorking ca
    where ca.Date=ta.AttDate and ca.EmployeeTypeID=ta.EmployeeTypeID)))
 and (Maternity is null or AttDate < Maternity) and (AfterMaternity is null or AttDate >= AfterMaternity)

 update #TAData set PaidAmount_Des = ta.LvAmount*iif(ty.PaidRate>0,100,0)/100.0,
 PaidAmount_Allowance_Des = ta.LvAmount*iif(ty.PaidRate>0,100,0)/100.0
 ,UnpaidAmount_Des = ta.LvAmount*iif(100 - ty.PaidRate < 100 ,0,100 - ty.PaidRate)/100.0
 --,UnpaidAmount_Allowance_Des = ta.LvAmount*(100-iif(ty.PaidRate>0,100,0))/100.0
 ,UnpaidNotBH=case when ty.PaidByInsSalary=1 and isnull(ty.PaidRate,0) = 0 then 1 else 0 end
 from #TAData ta
 inner join tblLeaveType ty on ta.LeaveCode = ty.LeaveCode
 where ta.LvAmount > 0
 --LeaveNotTran : chỉ tính nghỉ cá nhân, nghỉ nửa ngày ko tính, nghỉ cty ko tính
 update #TAData set LeaveNotTran=iif(LvAmount=1,1,0)

 --nghỉ trừ chuyên cần
 update #TAData set LeaveCC=1
 from #TAData ta
 inner join tblLeaveType ty on ta.LeaveCode = ty.LeaveCode
 where ty.CutDiligent=1

 --Bảng tổng hợp
 select EmployeeID, ta.SalaryHistoryID, SUM(iif(ta.HolidayStatus > 0, 0, 1)) as STD_PerHistoryID
   ,isnull(sum(ta.AttDays),0) as AttDays
   ,isnull(SUM(ta.PaidAmount_Des),0) as PaidLeaves
   ,isnull(SUM(ta.PaidAmount_Allowance_Des),0) as PaidLeaves_Allowance
   ,isnull(SUM(ta.UnpaidAmount_Des),0) as UnPaidLeaves
   --,isnull(SUM(ta.UnpaidAmount_Allowance_Des),0) as UnPaidLeaves_Allowance
   ,isnull(SUM(ta.WorkingDayoff),0) as WorkingDayoff
   --,SUM(iif(ta.LeaveCode = 'WK',1,0)) as TotalSunDay
   ,SUM(iif(ta.LeaveCode = 'UL',1,0)) TotalNonWorkingDays
   ,SUM(iif(ta.LeaveCode in('ML'),1,0)) ML_Leaves
   ,isnull(SUM(ta.LeaveNotTran),0) LeaveNotTran
   ,isnull(SUM(ta.DeductionHours),0) DeductionHours --đi trễ về sớm
   ,isnull(SUM(ta.LeaveCC),0) LeaveCC
   ,isnull(SUM(ta.LeaveCH2PH3),0) LeaveCH2PH3
   ,isnull(SUM(ta.LeaveNN),0) LeaveNN
   ,isnull(SUM(ta.UnpaidNotBH),0) UnpaidNotBH
   into #tblSal_AttendanceData_PerHistory
   from #Tadata  ta
   group by EmployeeID, ta.SalaryHistoryID
  --Nếu ngày làm việc thực tế nhỏ hơn 13 thì trừ những ngày nghỉ nửa ngày
   update #tblSal_AttendanceData_PerHistory set AttDays=case when isnull(AttDays,0) <= 13 then isnull(AttDays,0) - ROUND(isnull(LeaveNN,0) * 0.5,0) else AttDays end
   -----------------------------------
   select EmployeeID,sum(STD_PerHistoryID) as STDWorkingDays
   ,SUM(AttDays) as AttDays
   ,SUM(PaidLeaves) as PaidLeaves
   ,SUM(PaidLeaves_Allowance) as PaidLeaves_Allowance
   ,SUM(UnPaidLeaves) as UnPaidLeaves
   ,sum(WorkingDayoff) as WorkingDayoff
--,SUM(TotalSunDay) as TotalSunDay
   ,SUM(DeductionHours) as DeductionHours
   ,sum(TotalNonWorkingDays) as TotalNonWorkingDays
   ,sum(LeaveNotTran) as LeaveNotTran
   ,sum(LeaveCC) as LeaveCC
   ,sum(LeaveCH2PH3) as LeaveCH2PH3
   ,sum(LeaveNN) as LeaveNN
   ,sum(UnpaidNotBH) as UnpaidNotBH
   into #tblSal_AttendanceData
   from #tblSal_AttendanceData_PerHistory
   group by EmployeeID

   update #tblSal_AttendanceData set STDWorkingDays = sd.STD_WD
   from #tblSal_AttendanceData sal
   inner join #tblSalDetail sd on sal.employeeId = sd.EmployeeID and sd.LatestSalEntry = 1

------------------------------Calculate salary per day------------------------------------------
 -- Lương tính tăng ca = Lương CB + Support 1,2 + Chức vụ + Chuyên môn + Kỹ năng + Trách nhiệm + Ngoại ngữ
 update sa
 set OTSalary = isnull(sa.BasicSalary, 0) + isnull(al.Pos_AL, 0)
     + isnull(al.Qualification_AL, 0) + isnull(al.Skill_AL, 0) +
                 isnull(al.Responsibility_AL, 0) + isnull(al.Language_AL, 0),

  -- Lương tính BH = Lương CB (Default) + Support 1,2 + Chức vụ + Chuyên môn + Kỹ năng + Trách nhiệm + Ngoại ngữ
  InsSalary = isnull(sa.BasicSalary, 0)  + isnull(al.Pos_AL, 0)
      + isnull(al.Qualification_AL, 0) + isnull(al.Skill_AL, 0) + isnull(al.Responsibility_AL, 0) + isnull(al.Language_AL, 0)
 from #tblSalDetail sa
 left join #tmpAllowanCustom al on al.EmployeeID = sa.EmployeeID

 --Nếu có tỷ giá
 update sal set sal.OTSalary = sal.OTSalary * ISNULL(cs.[ExchangeRate],1)
 from #tblSalDetail sal
 inner join #EmployeeExchangeRate cs on sal.EmployeeID = cs.EmployeeID and cs.CurrencyCode = sal.CurrencyCode

 --lương 1 ngày công
 UPDATE #tblSalDetail SET SalaryPerDay = BasicSalary/STD_WD ,SalaryPerDayOT = OTSalary/STD_WD,
 NotWorkSalary=(BasicSalary/STD_WD) * (isnull(NotYetWork,0) + isnull(NotTermiWork,0) )

 ------------------------------Calculate salary per hour------------------------------------------
 update #tblSalDetail set SalaryPerHour =SalaryPerDay/WorkingHoursPerDay , SalaryPerHourOT= SalaryPerDayOT/WorkingHoursPerDay


 --Insert into Salary PITAmt table
 SELECT EmployeeID,'Has no salary entry' as Reason, CAST(1 as bit) as DoNotSalCal
 into #TableVarSalError
 FROM #tblEmployeeIDList a
 WHERE EmployeeID IN (SELECT DISTINCT EmployeeID FROM #tblSalDetail where TotalSalary <= 0)

 DELETE FROM #tblSalDetail WHERE EmployeeID in (select EmployeeID from #TableVarSalError where DoNotSalCal = 1)
 --DELETE FROM #tblEmployeeIDList WHERE EmployeeID in (select EmployeeID from #TableVarSalError where DoNotSalCal = 1)
 


------------------------------Calculate Leave---------------------------------

if(OBJECT_ID('SALCAL_LEAVE_AUTOMATIC_FINISHED' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_LEAVE_AUTOMATIC_FINISHED
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20) = ''-1''
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_LEAVE_AUTOMATIC_FINISHED @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID


create TABLE #DataLeave
(
 EmployeeID varchar(20),
 LeaveDate datetime,
 LeaveCode varchar(20),
 LeaveStatus int ,
 LeaveDays float,
 LeaveHours float,
 PaidRate float
)


create table #TableVarLeaveAmount (
  EmployeeID varchar(20)
 ,SalaryHistoryID bigint
 ,ContractSalary float(53)
 ,LeaveDate datetime
 ,LeaveCode varchar(20)
 ,PaidRate float
 ,UnpaidRate float
 ,LeaveDays float
 ,LeaveHours float
 ,SalaryPerDay float(53)

 ,AmountPaid float(53)
 ,AmountDeduct float(53)
)


-------------------------Leave Days---------------------------------------
--Bảng nghỉ
select lv.EmployeeID,lv.LeaveCode,iif(lv.LeaveStatus=3,1,0.5) LvAmount,lv.LeaveDate, lt.PaidRate,lv.LeaveStatus,lt.CutDiligent,ISNULL(lt.LeaveCategory,0) as LeaveCategory
into #tblLvHistory
from tblLvHistory lv
inner join tblLeaveType lt on lv.LeaveCode = lt.LeaveCode
and exists(select 1 from #tblEmployeeIDList te where te.EmployeeID=lv.EmployeeID and lv.LeaveDate
between te.HireDate and te.LastWorkingDate)
and lv.LeaveDate between @FromDate and @ToDate

delete lv
from #tblLvHistory lv
inner join #tblAttendanceSummary sa on sa.EmployeeID = lv.EmployeeID and sa.AttDate = lv.LeaveDate
where sa.LeaveCode is null

INSERT INTO #DataLeave (EmployeeID, LeaveDate,LeaveCode, LeaveStatus, LeaveDays,PaidRate)
select lv.EmployeeID,lv.LeaveDate,lv.LeaveCode ,lv.LeaveStatus,lv.LvAmount,lv.PaidRate
from #tblLvHistory lv
where  lv.LeaveCategory = 1 and Lv.LeaveCode not in ('FWC','WK','PH','CH','CL')

--Remove illegal records
--DELETE l FROM #DataLeave l WHERE datename(dw,l.LeaveDate) = 'Sunday' and exists (select 1 from tblWSchedule ws where ws.EmployeeID = l.EmployeeID and ws.ScheduleDate = l.LeaveDate and ws.HolidayStatus >0)

-------------------------Leave Amount---------------------------------------
INSERT INTO #TableVarLeaveAmount(EmployeeID,LeaveCode,LeaveDays,LeaveHours, LeaveDate,PaidRate ,UnpaidRate,SalaryHistoryID,SalaryPerDay)
(SELECT t.EmployeeID
,LeaveCode
,SUM(ISNULL(LeaveDays,0))
,SUM(ISNULL(LeaveHours,0))
,LeaveDate
,PaidRate
, iif(100 - PaidRate < 100 ,0,100 - PaidRate)
,SalaryHistoryID,MAX(SalaryPerDay) as SalaryPerDay
FROM #DataLeave t
inner join #tblSalDetail sal
on t.EmployeeID = sal.EmployeeID --and t.LeaveDate between FromDate and ToDate
GROUP BY t.EmployeeID, LeaveCode,LeaveDate,PaidRate,SalaryHistoryID)

---------------------------------------------------------------------------------------

UPDATE #TableVarLeaveAmount
SET AmountPaid = (PaidRate/100.00) * LeaveDays* SalaryPerDay -- ContractSalary * (PaidRate/100.00) * (LeaveDays/TotalDays) --chinh xac hon lay SalaryPerDays * LeaveDays
 ,AmountDeduct =(UnpaidRate/100.00) * LeaveDays* SalaryPerDay-- ContractSalary * (UnpaidRate/100.00) * (LeaveDays/TotalDays) --chinh xac hon lay SalaryPerDays * LeaveDays

-- tính tổng các ngày ko đi làm
UPDATE #tblSalDetail set UnpaidLeaveAmount = ROUND(tmp.AmountDeduct,@ROUND_SALARY_UNIT)
from #tblSalDetail sal
inner join tblSalaryCalculationRule sc on sal.SalCalRuleID = sc.SalCalRuleID
--and sc.IsSTDMinusUnpaidLeave =1 -- nếu là STD trừ đi ngày nghỉ
inner join (
SELECT EmployeeID,SalaryHistoryID ,SUM(ISNULL(AmountDeduct,0)) AmountDeduct FROM #TableVarLeaveAmount
GROUP BY EmployeeID,SalaryHistoryID)
tmp on sal.EmployeeID = tmp.EmployeeID and sal.SalaryHistoryID = tmp.SalaryHistoryID

-- tính tổng các ngày ko đi làm
IF @Month < 5 AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ImportPayrollCheck')
BEGIN
	-- Xóa các dòng trùng lặp cũ trong bảng ImportPayrollCheck, chỉ giữ lại dòng mới nhất (dựa trên RowIndex)
	;WITH DuplicateImport AS (
		SELECT 
			Emp_ID,
			ROW_NUMBER() OVER (PARTITION BY Emp_ID ORDER BY TRY_CAST(RowIndex AS INT) DESC) as rn
		FROM ImportPayrollCheck
		WHERE Emp_ID IS NOT NULL AND Emp_ID <> ''
	)
	DELETE FROM DuplicateImport WHERE rn > 1

	-- Sử dụng CTE CleanedImport để lấy dữ liệu đã làm sạch
	;WITH CleanedImport AS (
		SELECT 
			CAST(ipc.Emp_ID AS VARCHAR(20)) AS Emp_ID,
			TRY_CAST(ipc.Workdays AS FLOAT) AS Workdays,
			TRY_CAST(ipc.LA1 AS FLOAT) AS LA1,
			TRY_CAST(ipc.EL1 AS FLOAT) AS EL1
		FROM ImportPayrollCheck ipc
	)
	-- Cập nhật công thực tế và reset các loại nghỉ từ bảng lương final (Dùng cho testing)
	UPDATE sal
	SET sal.DaysOfSalEntry = ipc.Workdays
	FROM #tblSalDetail sal
	INNER JOIN CleanedImport ipc ON sal.EmployeeID = ipc.Emp_ID

	-- Cập nhật đồng bộ các loại ngày công, ngày phép, ngày nghỉ lễ/bù cty, ngày nghỉ không lương dựa trên dữ liệu import
	;WITH CompanyHolidays AS (
		SELECT 
			e.EmployeeID,
			COUNT(1) AS ActiveCompanyHolidays
		FROM #tblEmployeeIDList e
		INNER JOIN tblCalendarWorking c ON c.EmployeeTypeID = e.EmployeeTypeID
		WHERE c.Date BETWEEN @FromDate AND @ToDate
			AND c.Date BETWEEN e.HireDate AND ISNULL(e.LastWorkingDate, @ToDate)
			AND c.HolidayStatus > 0
			AND c.LeaveCode IN ('CH', 'PH')
		GROUP BY e.EmployeeID
	),
	CleanedImport AS (
		SELECT 
			CAST(ipc.Emp_ID AS VARCHAR(20)) AS Emp_ID,
			TRY_CAST(ipc.Workdays AS FLOAT) AS Workdays,
			TRY_CAST(ipc.LA1 AS FLOAT) AS LA1,
			TRY_CAST(ipc.EL1 AS FLOAT) AS EL1
		FROM ImportPayrollCheck ipc
	)
	UPDATE att
	SET 
		att.LeaveCH2PH3 = CASE 
			WHEN ipc.Workdays < ISNULL(h.ActiveCompanyHolidays, 0) THEN ipc.Workdays 
			ELSE ISNULL(h.ActiveCompanyHolidays, 0) 
		END,
		att.PaidLeaves = 0,
		att.PaidLeaves_Allowance = 0,
		att.AttDays = ipc.Workdays - 
			(CASE WHEN ipc.Workdays < ISNULL(h.ActiveCompanyHolidays, 0) THEN ipc.Workdays ELSE ISNULL(h.ActiveCompanyHolidays, 0) END),
		att.UnPaidLeaves = CASE 
			WHEN sal.STD_WD > ipc.Workdays THEN sal.STD_WD - ipc.Workdays 
			ELSE 0 
		END,
		att.WorkingDayoff = 0,
		att.TotalNonWorkingDays = CASE 
			WHEN sal.STD_WD > ipc.Workdays THEN sal.STD_WD - ipc.Workdays 
			ELSE 0 
		END,
		att.LeaveNotTran = CASE 
			WHEN sal.STD_WD > ipc.Workdays THEN sal.STD_WD - ipc.Workdays 
			ELSE 0 
		END,
		att.LeaveCC = CASE 
			WHEN sal.STD_WD > ipc.Workdays THEN sal.STD_WD - ipc.Workdays 
			ELSE 0 
		END,
		att.LeaveNN = 0,
		att.UnpaidNotBH = 0,
		att.DeductionHours = ISNULL(ipc.LA1, 0) + ISNULL(ipc.EL1, 0)
	FROM #tblSal_AttendanceData_PerHistory att
	INNER JOIN CleanedImport ipc ON att.EmployeeID = ipc.Emp_ID
	LEFT JOIN CompanyHolidays h ON att.EmployeeID = h.EmployeeID
	INNER JOIN #tblSalDetail sal ON att.EmployeeID = sal.EmployeeID AND sal.LatestSalEntry = 1

	-- Cập nhật đồng bộ tương tự cho bảng #tblSal_AttendanceData
	;WITH CompanyHolidays AS (
		SELECT 
			e.EmployeeID,
			COUNT(1) AS ActiveCompanyHolidays
		FROM #tblEmployeeIDList e
		INNER JOIN tblCalendarWorking c ON c.EmployeeTypeID = e.EmployeeTypeID
		WHERE c.Date BETWEEN @FromDate AND @ToDate
			AND c.Date BETWEEN e.HireDate AND ISNULL(e.LastWorkingDate, @ToDate)
			AND c.HolidayStatus > 0
			AND c.LeaveCode IN ('CH', 'PH')
		GROUP BY e.EmployeeID
	),
	CleanedImport AS (
		SELECT 
			CAST(ipc.Emp_ID AS VARCHAR(20)) AS Emp_ID,
			TRY_CAST(ipc.Workdays AS FLOAT) AS Workdays,
			TRY_CAST(ipc.LA1 AS FLOAT) AS LA1,
			TRY_CAST(ipc.EL1 AS FLOAT) AS EL1
		FROM ImportPayrollCheck ipc
	)
	UPDATE att
	SET 
		att.LeaveCH2PH3 = CASE 
			WHEN ipc.Workdays < ISNULL(h.ActiveCompanyHolidays, 0) THEN ipc.Workdays 
			ELSE ISNULL(h.ActiveCompanyHolidays, 0) 
		END,
		att.PaidLeaves = 0,
		att.PaidLeaves_Allowance = 0,
		att.AttDays = ipc.Workdays - 
			(CASE WHEN ipc.Workdays < ISNULL(h.ActiveCompanyHolidays, 0) THEN ipc.Workdays ELSE ISNULL(h.ActiveCompanyHolidays, 0) END),
		att.UnPaidLeaves = CASE 
			WHEN sal.STD_WD > ipc.Workdays THEN sal.STD_WD - ipc.Workdays 
			ELSE 0 
		END,
		att.WorkingDayoff = 0,
		att.TotalNonWorkingDays = CASE 
			WHEN sal.STD_WD > ipc.Workdays THEN sal.STD_WD - ipc.Workdays 
			ELSE 0 
		END,
		att.LeaveNotTran = CASE 
			WHEN sal.STD_WD > ipc.Workdays THEN sal.STD_WD - ipc.Workdays 
			ELSE 0 
		END,
		att.LeaveCC = CASE 
			WHEN sal.STD_WD > ipc.Workdays THEN sal.STD_WD - ipc.Workdays 
			ELSE 0 
		END,
		att.LeaveNN = 0,
		att.UnpaidNotBH = 0,
		att.DeductionHours = ISNULL(ipc.LA1, 0) + ISNULL(ipc.EL1, 0)
	FROM #tblSal_AttendanceData att
	INNER JOIN CleanedImport ipc ON att.EmployeeID = ipc.Emp_ID
	LEFT JOIN CompanyHolidays h ON att.EmployeeID = h.EmployeeID
	INNER JOIN #tblSalDetail sal ON att.EmployeeID = sal.EmployeeID AND sal.LatestSalEntry = 1

	-- Cập nhật UnpaidLeaveAmount trực tiếp từ số ngày nghỉ không hưởng lương vừa tính toán
	UPDATE sal
	SET sal.UnpaidLeaveAmount = ROUND(ISNULL(att.UnPaidLeaves, 0) * sal.SalaryPerDay, @ROUND_SALARY_UNIT)
	FROM #tblSalDetail sal
	INNER JOIN #tblSal_AttendanceData_PerHistory att ON sal.EmployeeID = att.EmployeeID and sal.SalaryHistoryID = att.SalaryHistoryID
END
ELSE
BEGIN
 UPDATE #tblSalDetail set UnpaidLeaveAmount = ROUND(tmp.AmountDeduct,@ROUND_SALARY_UNIT)
 from #tblSalDetail sal
 inner join tblSalaryCalculationRule sc on sal.SalCalRuleID = sc.SalCalRuleID
 --and sc.IsSTDMinusUnpaidLeave =1 -- nếu là STD trừ đi ngày nghỉ
 inner join (
 SELECT EmployeeID,SalaryHistoryID ,SUM(ISNULL(AmountDeduct,0)) AmountDeduct FROM #TableVarLeaveAmount
 GROUP BY EmployeeID,SalaryHistoryID)
 tmp on sal.EmployeeID = tmp.EmployeeID and sal.SalaryHistoryID = tmp.SalaryHistoryID
END

 ------------------------------Calculate Actual salary---------------------------------
 -- Luong thuc nhan cua thang

update #tblSalDetail  set DaysOfSalEntry = ISNULL(ca.AttDays,0)+ROUND(ISNULL(ca.PaidLeaves,0),0),
  STDPerSalaryHistoryId= case when CA.STD_PerHistoryID > sal.STD_WD then sal.STD_WD else ca.STD_PerHistoryID end
  ,LeaveCH2PH3=ca.LeaveCH2PH3
  ,AttDays=ca.AttDays
  ,UnpaidNotBH=ca.UnpaidNotBH
  ,WorkingDayoff = ca.WorkingDayoff
 from #tblSalDetail sal
 inner join #tblSal_AttendanceData_PerHistory ca on sal.EmployeeID = ca.EmployeeID and ca.SalaryHistoryID = ISNULL(sal.ProbationSalaryHistoryID, sal.SalaryHistoryID)

--tính lương ngày công ActualMonthlyBasic ,
--DaysOfSalEntry > 13 : Thực nhận =  BS – (BS /26 x số ngày nghỉ không hưởng lương)
--DaysOfSalEntry <= 13 : Thực nhận = BS /26 x số ngày làm việc (bao gồm nghỉ hưởng lương và nghỉ holiday)
update #tblSalDetail set LeaveCH2PH3=0 where isnull(DaysOfSalEntry,0) = 0 --có phát sinh công or nghỉ phép mới tính thêm nghỉ cty
IF @Month < 5
begin
	update #tblSalDetail set ActualMonthlyBasic = case when DaysOfSalEntry > (STD_WD / 2)
    then BasicSalary - isnull(UnpaidLeaveAmount,0) --- isnull(NotWorkSalary,0)
else SalaryPerDay * (isnull(DaysOfSalEntry,0)) end --+ isnull(LeaveCH2PH3,0)) end
end
else
begin
update #tblSalDetail set ActualMonthlyBasic = case when DaysOfSalEntry > (STD_WD / 2)
    then BasicSalary - isnull(UnpaidLeaveAmount,0) - isnull(NotWorkSalary,0)
else SalaryPerDay * (isnull(DaysOfSalEntry,0)) end --+ isnull(LeaveCH2PH3,0)) end
end
update #tblSalDetail set ActualMonthlyBasic = round(cast(ActualMonthlyBasic as decimal(15,4)),@ROUND_SALARY_UNIT)



--SELECT  ActualMonthlyBasic,STDPerSalaryHistoryId,LeaveCH2PH3,NotWorkSalary,UnpaidNotBH,WorkingDayoff,(STD_WD - DaysOfSalEntry)*iif(EmployeeTypeID = 0,9,8) as zzz,AttDays,DaysOfSalEntry,LeaveCH2PH3,*
--FROM #tblSalDetail
--ORDER BY
--    CASE
--        WHEN TRY_CAST(EmployeeID AS INT) IS NOT NULL THEN 0
--        ELSE 1
--    END,
--    TRY_CAST(EmployeeID AS INT),
--    EmployeeID
--return
if(OBJECT_ID('SALCAL_MONTHLYBASIC_FINISHED' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_MONTHLYBASIC_FINISHED
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_MONTHLYBASIC_FINISHED @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID
------- lấy thông tin của Allowance ở đây do cần thông tin này


CREATE table #tblAllowance
(
 EmployeeID varchar(20),AllowanceID int,AllowanceRuleID int
 ,AllowanceCode varchar(200),SalaryHistoryID bigint,SalCalRuleID int,
 FromDate datetime,
 ToDate datetime,
 DefaultAmount float(53),
 DefaultAmount_WithoutCustomAmount float(53),
 ReceiveAmount float(53),
 TaxableAmount float(53),
 UntaxableAmount float(53),
 TakeHome BIT,
 STD_WD float,
 TotalPaidDays float,
 AttDays float,
 CurrencyCode varchar(20)
 ,Raw_DefaultAmount float(53)
 ,Raw_CurrencyCode nvarchar(20)
 ,Raw_ExchangeRate float(53)
 ,IsMutilCurrencyCode bit
,RetroAmount money
 ,RetroAmountNonTax money
 ,TaxFreeMaxAmount money
 ,MonthlyCustomAmount money
 ,MonthlyCustomReceiveAmount money
 ,LatestSalEntry bit
 ,IsTaxable bit
 ,PositionID int
 ,RankID int
 ,LevelID int
 ,isNotAL bit
 ,NotYetWork int
 ,NotTermiWork int
 ,LeaveCH2PH3 int
 ,HireDate date
 ,TransportID int
 ,WorkingDayoff float
)
CREATE table #AllowanceCodeList (AllowanceCode varchar(20),AllowanceID int, DefaultAmount float(53),
AllowanceRuleID int, ForSalary bit, TaxfreeMaxAmount float(53),IsHouseAllowance bit,isUniformAllowance bit,
BasedOnSalaryScale bit,IsTaxable bit,IsMutilCurrencyCode bit)


insert into #AllowanceCodeList (AllowanceID,AllowanceCode,ForSalary,AllowanceRuleID,TaxfreeMaxAmount,IsHouseAllowance
 ,isUniformAllowance,DefaultAmount,BasedOnSalaryScale,IsTaxable,IsMutilCurrencyCode)

 select AllowanceID,AllowanceCode,ForSalary,AllowanceRuleID,TaxfreeMaxAmount,IsHouseAllowance
 ,isUniformAllowance,DefaultAmount,BasedOnSalaryScale,IsTaxable,IsMutilCurrencyCode
 from tblAllowanceSetting where AllowanceCode in (
 select c.COLUMN_NAME from INFORMATION_SCHEMA.COLUMNS c where c.TABLE_NAME = N'tblSalaryHistory' and c.DATA_TYPE = 'money'
 and c.COLUMN_NAME not in ('Salary','InsSalary','NETSalary')
 and Visible = 1
)
insert into #tblAllowance(EmployeeID,AllowanceID,AllowanceRuleID,AllowanceCode,SalaryHistoryID,FromDate,ToDate,DefaultAmount,TakeHome,SalCalRuleID,TotalPaidDays,AttDays,IsMutilCurrencyCode,TaxFreeMaxAmount
,LatestSalEntry,IsTaxable,STD_WD,PositionID,RankID,LevelID,isNotAL,NotYetWork,NotTermiWork,LeaveCH2PH3,HireDate,TransportID,WorkingDayoff)
select s.EmployeeID,a.AllowanceID,a.AllowanceRuleID,a.AllowanceCode,s.SalaryHistoryID,s.FromDate,s.ToDate,a.DefaultAmount,a.ForSalary,s.SalCalRuleID
,s.DaysOfSalEntry,s.AttDays
--,case when BasedOnSalaryScale = 1 then DaysOfSalEntry else s.DaysOfSalEntry end
,a.IsMutilCurrencyCode
,case when isnull(a.IsTaxable,0) =0 then 9999999999 else isnull(TaxFreeMaxAmount,0) end as TaxFreeMaxAmount
,s.LatestSalEntry,a.IsTaxable,s.STD_WD,s.PositionID,s.RankID,s.LevelID,s.isNotAL,s.NotYetWork,s.NotTermiWork,s.LeaveCH2PH3,s.HireDate,s.Kilometer,s.WorkingDayoff

from #AllowanceCodeList a
cross join #tblSalDetail s
--on S.LatestSalEntry = 1 or a.BasedOnSalaryScale =1
--left join #tblSal_AttendanceData sal on s.EmployeeID = sal.EmployeeID
set @Query = ''
select @Query += 'UPDATE #tblAllowance set DefaultAmount = sh.['+c.AllowanceCode+']
,CurrencyCode ='+case when isnull(c.IsMutilCurrencyCode,0)=1 then 'sh.['+c.AllowanceCode+'_CurrencyCode]' else 'sh.CurrencyCode' end+'
from #tblAllowance tmp
inner join tblSalaryHistory sh on tmp.SalaryHistoryID = sh.SalaryHistoryID and AllowanceID = '+ cast(c.AllowanceID as varchar) +'
'


from #AllowanceCodeList c
EXECUTE sp_executesql @Query

drop table #AllowanceCodeList

delete from #tblAllowance  where ISNULL(DefaultAmount,0) = 0 and LatestSalEntry = 0

--tringuyen:huong tron goi & chuyen can lay theo muc luong moi
delete from #tblAllowance  where AllowanceRuleID in(1,9) and LatestSalEntry = 0

-- kiểm tra coi có thằng nào bị miss exchange rate nữa hay ko
insert into tblProcessErrorMessage(ErrorType,ErrorDetail,LoginID)
select 'Exchange Rate not seted!','Exchange rate for "'+a.CurrencyCode+'" is not seted!, Please complete Function "Currency Setting" first!' ,@loginID-1000
 from #tblAllowance a
inner join #tblSalDetail sal on a.EmployeeID = sal.EmployeeID and sal.LatestSalEntry = 1
left join #EmployeeExchangeRate c on a.CurrencyCode = c.CurrencyCode and c.EmployeeID=a.EmployeeID
where isnull(a.CurrencyCode,'vnd') <> 'vnd' and c.[ExchangeRate] is null
if @@ROWCOUNT >0
begin
 -- nếu có lỗi thì
 return;
end

-- update tỷ giá cho thằng default Amount trước khi tính toán để cho đúng hơn

--,Raw_DefaultAmount float(53)
-- ,Raw_ReceiveAmount float(53)
-- ,Raw_ExchangeRate float(53)

update al set
DefaultAmount = al.DefaultAmount * isnull(c.[ExchangeRate],1)
,Raw_ExchangeRate = c.[ExchangeRate]
,Raw_DefaultAmount = al.DefaultAmount
,Raw_CurrencyCode = al.CurrencyCode
from #tblAllowance al
inner join #tblSalDetail sal on al.EmployeeID = sal.EmployeeID and sal.LatestSalEntry = 1
left join #EmployeeExchangeRate c on al.CurrencyCode = c.CurrencyCode and c.EmployeeID = al.EmployeeID


select * into #fn_ParameterAllowance_Range from dbo.fn_ParameterAllowance_Range() where @ToDateTruncate between EffectiveDate and EndDate

--Hiếu: các loại phụ cấp nè
 update a
 set
  DefaultAmount = case a.AllowanceCode
   when 'Support_AL' then b.Support_AL
   when 'Support2_AL' then b.Support2_AL
   when 'Pos_AL' then b.Pos_AL
   when 'Qualification_AL' then b.Qualification_AL
   when 'Skill_AL' then b.Skill_AL
   when 'Responsibility_AL' then b.Responsibility_AL
   when 'Language_AL' then b.Language_AL
   when 'Livingsupport1_AL' then b.Livingsupport1_AL
   when 'TCCD' then b.TCCD_AL
   when 'FORKLIFT' then b.FORKLIFT_AL
   when 'BMC' then b.BMC_AL
   when 'PCCC' then b.PCCC_AL
   when 'ATVSV' then b.ATVSV_AL
   when 'PerfectAtt' then b.PerfectAtt_AL
   when 'Breakfast' then b.Breakfast_AL
   when 'House_AL' then b.House_AL
   when 'Transport_AL' then b.Transport_AL
   when 'TCPN' then b.TCPN_AL
   when 'UnionAL' then b.Union_AL
   else a.DefaultAmount
  end,
  Raw_DefaultAmount = case a.AllowanceCode
   when 'Support_AL' then b.Support_AL
   when 'Support2_AL' then b.Support2_AL
   when 'Pos_AL' then b.Pos_AL
   when 'Qualification_AL' then b.Qualification_AL
   when 'Skill_AL' then b.Skill_AL
   when 'Responsibility_AL' then b.Responsibility_AL
   when 'Language_AL' then b.Language_AL
   when 'Livingsupport1_AL' then b.Livingsupport1_AL
   when 'TCCD' then b.TCCD_AL
   when 'FORKLIFT' then b.FORKLIFT_AL
   when 'BMC' then b.BMC_AL
   when 'PCCC' then b.PCCC_AL
   when 'ATVSV' then b.ATVSV_AL
   when 'PerfectAtt' then b.PerfectAtt_AL
   when 'Breakfast' then b.Breakfast_AL
   when 'House_AL' then b.House_AL
   when 'Transport_AL' then b.Transport_AL
   when 'TCPN' then b.TCPN_AL
   when 'UnionAL' then b.Union_AL
   else a.Raw_DefaultAmount
  end
 from #tblAllowance a
 inner join #tmpAllowanCustom b on b.EmployeeID = a.EmployeeID;

 -- Kết thúc thông tin của allowance, xóa các điều chỉnh tự động cũ
 delete p
 from tblPR_Adjustment p
 where exists(select 1 from #tblSalDetail s where s.EmployeeID = p.EmployeeID)
   and p.Month = @Month and p.Year = @Year and p.Remark = 'System automatic calculate';



--Hiếu: trừ đi trễ về sớm
insert into tblPR_Adjustment(EmployeeID,Month,Year,IncomeID,Amount,CurrencyCode,Remark)
select sa.EmployeeID, @Month, @Year,33  IncomeID,  sa.SalaryPerHour * isnull(att.DeductionHours,0), 'VND', 'System automatic calculate'
from #tblSalDetail sa
inner join #tblSal_AttendanceData_PerHistory att on att.EmployeeID=sa.EmployeeID
where isnull(att.DeductionHours,0) > 0 and not exists(select 1 from tblPR_Adjustment p
where p.EmployeeID=sa.EmployeeID and p.IncomeID=33 and p.Month=@Month and p.Year=@Year)

-- kết thúc thông tin của allowance

--exec sp_HR_ProcessTerminateData @LoginID = @LoginID, @FromDate = @FromDate, @ToDate = @ToDate
 -------------------------calculate Adjustment--------------------------------------
CREATE TABLE #tblAdjustment (
 EmployeeID varchar(20)
 ,SalaryHistoryID int
 ,BasicSalary float(53)

 ,IncomeID int
 ,ByAmount bit
 ,SalaryPercent float(10)

 ,AdjustmentAmount float(53)
 ,Raw_AdjustmentAmount float(53)
 ,EmpAdjustmentID bigint
 ,CurrencyCode varchar(20)

 ,ExchangeRate float(53)
)
-- xu ly nhung nhan vien co dc thanh toan tien phep chua su dung hang thang

--DELETE p FROM dbo.tblAnnualLeavePayment p WHERE EXISTS (SELECT 1 FROM #tblEmployeeIDList e WHERE p.EmployeeID = e.EmployeeID) AND p.Month = @Month AND p.Year = @Year AND ISNULL(p.Approved,0) = 0
--DELETE p FROM dbo.tblAnnualLeavePayment p WHERE EXISTS (SELECT 1 FROM tblALPaymentTracking t WHERE p.EmployeeID = t.EmployeeID AND p.Month = t.Month AND p.Year = t.Year AND ISNULL(t.ALPaidDays,0) = 0) AND p.Month = @Month AND p.Year = @Year AND ISNULL(p.Approved,0) = 0

--insert into tblAnnualLeavePayment(EmployeeID,EffectiveDate,SalaryHistoryID,Salary,ALDays,SalPerDay,Amount,ApprovedAmount,Approved,Year,Month)
--SELECT s.EmployeeID,@FromDate,s.SalaryHistoryID,s.BasicSalary,ap.ALPaidDays,s.SalaryPerDay,ap.ALPaidDays*s.SalaryPerDay,ap.ALPaidDays*s.SalaryPerDay ,0,@Year,@Month FROM tblALPaymentTracking ap INNER JOIN #tblSalDetail s ON ap.EmployeeID = s.EmployeeID AND s.LatestSalEntry = 1
--WHERE EXISTS (SELECT 1 FROM #tblEmployeeIDList e WHERE ap.EmployeeID = e.EmployeeID)
--AND ap.Month = @Month AND ap.Year = @Year AND ISNULL(ALPaidDays,0) <> 0
--AND NOT EXISTS (SELECT 1 FROM dbo.tblAnnualLeavePayment p WHERE ap.EmployeeID = p.EmployeeID AND p.Approved = 1 AND ap.Month = p.Month AND ap.year = p.Year)
---- dua vao bang tblPR_Adjustment
--UPDATE a SET a.Amount = p.ApprovedAmount FROM dbo.tblPR_Adjustment a INNER JOIN dbo.tblAnnualLeavePayment p ON a.EmployeeID = p.EmployeeID AND a.Month = p.Month AND a.Year = p.Year
--WHERE a.IncomeID = 5 AND a.Remark LIKE N'System automatic paid AL unused days%'
--AND a.Month = @Month AND a.Year = @Year AND ISNULL(a.SalaryTerm,0) = 0 AND ISNULL(a.Amount,0) <> ISNULL(p.ApprovedAmount,0)
--AND EXISTS (SELECT 1 FROM #tblEmployeeIDList e WHERE e.EmployeeID = a.EmployeeID)

--DELETE a FROM dbo.tblPR_Adjustment a
--WHERE a.IncomeID = 5 AND a.Remark LIKE N'System automatic paid AL unused days%'
--AND not EXISTS (SELECT 1 FROM tblAnnualLeavePayment p WHERE p.EmployeeID = a.EmployeeID AND p.Month = a.Month AND p.Year = a.Year AND a.IncomeID = 5 AND a.Remark LIKE N'System automatic paid AL unused days')
--AND a.Month = @Month AND a.Year = @Year AND ISNULL(a.SalaryTerm,0) = 0

--INSERT INTO dbo.tblPR_Adjustment(EmployeeID,Month,Year,IncomeID,ByAmount,Amount,Remark,SalaryTerm)
--SELECT p.EmployeeID,@Month,@Year, 5,1,p.ApprovedAmount,N'System automatic paid AL unused days',0 FROM  dbo.tblAnnualLeavePayment p
--WHERE EXISTS (SELECT 1 FROM #tblEmployeeIDList e WHERE p.EmployeeID = e.EmployeeID)
--AND p.Month = @Month AND p.Year = @Year
--AND NOT EXISTS (SELECT 1 FROM dbo.tblPR_Adjustment a WHERE a.EmployeeID = p.EmployeeID AND a.Month = p.Month AND p.Year = a.Year AND a.IncomeID = 5)

if(OBJECT_ID('SALCAL_ADJUSTMENT_INITIAL' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_ADJUSTMENT_INITIAL
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
 ,@CalculateRetro int =0
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_ADJUSTMENT_INITIAL @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID,@CalculateRetro

-------------------Employees who have Adjustment--------------------------------
INSERT INTO #tblAdjustment(EmployeeID,IncomeID,ByAmount,SalaryPercent,AdjustmentAmount,EmpAdjustmentID,CurrencyCode,ExchangeRate)




(SELECT p.EmployeeID,p.IncomeID,ByAmount,SalaryPercent,p.Amount * isnull(c.[ExchangeRate],1) as Amount
,EmpAdjustmentID,p.CurrencyCode
,ISNULL(c.[ExchangeRate],1) as ExchangeRate
FROM tblPR_Adjustment p
inner join tblIrregularIncome ir on p.InComeID = ir.IncomeID and isnull(ir.AppendToPIT,0)=0
inner join #tblSalDetail sal on p.EmployeeID = sal.EmployeeID and sal.LatestSalEntry = 1
left join #EmployeeExchangeRate c on p.EmployeeID = c.EmployeeID and p.CurrencyCode = c.CurrencyCode
WHERE p.EmployeeID IN (SELECT EmployeeID FROM #tblEmployeeIDList)
AND [Month] = @Month AND [Year] = @Year
)
update #tblAdjustment set CurrencyCode = 'VND' where ISNULL(CurrencyCode,'-1') = '-1'
insert into tblProcessErrorMessage(ErrorType,ErrorDetail,LoginID)
select 'Exchange Rate not seted!','Exchange rate for "'+a.CurrencyCode+'" is not seted!, Please complete Function "Currency Setting" first!' ,@loginID-1000
 from #tblAdjustment a
inner join #tblSalDetail sal on a.EmployeeID = sal.EmployeeID and sal.LatestSalEntry = 1
left join #EmployeeExchangeRate c on a.CurrencyCode = c.CurrencyCode and c.EmployeeID = a.EmployeeID
where isnull(a.CurrencyCode,'vnd') <> 'vnd' and c.[ExchangeRate] is null
if @@ROWCOUNT >0
begin
 -- nếu có lỗi thì
 return;
end

------------Determine whether Adjustment is calculated base on Salary percent or not----------
UPDATE #tblAdjustment
SET ByAmount = 1-- ISNULL(ByAmount,1)
,SalaryPercent =0-- ISNULL(SalaryPercent,0)

UPDATE #tblAdjustment
SET BasicSalary = sd.BasicSalary
FROM #tblAdjustment adj, #tblSalDetail sd
WHERE adj.EmployeeID = sd.EmployeeID
AND adj.ByAmount = 0 --tinh theo salary percent
and sd.LatestSalEntry= 1


-------------------Calculate if Adjustment is based on Salary percent---------------
--UPDATE #tblAdjustment
--SET AdjustmentAmount = BasicSalary * SalaryPercent/100.0
--WHERE ByAmount = 0

UPDATE #tblAdjustment
SET AdjustmentAmount = ISNULL(AdjustmentAmount,0)

select EmployeeID,als.AllowanceID,ad.IncomeID,AdjustmentAmount,EmpAdjustmentID
,ir.TaxBaseOnAllowanceCode,ad.Raw_AdjustmentAmount,ad.CurrencyCode as Raw_CurrencyCode
,ad.ExchangeRate as Raw_ExchangeRate
into #tblAdjustmentForAllowance
from #tblAdjustment ad
inner join tblIrregularIncome ir on ad.IncomeID = ir.IncomeID and len(ir.TaxBaseOnAllowanceCode) >0 and ForAllowance=1
inner join tblAllowanceSetting als on ir.TaxBaseOnAllowanceCode = als.AllowanceCode

insert into #tblSal_Adjustment_ForAllowance_Des(EmployeeID,Month,Year,PeriodID,AllowanceID,IncomeID,AdjustmentAmount,Raw_AdjustmentAmount,Raw_CurrencyCode,Raw_ExchangeRate)
select EmployeeID,@Month,@Year,@PeriodID,AllowanceID,IncomeID
,AdjustmentAmount,Raw_AdjustmentAmount
,Raw_CurrencyCode,Raw_ExchangeRate from #tblAdjustmentForAllowance


delete #tblAdjustment  from #tblAdjustment  a
inner join #tblAdjustmentForAllowance aa on a.EmployeeId = aa.EmployeeId and a.IncomeID = aa.IncomeID

-----------------Insert into the table #tblSal_Adjustment_des-------------------

SELECT EmployeeID,IncomeID,SUM(AdjustmentAmount) AdjustmentAmount,sum(Raw_AdjustmentAmount) as Raw_AdjustmentAmount, CAST(0 as float(53)) TaxableAmount, CAST(0 as float(53)) UntaxableAmount
into #AdjustmentSum
FROM #tblAdjustment
GROUP BY EmployeeID, IncomeID

UPDATE a set UntaxableAmount = ISNULL(i.TaxfreeMaxAmount,0)
from #AdjustmentSum a
inner join tblIrregularIncome i on a.IncomeID = i.IncomeID and i.Taxable = 1

UPDATE a set UntaxableAmount = isnull(UntaxableAmount,0) + AdjustmentAmount
from #AdjustmentSum a
inner join tblIrregularIncome i on a.IncomeID = i.IncomeID and isnull(i.Taxable,0) = 0

UPDATE #AdjustmentSum
set UntaxableAmount = AdjustmentAmount
 where UntaxableAmount > AdjustmentAmount and AdjustmentAmount >0

UPDATE #AdjustmentSum set TaxableAmount = AdjustmentAmount - UntaxableAmount

UPDATE #AdjustmentSum
SET
Raw_AdjustmentAmount=AdjustmentAmount
,AdjustmentAmount = ROUND(AdjustmentAmount,@ROUND_SALARY_UNIT)
, UntaxableAmount = ROUND(UntaxableAmount,@ROUND_SALARY_UNIT)
, TaxableAmount = ROUND(TaxableAmount,@ROUND_SALARY_UNIT)

if(OBJECT_ID('SALCAL_ADJUSTMENT_BEFORE_INSERT' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_ADJUSTMENT_BEFORE_INSERT
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_ADJUSTMENT_BEFORE_INSERT @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID



 ------------------------------Calculate OT------------------------------------

 -- giống như thằng Leave thì đoạn này cũng cần phải

 --Hiếu: tính tăng ca
select o.OTKind,o.EmployeeID, @Month Month, @Year Year, s.SalaryHistoryID,os.OvValue as OTRate,SUM(o.ApprovedHours) as OTHour, CAST(0 as float(53)) OTAmount
,s.SalaryPerDayOT, s.SalaryPerHourOT,s.STD_WD, s.LatestSalEntry,MAX(os.NSPercents) as NSPercents,CAST(0 as  money ) as NightShiftAmount
into #tblSal_OT_Detail
from #tblOTList o
inner join #tblSalDetail s on o.EmployeeID = s.EmployeeID and o.OTDate between s.FromDate and s.ToDate
inner join tblOvertimeSetting os on o.OTKind = os.OTKind
group by o.OTKind,o.EmployeeID,s.SalaryHistoryID,os.OvValue,s.SalaryPerDayOT, s.SalaryPerHourOT,s.SalaryPerHour,s.STD_WD,s.LatestSalEntry



if(OBJECT_ID('SALCAL_OT_INITIAL' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_OT_INITIAL
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,

 @FromDatedatetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,

 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_OT_INITIAL @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

if @StopUPDATE = 0
begin
-- add thêm phần night shift
 UPDATE #tblSal_OT_Detail set
  OTAmount = o.OTRate*o.OTHour*o.SalaryPerHourOT/100.0
  ,NightShiftAmount =  o.NSPercents*o.OTHour*o.SalaryPerHourOT/100.0
   from #tblSal_OT_Detail o
end
UPDATE #tblSalDetail
set TaxableOTTotal = round(tmp.TaxableOTAmount,@ROUND_SALARY_UNIT)
,NoneTaxableOTTotal = round(tmp.NoneTaxableOTAmount,@ROUND_OT_NS_Detail_UNIT)
,TotalOTAmount = tmp.TotalOTAmount
,NightShiftAmount = tmp.NightShiftAmount
from #tblSalDetail s
inner join (
 select
  EmployeeID,SalaryHistoryID,LatestSalEntry
 ,SUM(OTAmount/OTRate*100.0) TaxableOTAmount
 ,SUM(OTAmount - round((OTAmount/OTRate*100.0),@ROUND_SALARY_UNIT)) NoneTaxableOTAmount -- làm vầy cộng lại mới tròn
 ,ROUND(SUM(OTAmount),@ROUND_OT_NS_Detail_UNIT) TotalOTAmount
 ,ROUND(SUM(NightShiftAmount),@ROUND_OT_NS_Detail_UNIT) NightShiftAmount
 from #tblSal_OT_Detail
 group by EmployeeID,SalaryHistoryID,LatestSalEntry
) tmp on s.EmployeeID = tmp.EmployeeID and s.SalaryHistoryID = tmp.SalaryHistoryID and s.LatestSalEntry = tmp.LatestSalEntry


update #tblSalDetail
set TotalOTAmount = ISNULL(TotalOTAmount,0) + ISNULL(re.OT_Retro_Amount,0)
,TaxableOTTotal = ISNULL(TaxableOTTotal,0) + ISNULL(re.Taxed_OT_REtro,0)
,NoneTaxableOTTotal = ISNULL(NoneTaxableOTTotal,0) + ISNULL(re.Nontax_OT_Retro_Amount,0)
from #tblSalDetail   sal
inner join
(
select EmployeeID,OT_Retro_Amount,Nontax_OT_Retro_Amount,ISNULL(OT_Retro_Amount,0) - ISNULL(Nontax_OT_Retro_Amount,0) as Taxed_OT_REtro
 from #tblsal_retro_Final
 ) re on sal.EmployeeID= re.EmployeeID
 where sal.LatestSalEntry = 1


insert into #tblSal_OT_Detail_des(OverTimeID,EmployeeID,Year,Month,SalaryHistoryID,OTHour,OTAmount, OTRate,SalaryPerDay,SalaryPerHour,LatestSalEntry,PeriodID,NightShiftAmount
,TaxableOTAmount,NoneTaxableOTAmount)
select OTKind,EmployeeID,Year,Month,SalaryHistoryID,OTHour,ROUND(OTAmount,@ROUND_OT_NS_Detail_UNIT) OTAmount, OTRate,SalaryPerDayOT,SalaryPerHourOT,LatestSalEntry
,@PeriodID ,NightShiftAmount
,OTAmount/OTRate*100.0 as TaxableOTAmount
,OTAmount - round((OTAmount/OTRate*100.0),@ROUND_SALARY_UNIT) as NoneTaxableOTAmount
from #tblSal_OT_Detail


if(OBJECT_ID('SALCAL_OT_FINISHED' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_OT_FINISHED
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_OT_FINISHED @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID
update #tblSalDetail set
TotalOTAmount = ROUND(TotalOTAmount,@ROUND_OT_NS_Detail_UNIT)
,TaxableOTTotal = ROUND(TaxableOTTotal,@ROUND_OT_NS_Detail_UNIT)
,NoneTaxableOTTotal = ROUND(NoneTaxableOTTotal,@ROUND_OT_NS_Detail_UNIT)
,NightShiftAmount =  ROUND(NightShiftAmount,@ROUND_OT_NS_Detail_UNIT)

-- OT summary--
insert into #tblSal_OT_des(EmployeeID,Month,Year,OTAmount,TaxableOTAmount,NoneTaxableOTAmount,PeriodID,NightShiftAmount)
select EmployeeID,@Month,@Year,round(SUM(TotalOTAmount),@ROUND_OT_NS_Detail_UNIT),round(SUM(TaxableOTTotal),@ROUND_OT_NS_Detail_UNIT),round(SUM(NoneTaxableOTTotal),@ROUND_OT_NS_Detail_UNIT)
,@PeriodID,sum(NightShiftAmount) as NightShiftAmount
from #tblSalDetail s
where s.TaxableOTTotal+s.NoneTaxableOTTotal >0
GROUP by EmployeeID


-------------------------calculate Nightshift adjustment--------------------------------------
DECLARE @PERCENT float
select @PERCENT = CAST([Value] AS FLOAT) from tblParameter where Code = 'NIGHT_SHIFT_PERCENT'
SET @PERCENT = ISNULL(@PERCENT,30)
CREATE TABLE #tblNightShiftList (
	NSKind int,
	EmployeeID varchar(20),
	HourApprove float,
	[Date] datetime
)


IF @Month < 5 AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ImportPayrollCheck')
	BEGIN
		DECLARE @NSKind_Official int, @NSKind_Unofficial int
		SELECT TOP 1 @NSKind_Official = NSKind FROM tblNightShiftSetting WHERE NSValue = 35
		SELECT TOP 1 @NSKind_Unofficial = NSKind FROM tblNightShiftSetting WHERE NSValue = 30
		SET @NSKind_Official = ISNULL(@NSKind_Official, 1)
		SET @NSKind_Unofficial = ISNULL(@NSKind_Unofficial, 2)

		INSERT INTO #tblNightShiftList(NSKind, EmployeeID, HourApprove, [Date])
		SELECT 
			CASE WHEN e.WorkTypeID = 1 THEN @NSKind_Official ELSE @NSKind_Unofficial END AS NSKind,
			e.EmployeeID,
			ISNULL(TRY_CAST(ipc.NS_Hour AS FLOAT), 0) AS HourApprove,
			@ToDateTruncate AS [Date]
		FROM #tblEmployeeIDList e
		INNER JOIN ImportPayrollCheck ipc ON e.EmployeeID = CAST(ipc.Emp_ID AS VARCHAR(20))
		WHERE ISNULL(TRY_CAST(ipc.NS_Hour AS FLOAT), 0) > 0
     
	END
	ELSE
	BEGIN
		INSERT INTO #tblNightShiftList(NSKind, EmployeeID, HourApprove, [Date])
		select NSKind,EmployeeID,HourApprove,[Date]
		 from tblNightShiftList
		where Approval = 1 and Date between @FromDate and @ToDate  and
		 EmployeeID in(select te.EmployeeId from #tblEmployeeIDList te
		   except
		   select c.EmployeeId from #tblCustomAttendanceData c
		   )

		delete #tblNightShiftList where EmployeeID in(select  c.EmployeeId from #tblCustomAttendanceData c)

		insert into #tblNightShiftList(NSKind,EmployeeID,HourApprove,[Date])
		select 1 as NSKind,EmployeeID, NS_Hour_1 as  HourApprove,@ToDateTruncate as Date
		from #tblCustomAttendanceData where  NS_Hour_1 <>0
		union
		select 2 as NSKind,EmployeeID, NS_Hour_2 as  HourApprove,@ToDateTruncate as Date
		from #tblCustomAttendanceData where  NS_Hour_2 <>0
		union
		select 3 as NSKind,EmployeeID, NS_Hour_3 as  HourApprove,@ToDateTruncate as Date
		from #tblCustomAttendanceData where  NS_Hour_3 <>0
		union
		select 4 as NSKind,EmployeeID, NS_Hour_4 as  HourApprove,@ToDateTruncate as Date
		from #tblCustomAttendanceData where  NS_Hour_4 <>0
	END




select o.NSKind,o.EmployeeID, @Month Month, @Year Year, s.SalaryHistoryID,os.NSValue as OTRate, SUM(o.HourApprove) as OTHour, CAST(0 as float(53)) NSAmount
,s.SalaryPerDayOT,s.SalaryPerHourOT, s.LatestSalEntry
into #tblSal_NS_Detail
from #tblNightShiftList o
inner join #tblSalDetail s on o.EmployeeID = s.EmployeeID and o.[Date] between s.FromDate and s.ToDate
inner join tblNightShiftSetting os on o.NSKind = os.NSKind
group by o.NSKind,o.EmployeeID,s.SalaryHistoryID,os.NSValue,s.SalaryPerDayOT,s.SalaryPerHourOT,s.LatestSalEntry


UPDATE #tblSal_NS_Detail SET OTRate = @PERCENT where OTRate is null

if(OBJECT_ID('SALCAL_NS_INITIAL' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_NS_INITIAL
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_NS_INITIAL @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

if @StopUPDATE = 0
begin

 UPDATE #tblSal_NS_Detail set NSAmount = ROUND(o.OTRate*o.OTHour*o.SalaryPerHourOT/100.0,@ROUND_OT_NS_Detail_UNIT) from #tblSal_NS_Detail o
end



update #tblSal_NS_Detail set NSAmount = ROUND(NSAmount,@ROUND_OT_NS_Detail_UNIT)

insert into #tblSal_NS_Detail_des(EmployeeID,Month,Year,SalaryHistoryID,NSKind,NSHours,NSAmount,LatestSalEntry,PeriodID)
select EmployeeID,Month,Year,SalaryHistoryID,NSKind,SUM(OTHour) OTHour,SUM(NSAmount) NSAmount,LatestSalEntry
,@PeriodID
from #tblSal_NS_Detail group by EmployeeID,Month,Year,SalaryHistoryID, LatestSalEntry,NSKind

UPDATE #tblSalDetail set TotalNSAmt = round(tmp.TotalNSAmt,@ROUND_OT_NS_Detail_UNIT), NoneTaxableNSAmt = round(tmp.NoneTaxableNSAmt,@ROUND_OT_NS_Detail_UNIT)
from #tblSalDetail s
inner join (
 select EmployeeID, SalaryHistoryID, LatestSalEntry,SUM(NSAmount) TotalNSAmt,SUM(NSAmount) NoneTaxableNSAmt
 from #tblSal_NS_Detail group by EmployeeID,SalaryHistoryID,LatestSalEntry
) tmp on s.EmployeeID = tmp.EmployeeID and s.SalaryHistoryID = tmp.SalaryHistoryID and s.LatestSalEntry = tmp.LatestSalEntry


-- update retro amount of night shift (normal days only)
update #tblSalDetail set TotalNSAmt = ISNULL(TotalNSAmt,0) + ISNULL(re.NightShift_RETRO,0)
from #tblSalDetail sal
inner join #tblsal_retro_Final re
on sal.EmployeeID = re.EmployeeID
where sal.LatestSalEntry = 1


if(OBJECT_ID('SALCAL_NS_FINISHED' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_NS_FINISHED
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_NS_FINISHED @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

update #tblSal_NS_Detail set NSAmount = ROUND(NSAmount,@ROUND_OT_NS_Detail_UNIT)


-- NS summary--
insert into #tblSal_NS_des(EmployeeID,Month,Year,NSHours,NSAmount,PeriodID)
select EmployeeID,Month,Year,SUM(OTHour) NSHours, ROUND(SUM(NSAmount),@ROUND_OT_NS_Detail_UNIT) NSAmount,@PeriodID
from #tblSal_NS_Detail s group by EmployeeID,Month,Year

-----------------------Calculate Allowance---------------------------

  -- Hiếu: Đồng bộ các ngày công pro-rata trong #tblAllowance của dòng mới nhất bằng tổng công cả tháng
  IF @Month < 5 AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ImportPayrollCheck')
  BEGIN
      -- Các tháng cũ < 5: Lấy thẳng số ngày công tính lương (Workdays) từ file Import làm ngày công cả tháng
      update a
      set a.TotalPaidDays = isnull(ipc.Workdays, 0),
          a.AttDays = isnull(ipc.Workdays, 0),
          a.WorkingDayoff = 0
      from #tblAllowance a
      inner join (
          select cast(Emp_ID as varchar(20)) as Emp_ID, try_cast(Workdays as float) as Workdays
          from ImportPayrollCheck
          where Emp_ID is not null and Emp_ID <> ''
      ) ipc on a.EmployeeID = ipc.Emp_ID
      where a.LatestSalEntry = 1
  END
  ELSE
  BEGIN
      -- Các tháng thực tế >= 5: Lấy tổng công cả tháng từ hệ thống (bao gồm đi làm thực tế + phép + lễ)
      update a
      set a.TotalPaidDays = isnull(tot.AttDays, 0) + isnull(tot.PaidLeaves, 0) + isnull(tot.LeaveCH2PH3, 0),
          a.AttDays = isnull(tot.AttDays, 0) + isnull(tot.LeaveCH2PH3, 0),
          a.WorkingDayoff = isnull(tot.WorkingDayoff, 0)
      from #tblAllowance a
      inner join #tblSal_AttendanceData tot on a.EmployeeID = tot.EmployeeID
      where a.LatestSalEntry = 1
  END

 -- 1. Trợ cấp Nhà ở (Chỉ dành cho TransportID = 2)
 -- Rule: Tính theo TotalPaidDays (bao gồm cả phép, lễ...) chia cho 26
 update a
 set ReceiveAmount = case
   when isnull(a.NotYetWork, 0) > 0 or isnull(a.NotTermiWork, 0) > 0 or isnull(s.IsProbation, 0) = 1
    then (isnull(a.DefaultAmount, 0) / 26.0) * isnull(a.TotalPaidDays, 0)
   else a.DefaultAmount
  end
 from #tblAllowance a
 inner join #tblSalDetail s on s.EmployeeID = a.EmployeeID and s.SalaryHistoryID = a.SalaryHistoryID
 where a.AllowanceCode = 'House_AL'
   and a.TransportID = 2

    update a
 set ReceiveAmount = case
   when isnull(a.NotYetWork, 0) > 0 or isnull(a.NotTermiWork, 0) > 0 or isnull(s.IsProbation, 0) = 1
    then (isnull(a.DefaultAmount, 0) / 26.0) * isnull(a.AttDays, 0)
   else a.DefaultAmount
  end
 from #tblAllowance a
 inner join #tblSalDetail s on s.EmployeeID = a.EmployeeID and s.SalaryHistoryID = a.SalaryHistoryID
 where a.AllowanceCode = 'Breakfast'
 
     update a
 set ReceiveAmount = case
   when isnull(a.NotYetWork, 0) > 0 or isnull(a.NotTermiWork, 0) > 0 or isnull(s.IsProbation, 0) = 1
    then (isnull(a.DefaultAmount, 0) / s.STD_WD) * isnull(a.AttDays, 0)
   else a.DefaultAmount
  end
 from #tblAllowance a
 inner join #tblSalDetail s on s.EmployeeID = a.EmployeeID and s.SalaryHistoryID = a.SalaryHistoryID
 where a.AllowanceCode = 'PCCC'

 -- 2. Trợ cấp đi lại (Dành cho TransportID > 2: các mức 3, 6, 9, 12, 15)
 -- Rule: Tính theo AttDays (ngày đi làm thực tế) chia cho 22
 update a set
  ReceiveAmount = (isnull(a.DefaultAmount,0) / 22.0) * (isnull(a.AttDays, 0) + isnull(a.WorkingDayoff,0))
 from #tblAllowance a
 where a.AllowanceCode = 'Transport_AL' and a.TransportID > 2

 -- Dưới tháng 5 và có bảng ImportPayrollCheck: lấy trực tiếp tiền từ file Import để đồng bộ
 IF @Month < 5 AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ImportPayrollCheck')
 BEGIN
  ;WITH CleanedImport AS (
   SELECT 
    CAST(ipc.Emp_ID AS VARCHAR(20)) AS Emp_ID,
    TRY_CAST(ipc.Transport AS FLOAT) AS TransportAmt,
    ROW_NUMBER() OVER (PARTITION BY ipc.Emp_ID ORDER BY TRY_CAST(ipc.RowIndex AS INT) DESC) as rn
   FROM ImportPayrollCheck ipc
   WHERE ipc.Emp_ID IS NOT NULL AND ipc.Emp_ID <> ''
  )
  UPDATE a
  SET ReceiveAmount = ISNULL(ipc.TransportAmt, 0)
  FROM #tblAllowance a
  INNER JOIN CleanedImport ipc ON a.EmployeeID = ipc.Emp_ID AND ipc.rn = 1
  WHERE (a.AllowanceCode = 'House_AL' AND a.TransportID = 2)
     OR (a.AllowanceCode = 'Transport_AL' AND a.TransportID > 2)
 END
 -- 3. Trợ cấp chuyên cần (PerfectAtt)
 -- Rule:
 -- - Vi phạm (Trễ > 30p, nghỉ không phép, nghỉ việc trong tháng): 0đ
 -- - Vi phạm nhẹ (Trễ <= 30p): Trừ 80,000đ
 -- - Không vi phạm: Hưởng full

 IF OBJECT_ID('tempdb..#KipSundayWork') IS NOT NULL DROP TABLE #KipSundayWork
 SELECT EmployeeID, COUNT(1) AS SundayKipCount
 INTO #KipSundayWork
 FROM #TAData
 WHERE EmployeeTypeID = 2
   --AND HolidayStatus = 0
   AND ((DATEPART(dw, AttDate) + @@DATEFIRST - 1) % 7 = 0)
   AND AttDays = 1
 GROUP BY EmployeeID

 update a set
  ReceiveAmount = case
   when isnull(s.LeaveCC,0) > 0 or isnull(s.DeductionHours,0) > 0.5 or isnull(a.NotTermiWork,0) > 0 then 0
   when isnull(s.DeductionHours,0) > 0 and isnull(s.DeductionHours,0) <= 0.5 then
    case when isnull(a.DefaultAmount,0) > 80000 then isnull(a.DefaultAmount,0) - 80000 else 0 end
   else 
    case 
     when sd.IsProbation = 0 and e.EmployeeTypeID = 2 and isnull(kw.SundayKipCount, 0) >= 3 
      then 500000
     else isnull(a.DefaultAmount,0)
    end
  end
 from #tblAllowance a
 inner join #tblSal_AttendanceData_PerHistory s on s.EmployeeID = a.EmployeeID
 inner join #tblSalDetail sd on sd.EmployeeID = a.EmployeeID and sd.SalaryHistoryID = a.SalaryHistoryID
 inner join #tblEmployeeIDList e on e.EmployeeID = a.EmployeeID
 left join #KipSundayWork kw on kw.EmployeeID = a.EmployeeID
 where a.AllowanceCode = 'PerfectAtt' and a.HireDate < @FromDate

 
  IF @Month < 5 AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ImportPayrollCheck')
  BEGIN
   ;WITH CleanedImport AS (
    SELECT 
     CAST(ipc.Emp_ID AS VARCHAR(20)) AS Emp_ID,
     TRY_CAST(ipc.Perfect_Att AS FLOAT) AS PerfectAttAmt,
     ROW_NUMBER() OVER (PARTITION BY ipc.Emp_ID ORDER BY TRY_CAST(ipc.RowIndex AS INT) DESC) as rn
    FROM ImportPayrollCheck ipc
    WHERE ipc.Emp_ID IS NOT NULL AND ipc.Emp_ID <> ''
   )
   UPDATE a
   SET ReceiveAmount = ISNULL(ipc.PerfectAttAmt, 0)
   FROM #tblAllowance a
   INNER JOIN CleanedImport ipc ON a.EmployeeID = ipc.Emp_ID AND ipc.rn = 1
   WHERE a.AllowanceCode = 'PerfectAtt'
  END



 IF OBJECT_ID('tempdb..#KipSundayWork') IS NOT NULL DROP TABLE #KipSundayWork
 --Tham nien

  update a set ReceiveAmount = case
		when isnull(a.NotYetWork, 0) > 0 or isnull(a.NotTermiWork, 0) > 0
			then (isnull(a.DefaultAmount, 0) / sd.STD_WD) * isnull(a.AttDays, 0)
		else isnull(a.DefaultAmount, 0)
	end
 from #tblAllowance a
 inner join #tblSalDetail sd on sd.EmployeeID = a.EmployeeID and sd.SalaryHistoryID = a.SalaryHistoryID
 where a.AllowanceCode ='Livingsupport1_AL'



 -- 4. Các loại trợ cấp core (Chức vụ, Chuyên môn, Trách nhiệm, Ngoại ngữ)
 -- Rule:
 -- - Nếu là nhân viên mới vào làm hoặc nghỉ việc trong tháng: hưởng theo số ngày tính lương (DaysOfSalEntry) chia cho 26.
 -- - Nếu là nhân viên cũ: Đi làm thực tế (AttDays) > 7 ngày hưởng full, <= 7 ngày tính theo tỷ lệ công thực tế.
 update a set
  ReceiveAmount = case
   when isnull(a.NotYetWork, 0) > 0 or isnull(a.NotTermiWork, 0) > 0
    then (isnull(a.DefaultAmount, 0) / a.STD_WD) * isnull(a.TotalPaidDays, 0)
   when isnull(a.AttDays,0) > 7 then a.DefaultAmount
   else (isnull(a.DefaultAmount,0) / a.STD_WD) * isnull(a.AttDays,0)
  end
 from #tblAllowance a
 inner join #tblSalDetail sd on sd.EmployeeID = a.EmployeeID and sd.SalaryHistoryID = a.SalaryHistoryID
 where a.AllowanceCode in ('Qualification_AL', 'Pos_AL', 'Responsibility_AL', 'Language_AL', 'Skill_AL')

 -- 5. Các loại trợ cấp còn lại (Kỹ năng, Sinh hoạt...)
 -- Rule: Đi làm thực tế (AttDays) > 7 ngày hưởng full, <= 7 ngày tính theo tỷ lệ công thực tế
 update a set
  ReceiveAmount = case
   when isnull(a.NotYetWork, 0) > 0 or isnull(a.NotTermiWork, 0) > 0
    then (isnull(a.DefaultAmount, 0) / a.STD_WD) * isnull(a.TotalPaidDays, 0)
   when isnull(a.AttDays,0) > 7 then a.DefaultAmount
   else (isnull(a.DefaultAmount,0) / a.STD_WD) * isnull(a.AttDays,0)
  end
 from #tblAllowance a
 where a.AllowanceCode not in ('House_AL', 'Transport_AL', 'PerfectAtt','Livingsupport1_AL','Breakfast')
   and a.AllowanceCode not in ('Qualification_AL', 'Pos_AL', 'Responsibility_AL', 'Language_AL', 'Skill_AL')


 -- Kết thúc thông tin của allowance, xóa các điều chỉnh tự động cũ
update #tblAllowance set
DefaultAmount_WithoutCustomAmount = DefaultAmount

select distinct MonthlyCustomAmountColumnName,AllowanceID  into #CustomColname
from tblAllowanceSetting
where MonthlyCustomAmountColumnName is not null
 and MonthlyCustomAmountColumnName in(select Column_Name from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME= 'tblCustomInputImportMonthly')
 
 select * into #tblCustomInputImportMonthly from tblCustomInputImportMonthly
 where Month = @Month and YEar =  @Year and ISNULL(IsRetro,0) = isnull(@CalculateRetro,0)
 set @Query = ''
 declare @customcOlName nvarchar(100) = ''
 declare @AllowanceID nvarchar(10) = ''
 while exists(select 1 from #CustomColname)
 begin
  select top 1 @customcOlName = MonthlyCustomAmountColumnName
  ,@AllowanceID = AllowanceID
  from #CustomColname
  set @Query = 'update #tblAllowance
  set MonthlyCustomAmount = isnull(c.['+@customcOlName+'] ,0)
  ,DefaultAmount =isnull(DefaultAmount,0) +isnull(c.['+@customcOlName+'],0)
  from #tblAllowance al
  inner join #tblCustomInputImportMonthly c on al.EmployeeId = c.EmployeeID
  where al.AllowanceID  ='+@AllowanceID+' and c.['+@customcOlName+'] <>0
  and al.LatestSalEntry = 1'
  exec(@Query)
  delete #CustomColname where MonthlyCustomAmountColumnName = @customcOlName
 end
 drop table #tblCustomInputImportMonthly
 drop table #CustomColname

update #tblAllowance  set  MonthlyCustomAmount = isnull(MonthlyCustomAmount,0) + isnull(a.AdjustmentAmount,0)
  ,DefaultAmount =isnull(DefaultAmount,0) + isnull(a.AdjustmentAmount,0)
from #tblAllowance  al
inner join (select  EmployeeID,TaxBaseOnAllowanceCode ,Sum(AdjustmentAmount) as AdjustmentAmount
from #tblAdjustmentForAllowance a group by EmployeeID,TaxBaseOnAllowanceCode) a
on al.EmployeeID = a.EmployeeId and al.AllowanceCode= a.TaxBaseOnAllowanceCode
where al.LatestSalEntry = 1



if(OBJECT_ID('SALCAL_ALLOWANCE_BEFORE_PROCESS' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_ALLOWANCE_BEFORE_PROCESS
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_ALLOWANCE_BEFORE_PROCESS @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

-- thâm niên
select EmployeeID
,Hiredate BeginDate
,@ToDate EndDate
,1 FirstMonthAddition --mac dinh tinh luon thang vao lam
,1 LastMonthAddition --tinh ca thang ket thuc
,TerminateDate
,0 as Months
into #tmpSeniority
from #tblEmployeeIDList e where Hiredate < @ToDate

--nhan vien nghi viec thi chi tinh den thang nghi viec thoi
UPDATE #tmpSeniority SET EndDate = TerminateDate where TerminateDate is not null

if(OBJECT_ID('SALCAL_ALLOWANCE_SENIORIRY_INITIAL' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_ALLOWANCE_SENIORIRY_INITIAL
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_ALLOWANCE_SENIORIRY_INITIAL @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

if @StopUPDATE = 0
begin
 DECLARE @SENIORITY_FOR_FIRST_MONTH int, @SENIORITY_FOR_LAST_MONTH int
 select @SENIORITY_FOR_FIRST_MONTH = [Value] from tblParameter where Code = 'SENIORITY_FOR_FIRST_MONTH'
 SET @SENIORITY_FOR_FIRST_MONTH = ISNULL(@SENIORITY_FOR_FIRST_MONTH,0)

 select @SENIORITY_FOR_LAST_MONTH = [Value] from tblParameter where Code = 'SENIORITY_FOR_LAST_MONTH'
 SET @SENIORITY_FOR_LAST_MONTH = ISNULL(@SENIORITY_FOR_LAST_MONTH,31)

 if @SENIORITY_FOR_FIRST_MONTH > 0 --VD: neu vao lam sau ngay 15 thi khong duoc tham nien thang dau
  UPDATE #tmpSeniority SET FirstMonthAddition = 0 where day(BeginDate) > @SENIORITY_FOR_FIRST_MONTH

 if @SENIORITY_FOR_LAST_MONTH <= 0 --nhap 0 thi tinh den cuoi thang truoc
  UPDATE #tmpSeniority SET LastMonthAddition = 0 where TerminateDate is not null
 else if @SENIORITY_FOR_LAST_MONTH < 31 --nhap ngay trong thang, gia su nhap 15 thi nghi viec truoc ngay 15 thi khong duoc, tu ngay 16 tro di thi duoc
  UPDATE #tmpSeniority SET LastMonthAddition = 0 where day(TerminateDate) < @SENIORITY_FOR_LAST_MONTH
 else if @SENIORITY_FOR_LAST_MONTH >= 31 --nhap 31 thi nghi viec ngay 1 thi khong duoc, vi LastWorkingDay la ngay cuoi cung cua thang truoc, tu ngay 2 duoc
  UPDATE #tmpSeniority SET LastMonthAddition = 0 where day(TerminateDate) = 1

 --tru 2 la tru thang dau tien va thang cuoi cung
 UPDATE #tmpSeniority SET Months = DATEDIFF(month,BeginDate,EndDate) - 2 + FirstMonthAddition + LastMonthAddition
end

CREATE TABLE #tblSeniorityAllowance(EmployeeID varchar(20),AllowanceAmount float(53))

insert into #tblSeniorityAllowance(EmployeeID,AllowanceAmount)
select EmployeeID,c.AllowanceAmt from #tmpSeniority a cross apply (
 select Min(FromMonth) FromMonth

  from tblSeniorityAllwanceSetting b where a.Months between b.FromMonth and b.ToMonth
) b
inner join tblSeniorityAllwanceSetting c on b.FromMonth = c.FromMonth

UPDATE a set ReceiveAmount = s.AllowanceAmount
from #tblAllowance a
inner join #tblSeniorityAllowance s on a.EmployeeID = s.EmployeeID
where a.AllowanceRuleID in (13)
--cap nhat phu cap tham nien vao bang history
set @Query = ''
select @Query += '
update sal set ['+AllowanceCode+'] = ReceiveAmount
 from tblSalaryHistory sal
inner join #tblAllowance al on sal.SalaryHistoryID = al.SalaryHistoryID
where al.AllowanceCode= '''+AllowanceCode+'''
'

from (select Distinct AllowanceCode from #tblAllowance al where al.AllowanceRuleID = 13 ) al

EXECUTE sp_executesql @Query


if(OBJECT_ID('SALCAL_ALLOWANCE_SENIORIRY_FINISHED' )is null)
 begin
exec('CREATE PROCEDURE dbo.SALCAL_ALLOWANCE_SENIORIRY_FINISHED
(
 @StopUPDATE bit output,
 @Month int,

 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;

end')
end

set @StopUPDATE = 0
exec SALCAL_ALLOWANCE_SENIORIRY_FINISHED @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID


-- chuyên cần, chuyen can chuyencan
-- RuleID = 9

if(OBJECT_ID('SALCAL_ALLOWANCE_DILIGENTALL_INITIAL' )is null)
 begin
exec('CREATE PROCEDURE dbo.SALCAL_ALLOWANCE_DILIGENTALL_INITIAL
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_ALLOWANCE_DILIGENTALL_INITIAL @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID


if(OBJECT_ID('SALCAL_ALLOWANCE_DILIGENTALL_FINISHED' )is null)
 begin
exec('CREATE PROCEDURE dbo.SALCAL_ALLOWANCE_DILIGENTALL_FINISHED
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_ALLOWANCE_DILIGENTALL_FINISHED @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

-- ket thuc chuyen can
-- Lap trinh rieng theo quy tac cua khach hang
if(OBJECT_ID('SALCAL_ALLOWANCE_CUSTOMER_RULE' )is null)
 begin
exec('CREATE PROCEDURE dbo.SALCAL_ALLOWANCE_CUSTOMER_RULE
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_ALLOWANCE_CUSTOMER_RULE @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

-- cộng Retro allowance vào
create table #tblRetro_Allowance_detail (EmployeeId varchar(20),AllowanceCode nvarchar(200),Amount money)
select SUBSTRING(SUBSTRING(c.COLUMN_NAME,4,9999),1,LEN(SUBSTRING(c.COLUMN_NAME,4,9999))-6)  as AllowanceName,c.COLUMN_NAME
into #AllowanceCodeFromRetroTable
from INFORMATION_SCHEMA.COLUMNS c where c.TABLE_NAME = 'tblSal_Retro_Sumary' and c.COLUMN_NAME in
(select 'AL_'+AllowanceCode+'_Retro' from tblAllowanceSetting where Visible = 1)


if (select COUNT(1) from #AllowanceCodeFromRetroTable) > 0
begin
 set @Query =''
 select @Query +=' select EmployeeID,''' +AllowanceName + ''','+COLUMN_NAME+'
 from #tblsal_retro_Final where '+COLUMN_NAME+' <> 0
 union all' from #AllowanceCodeFromRetroTable

 set @Query = SUBSTRING(@Query,1,len(@Query) -LEN('union all'))

 set  @Query = 'insert into #tblRetro_Allowance_detail(EmployeeId,AllowanceCode,Amount)
 '+ @Query
 exec(@Query)
end
-- so lan di cong tac
--UPDATE #tblAllowance SET TotalPaidDays = bzC.BZCount, ReceiveAmount = a.Raw_DefaultAmount * bzC.BZCount
--from  #tblAllowance a inner join tblAllowanceRule r on a.AllowanceRuleID = r.AllowanceRuleID and ISNULL(MultipliToBZDays,0) = 1
--inner join (select EmployeeID, COUNT(1) BZCount from  #tblLvHistory where LeaveCode in ('BZ','CT') group by EmployeeID) bzC on a.EmployeeID = bzC.EmployeeID

update al set RetroAmount = re.Amount, ReceiveAmount = ISNULL(ReceiveAmount,0) + ISNULL(re.Amount,0)   from #tblRetro_Allowance_detail re
inner join #tblAllowance al  on re.EmployeeId = al.EmployeeID and re.AllowanceCode = al.AllowanceCode
-- hết cộng retro vào

UPDATE #tblAllowance set UntaxableAmount = TaxfreeMaxAmount
from #tblAllowance a
--inner join tblAllowanceSetting al on a.AllowanceID = al.AllowanceID



UPDATE #tblAllowance set UntaxableAmount = 0 where UntaxableAmount is null

UPDATE #tblAllowance set
UntaxableAmount = round(CASE WHEN ISNULL(ReceiveAmount,0) - ISNULL(RetroAmount,0) > UntaxableAmount THEN UntaxableAmount ELSE ISNULL(ReceiveAmount,0) - ISNULL(RetroAmount,0) END,@ROUND_SALARY_UNIT)
,RetroAmountNonTax = round(CASE WHEN ISNULL(ReceiveAmount,0)  > UntaxableAmount THEN UntaxableAmount ELSE ISNULL(ReceiveAmount,0)  END,@ROUND_SALARY_UNIT)
- round(CASE WHEN ISNULL(ReceiveAmount,0) - ISNULL(RetroAmount,0) > UntaxableAmount THEN UntaxableAmount ELSE ISNULL(ReceiveAmount,0) - ISNULL(RetroAmount,0) END,@ROUND_SALARY_UNIT)

-- phụ cấp trang phục, đồng phục, 1 năm được miễn thuế 5tr, nếu vượt quá thì không được miễn thuế nữa
UPDATE a
SET UntaxableAmount = round(CASE
 WHEN ISNULL(a.ReceiveAmount,0) > t.TaxfreeMaxAmount THEN t.TaxfreeMaxAmount
 ELSE a.ReceiveAmount
 END,@ROUND_SALARY_UNIT)
FROM #tblAllowance a
INNER JOIN
 (SELECT tmp.EmployeeID,
 tmp.AllowanceID,

 sa.TaxfreeMaxAmount - ISNULL(tmp.UntaxableAmount,0) TaxfreeMaxAmount
 FROM tblAllowanceSetting sa
 INNER JOIN
 (SELECT a.EmployeeID,
 SUM(a.UntaxableAmount) UntaxableAmount,
 sa.AllowanceID
 FROM #tblSal_Allowance_Detail_des a
 INNER JOIN tblAllowanceSetting sa ON a.AllowanceID = sa.AllowanceID
 AND isnull(sa.isUniformAllowance,0) = 1
 INNER JOIN #tblAllowance al ON a.EmployeeID = al.EmployeeID
 AND al.AllowanceID = a.AllowanceID
 WHERE (a.Month + a.Year*12) BETWEEN @Year*12+1 AND @Year*12 +12
 AND a.Month + a.Year <> @month + @year
 GROUP BY a.EmployeeID,
 a.AllowanceID,
 sa.AllowanceID) tmp ON sa.AllowanceID = tmp.AllowanceID) t ON a.EmployeeID = t.EmployeeID
AND a.AllowanceID = t.AllowanceID




-- phụ cấp nhà ở
DECLARE @HouseAllPercent REAL
set @HouseAllPercent = (select cast(Value as float(53)) from tblParameter where code = 'HOUSE_ALL_PER_COMP')
set @HouseAllPercent = isnull(@HouseAllPercent,15)

--tổng số tiền tinh thuế kovượt quá 15% tổng thu nhập chịu thuế (không bao gồm phụ cấp nhà ở)
-- tổng hợp thu nhập chịu thuế chua gồm tiền nhà

  -- Hiếu: Chỉ giữ lại phụ cấp cho dòng lương mới nhất, dòng lương cũ set bằng 0
  update #tblAllowance set ReceiveAmount = 0, UntaxableAmount = 0, RetroAmount = 0, RetroAmountNonTax = 0
  where LatestSalEntry = 0

  UPDATE #tblAllowance SET ReceiveAmount = ROUND(ReceiveAmount,@ROUND_SALARY_UNIT)
UPDATE #tblSalDetail SET ActualMonthlyBasic = ROUND(ActualMonthlyBasic,@ROUND_SALARY_UNIT)
update #tblSalDetail set ActualMonthlyBasic = ISNULL(ActualMonthlyBasic,0)
+ ISNULL(sr.ActualMonthlyBasic_Retro_Amount,0)
from #tblSalDetail  sal
inner join #tblsal_retro_Final sr on sal.EmployeeID = sr.EmployeeID --and sr.Month= @Month and sr.Year= @Year
where sal.LatestSalEntry = 1

UPDATE #tblAllowance set TaxableAmount = ISNULL(ReceiveAmount,0) - ISNULL(RetroAmount,0) - ISNULL(UntaxableAmount,0)



create table #tblAdjustmentNeedConfig(EmployeeId varchar(20),IncomeID int)

insert into #tblAdjustmentNeedConfig(EmployeeId,IncomeID)
select EmployeeId,IncomeID from
(
update #AdjustmentSum set  UntaxableAmount = case when a.AdjustmentAmount > al.TaxFreeMaxAmount  - al.UntaxableAmount then al.TaxFreeMaxAmount  - al.UntaxableAmount else  a.AdjustmentAmount end
output inserted.EmployeeID,inserted.IncomeID
from #AdjustmentSum a
inner join tblIrregularIncome irr on a.IncomeID = irr.IncomeID
inner join tblAllowanceSetting als on irr.TaxBaseOnAllowanceCode = als.AllowanceCode
inner join #tblAllowance al on als.AllowanceID = al.AllowanceID and a.EmployeeID = al.EmployeeID
where al.TaxFreeMaxAmount  > al.UntaxableAmount
) ud
if @@ROWCOUNT >0
begin
 update #AdjustmentSum set TaxableAmount = AdjustmentAmount - ISNULL(a.UntaxableAmount,0)
 from #AdjustmentSum a
 inner join  #tblAdjustmentNeedConfig  n on a.EmployeeID = n.EmployeeId and a.IncomeID = n.IncomeID
end
drop table #tblAdjustmentNeedConfig
-- người vận chuyển đoạn insert update của thằng adjustment xuống đây

INSERT INTO #tblSal_Adjustment_des (EmployeeID, Month, Year, IncomeID,Amount,Raw_Amount,PeriodID,UntaxableAmount,TaxableAmount )
SELECT EmployeeID ,@Month
 ,@Year
 ,IncomeID
 ,AdjustmentAmount
 ,Raw_AdjustmentAmount
,@PeriodID,UntaxableAmount,TaxableAmount
FROM #AdjustmentSum

UPDATE #tblSalDetail set
TaxableAdjustmentTotal =round(tmp.TaxableAmount,@ROUND_SALARY_UNIT)
,TaxableAdjustmentTotal_ForSalary =round(tmp.TaxableAmount_ForSalary,@ROUND_SALARY_UNIT)
,TaxableAdjustmentTotal_NotForSalary =round(tmp.TaxableAmount_NotForSalary,@ROUND_SALARY_UNIT)
, NoneTaxableAdjustmentTotal = round(tmp.UntaxableAmount,@ROUND_SALARY_UNIT)
, TotalAdjustmentForSalary = round(tmp.TotalAdjustmentForSalary,@ROUND_SALARY_UNIT)
, TotalAdjustment_WithoutForce = round(tmp.TotalAdjustment_WithoutForce,@ROUND_SALARY_UNIT)

from #tblSalDetail sal,(
select
a.EmployeeID,SUM(case when i.IncomeKind = 0 then -1* UntaxableAmount else UntaxableAmount end) UntaxableAmount
,SUM(case when i.IncomeKind = 0 then -1* TaxableAmount else TaxableAmount end) TaxableAmount
,SUM(case when isnull(i.ForSalary,0) = 0 then 0 when i.IncomeKind = 0 then -1* AdjustmentAmount else AdjustmentAmount end *case when Taxable = 1 then 1 else 0 end) TaxableAmount_ForSalary
,SUM(case when isnull(i.ForSalary,0) = 1 then 0 when i.IncomeKind = 0 then -1* TaxableAmount else TaxableAmount end) TaxableAmount_NotForSalary
,SUM(case when ISNULL(i.ForSalary,0) = 0 then 0 else case when i.IncomeKind = 0 then -1 else 1 end * AdjustmentAmount end) TotalAdjustmentForSalary
,SUM(case when ISNULL(ForceNonTax,0) =0 then
   case when i.IncomeKind = 0 then -1 else 1 end * AdjustmentAmount
else 0 end) TotalAdjustment_WithoutForce
 ,sum(case when i.incomeKind = 1 then 1 else 0 end * a.AdjustmentAmount) as TotalDeductFromTotalEarnCauseOfNegativeAmount
from #AdjustmentSum a
inner join tblIrregularIncome i on a.IncomeID = i.IncomeID group by a.EmployeeID
) tmp where sal.EmployeeID = tmp.EmployeeID and sal.LatestSalEntry = 1



 --OtherDeductionAfterPIT
update #tblSalDetail set OtherDeductionAfterPIT = tmp.Amount from #tblSalDetail s inner join (
select a.EmployeeID,sum(a.AdjustmentAmount) Amount from #AdjustmentSum a
inner join tblIrregularIncome ir on a.IncomeID = ir.IncomeID and ir.IncomeKind = 0 and isnull(ir.Taxable,0) = 0
group by a.EmployeeID
) tmp on s.EmployeeID = tmp.EmployeeID


if(OBJECT_ID('SALCAL_ADJUSTMENT_FINISHED' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_ADJUSTMENT_FINISHED
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_ADJUSTMENT_FINISHED @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID
-- hết adjustment




UPDATE #tblSalDetail set TaxableIncomeBeforeDeduction = ISNULL(ActualMonthlyBasic,0) + ISNULL(TotalNSAmt,0) - isnull(NoneTaxableNSAmt,0) + ISNULL(TaxableAdjustmentTotal,0)
 + isnull(TaxableOTTotal,0)

UPDATE s set TaxableIncomeBeforeDeduction = TaxableIncomeBeforeDeduction + tmp.TaxableAmount
from #tblSalDetail s inner join (
 select a.EmployeeID,SUM(ISNULL(a.TaxableAmount,0)) TaxableAmount
 from #tblAllowance a
 inner join tblAllowanceSetting sa on a.AllowanceID = sa.AllowanceID
 and isnull(sa.IsHouseAllowance,0) = 0
 group by EmployeeID
) tmp on s.EmployeeID = tmp.EmployeeID

-- cộng với lương từ nước ngoài để gross up

-- delete first
select sa.* into #tblSalaryAbroad from #tblEmployeeIDList e
cross apply(select MAX(Month+Year*12) MY from tblSalaryAbroad  sa1 where e.EmployeeID = sa1.EmployeeID and  sa1.Month+sa1.Year*12 <= @month+@year*12
 and (sa1.ToMonth is null or sa1.ToYear is null  or sa1.ToMonth +sa1.ToYear *12 >=  @month+@year*12 )
 ) ca
 inner join tblSalaryAbroad sa  on sa.EmployeeID = e.EmployeeID and sa.Month+sa.Year *12 = ca.MY



insert into #tblSal_Abroad_ForTaxPurpose_Des
 (
  EmployeeID,Month,Year
  ,NetAmountVND,Raw_NetAmount,
  GrossAmountVND,Raw_GrossAmount
  ,CurrencyCode,ExchangeRate
  ,NationID
  ,PeriodID
  ,VND_Amount
  ,Raw_Amount_AfterDeductVND
 )
select
 sa.EmployeeID,@month as month,@Year as year
 ,round(isnull(NetAmount,0) *c.[ExchangeRate],@ROUND_SALARY_UNIT) as NetAmountVND
 ,NetAmount as Raw_NetAmount
 ,round(isnull(GrossAmount,0) *c.[ExchangeRate],@ROUND_SALARY_UNIT) as GrossAmountVND
 ,GrossAmount as Raw_Amount
 ,sa.CurrencyCode
 ,c.[ExchangeRate] as ExchangeRate,sa.NationID

 ,@PeriodID
 ,sa.VND_Amount
 ,NetAmount - (sa.VND_Amount/c.[ExchangeRate]) as Raw_Amount_AfterDeductVND
 from #tblSalaryAbroad sa
 inner join #tblSalDetail sal on sa.EmployeeID = sal.EmployeeID and sal.LatestSalEntry = 1
 left join #EmployeeExchangeRate c on sa.CurrencyCode = c.CurrencyCode and c.EmployeeID = sa.EmployeeID


-- lấy danh sách allowance Gross ra trừ đi trước khi grossup
-- có thể net hóa nó nhưng mà khó lém
select EmployeeID,sum(TaxableAmount) as TotalGrossAllowanceAmount_Taxable
into #grossAllowanceAmount
from #tblAllowance a
inner join tblAllowanceSetting al on a.AllowanceCode = al.AllowanceCode
where al.IsTaxable = 1 and al.IsGrossAllowance_InNetSal = 1
group by EmployeeID
if @@ROWCOUNT >0 -- nếu có gross allowance thì phải trừ đi rồi mới gross up
begin
 update #tblSalDetail
 set TaxableIncomeBeforeDeduction = TaxableIncomeBeforeDeduction - isnull(gross.TotalGrossAllowanceAmount_Taxable,0)
 from #tblSalDetail sal
 inner join #grossAllowanceAmount gross on sal.EmployeeID =gross.EmployeeID and sal.LatestSalEntry =1
 where sal.IsNet =1
end



-- cộng cục này với phần Net từ nước ngoài trả
 update #tblSalDetail set TaxableIncomeBeforeDeduction += isnull(ca.NetAmountVND,0) -- cộng phần net để grossup trước

from #tblSalDetail sal
 cross apply(select sum(NetAmountVND) as NetAmountVND
 from #tblSal_Abroad_ForTaxPurpose_des sa
 where sa.Month=@Month and sa.Year= @Year and sa.EmployeeID = sal.EmployeeID) ca
 where sal.LatestSalEntry = 1 and sal.IsNet =1

 -- custom lấy cái TotalNetIncome ra nào
 update #tblSalDetail set TotalNetIncome_Custom  = TaxableIncomeBeforeDeduction
--gross it up


select
(IncomeFrom - (IncomeFrom - 1)) * TaxPercent + ProgressiveAmount as MinTax -- số thuế tối thiểu phải đóng
,(IncomeTo - (IncomeFrom - 1)) * TaxPercent + ProgressiveAmount as MaxTax -- số thuế tối đa phải đóng
,IncomeFrom-1--+9000000
-((IncomeFrom - (IncomeFrom - 1)) * TaxPercent + ProgressiveAmount) as MinNet -- số tiền net tối thiểu (chưa tính giảm trừ trong này nha)
,IncomeTo-1--+9000000
-((IncomeTo - (IncomeFrom - 1)) * TaxPercent + ProgressiveAmount) as MaxNet -- số tiền net tối đa (chưa tính giảm trừ trong này nha)
,*
into #TaxForGrossup
from tblTax tt WHERE tt.EffectDate =
(SELECT Max(EffectDate) FROM tblTax tx WHERE tx.EffectDate<= @FromDate )--for gross up


 declare @PesonalDeduct float(53),@RelationDeduct float(53)
 select @PesonalDeduct = TAX_PERSONAL_DEDUCT, @RelationDeduct  = TAX_RELATE_DEDUCT from fn_TaxDeduction_byMonthYear(@Month,@Year)

 --set @PesonalDeduct = (select cast(Value as float(53)) from tblParameter where code = 'TAX_PERSONAL_DEDUCT')
 set @PesonalDeduct = isnull(@PesonalDeduct,9000000)
 --set @RelationDeduct = (select cast(Value as float(53)) from tblParameter where code = 'TAX_RELATE_DEDUCT')
 set @RelationDeduct = isnull(@RelationDeduct,3600000)

 select EmployeeID,count(EmployeeID)as CountDeduct
 into #CountRelation
 from tblFamilyInfo where TaxDependant =1
 and EmployeeID in(select EmployeeID from #tblEmployeeIDList)
 and ISNULL(EffectiveDate,@ToDate) <= @ToDate
 and ISNULL(EffectiveToDate,@FromDate) >= @FromDate
 group by EmployeeID

 -- đang làm tới đây
----update dependant truocws nhes
--select TaxableIncomeBeforeDeduction,-- tính before tax coi có ngon chưa nào
update sal set TaxableIncomeBeforeDeduction =
round(
(IncomeFrom-1)+ -- lấy khoản Income from
((TaxableIncomeBeforeDeduction -(MinNet + @PesonalDeduct +(isnull(c.CountDeduct,0)*@RelationDeduct) ))/(1-TaxPercent)) -- cộng với công thức ba lăng nhăng
+ @PesonalDeduct +(isnull(c.CountDeduct,0)*@RelationDeduct) -- cộng với giảm trừ bản thân, gia đình, tới đây còn thiếu cái tiền bảo hiểm tý mới cộng
 --as TaxableIncomeBeforeDeduction_GrossedUp
--,MinNet
--,*
,0,1)
from #tblSalDetail sal
left join #CountRelation c on sal.EmployeeID = c.EmployeeID
inner join #TaxForGrossup tg on sal.TaxableIncomeBeforeDeduction -- đổi với những người lương NET thì cái này được hiểu là tổng lương net Nhé anh em
 - @PesonalDeduct -(isnull(c.CountDeduct,0)*@RelationDeduct) between tg.MinNet and tg.MaxNet
where IsNet = 1




update #tblSalDetail set GrossedUpWithoutHousing_WithoutGrossIncome_Custom = TaxableIncomeBeforeDeduction

if exists(select 1 from #grossAllowanceAmount)-- nếu có gross allowance thì cộng vào lại chứ ko vỡ mồm
begin
 update #tblSalDetail
 set TaxableIncomeBeforeDeduction = TaxableIncomeBeforeDeduction + isnull(gross.TotalGrossAllowanceAmount_Taxable,0)
 from #tblSalDetail sal
 inner join #grossAllowanceAmount gross on sal.EmployeeID =gross.EmployeeID and sal.LatestSalEntry =1
 where sal.IsNet =1
end
-------------------------Calculate Employee insurance --------------------------------
if @PeriodID in (0,2)
begin
    --exec EmpInsuranceMonthly_List @Month = @Month,@Year = @Year ,@LoginID = @LoginID, @CalFromSalCal = 1 ,@EmployeeID = @EmployeeID
 --Code lại tính bảo hiểm
 create table #InsuranceTmp
 (
  EmployeeID varchar(20),Month int,Year int,
  IsEmpSI bit,IsEmpHI bit,IsEmpUI bit,
  IsComSI bit,IsComHI bit,IsComUI bit,
  Salary money,HIIncome money,SIIncome money,UIIncome money,
  EmployeeStatusID int,
  EmployeeSI money,EmployeeHI money,EmployeeUI money,
  CompanySI money,CompanySM money, CompanyHI money, CompanyUI money,
  OtherCompanyIns bit,
  ExpatIns bit,
  Notes nvarchar(max),
  InsPaymentStatus int default 0,
  SalaryHistoryID bigint
  ,EmployeeTotal money
  ,CompanyTotal money
  ,Total money
  ,CurrencyCode varchar(20)
  ,ExchangeRate money
  ,UnPaidLeave float
 )

 DECLARE @SalStart datetime = @FromDate ,@SalStop datetime =@ToDate
 select @SIDate = cast(cast(Year(@SalStop) as nvarchar(20)) +'-' +cast(Month(@SalStop) as nvarchar(20)) +'-15' as date )

 INSERT INTO #InsuranceTmp(EmployeeID,EmployeeStatusID,Month,Year,Salary,HIIncome,SIIncome,UIIncome,IsEmpHI,IsEmpUI,IsEmpSI,IsComHI,IsComUI,IsComSI,InsPaymentStatus,SalaryHistoryID,CurrencyCode,UnPaidLeave)
 select ch.EmployeeID,ch.EmployeeStatusID,@Month,@Year,ch.BasicSalary,iif(ch.InsSalary>tmp.HI_Salary,tmp.HI_Salary,ch.InsSalary) HIIncome
 --,iif(ch.InsSalary>bs.Salary*20,bs.Salary*20,ch.InsSalary) SIIncome
 ,iif(ch.InsSalary>tmp.SI_Salary,tmp.SI_Salary,ch.InsSalary) SIIncome
 ,iif(ch.InsSalary>tmp.UI_Salary,tmp.UI_Salary,ch.InsSalary) UIIncome,1,1,1,1,1,1 ,0, ch.SalaryHistoryID,sal.CurrencyCode
 ,isnull(ch.WD_Month,0) - isnull(ch.DaysOfSalEntry,0)
 from #tblSalDetail ch
 inner join tblSalaryHistory AS sal on ch.SalaryHistoryID = sal.SalaryHistoryID
 --left JOIN dbo.fn_CurrentBaseSalRegionalByDate(@SIDate) bs on isnull(sal.BaseSalRegionalID,1) = bs.BaseSalRegionalID
 cross join (
  SELECT Ceil_SalaryID, SI_Salary, UI_Salary, HI_Salary, EffectiveDate
  FROM dbo.tblSI_CeilSalary AS tscs
  WHERE (EffectiveDate =
   (SELECT MAX(EffectiveDate) AS Expr1 FROM dbo.tblSI_CeilSalary tmp WHERE (tmp.EffectiveDate <= @SIDate)))
 ) AS tmp
 where ch.LatestSalEntry = 1
 update ta1 set InsPaymentStatus = ISNULL(ta2.InsPaymentStatus,0)
 from #InsuranceTmp  ta1
 inner join tblSal_Insurance ta2 on ta1.EmployeeID = ta2.EmployeeID and ta2.Month = @Month and ta2.Year = @Year

 --mức lương tối thiểu đóng BH riêng của NPSV
 update #InsuranceTmp set HIIncome=case when HIIncome <= 5330000 then 5330000 else HIIncome end
       ,SIIncome=case when SIIncome <= 5330000 then 5330000 else SIIncome end
       ,UIIncome=case when UIIncome <= 5330000 then 5330000 else UIIncome end

 --can cu vao hop dong truoc (neu co)
 --UPDATE #InsuranceTmp SET
 --IsEmpSI = ISNULL(c.EmpSI,0),IsEmpHI = ISNULL(c.EmpHI,0),IsEmpUI = ISNULL(c.EmpUI,0),
 --IsComSI = ISNULL(CompSI,0), IsComHI = ISNULL(c.CompHI,0), IsComUI = ISNULL(CompUI,0),
 --Notes = CASE WHEN c.EmployeeID is not null THEN N'Follow labour contract' ELSE 'Has no contract!' END
 --from #InsuranceTmp tmp
 --left join (select c.EmployeeID,cis.*
 -- from dbo.fn_CurrentContractListByDate(@SIDate) c
 -- inner  join tblLabourContract lb on c.ContractID = lb.ContractID
 -- inner join ContractInsuranceStatus cis on isnull(lb.InsuranceStatusID,-1) = cis.InsuranceStatusID
 --) c  on tmp.EmployeeID = c.EmployeeID
 --where InsPaymentStatus = 0

 UPDATE #InsuranceTmp SET SIIncome = 0, HIIncome = 0, UIIncome = 0, IsComSI = 0, IsComHI = 0, IsComUI = 0, IsEmpSI = 0, IsEmpHI = 0, IsEmpUI = 0
 , Notes = N'Empty Insurance salary!'+ ISNULL(' - ' + Notes,'')
 where (SalaryHistoryID is null or ISNULL(SIIncome,0) = 0)

 UPDATE #InsuranceTmp SET IsComSI = 0, IsComHI = 0, IsComUI = 0, IsEmpSI = 0, IsEmpHI = 0, IsEmpUI = 0, Notes = 'probation'
 from #InsuranceTmp t
 where exists(select 1 from #tblEmployeeIDList te where t.EmployeeID = te.EmployeeID and te.ProbationEndDate >= @SIDate)

 UPDATE s SET IsComSI = 0, IsComHI = 0, IsComUI = 0, IsEmpSI = 0, IsEmpHI = 0, IsEmpUI = 0, Notes = isnull(Notes,'Unpaid leaves >= 14')
 from #InsuranceTmp s
 where (isnull(UnPaidLeave,0) >= 14
 and not exists(select 1 from #tblSalDetail sa where sa.EmployeeID=s.EmployeeID
    and (sa.AfterMaternity < @SIDate or sa.Maternity > @SIDate or sa.LBIssueDate < @SIDate )
    and sa.TerminateDate is null
   )
 )
 or exists(select 1 from #tblSalDetail sa where sa.EmployeeID=s.EmployeeID
        and (sa.AfterMaternity > @SIDate or sa.Maternity < @SIDate
            or sa.LBIssueDate > @SIDate or sa.TerminateDate < @SIDate)
  )

 --xu ly Payment status
 UPDATE #InsuranceTmp SET IsComSI = 1, IsComHI = 1, IsComUI = 1, IsEmpSI = 1, IsEmpHI = 1, IsEmpUI = 1 where InsPaymentStatus in (1,5) --dong day du
 UPDATE #InsuranceTmp SET IsEmpSI = 0, IsEmpHI = 0, IsEmpUI = 0 where InsPaymentStatus = 2 --cty dong het thi setup nhan vien ve 0  ==> ko nen setup ca phan cua cty vi con can cu vao hop dong nua
 UPDATE #InsuranceTmp SET IsComSI = 0, IsComHI = 0, IsComUI = 0 where InsPaymentStatus = 3 --nhan vien dong het thi nguoc voi cty
 UPDATE #InsuranceTmp SET IsComSI = 0, IsComHI = 0, IsComUI = 0, IsEmpSI = 0, IsEmpHI = 0, IsEmpUI = 0 where InsPaymentStatus = 4 --khong dong bh

 UPDATE #InsuranceTmp SET IsComSI = 0, IsComHI = 0, IsComUI = 0, IsEmpSI = 0, IsEmpHI = 0, IsEmpUI = 0 WHERE InsPaymentStatus = 7 --truy thu 4.5%

 --Tinh luong Insurance
 UPDATE #InsuranceTmp SET
  EmployeeSI = ROUND(SIIncome * p.SI_EmpPercent/100.0,0),
  CompanySI  =  ROUND(SIIncome * p.SI_CompPercent/100.0,0),
  CompanySM  =  ROUND(SIIncome * p.SM_CompPercent/100.0,0),
  EmployeeHI =  ROUND(HIIncome * p.HI_EmpPercent/100.0,0),

  CompanyHI  =  ROUND(HIIncome * p.HI_CompPercent/100.0,0),
  EmployeeUI =  ROUND(UIIncome * p.UI_EmpPercent/100.0,0),
  CompanyUI  =  ROUND(UIIncome * p.UI_CompPercent/100.0,0)
 from #InsuranceTmp tmp cross join dbo.fn_CurrentInsurancePercentage(@SIDate) p

 --truy thu 4.5% đưa vào khoản điều chỉnh
 insert into tblPR_Adjustment(EmployeeID,Month,Year,IncomeID,Amount,CurrencyCode,Remark)
 select sa.EmployeeID, @Month, @Year,18  IncomeID,  HIIncome * 0.045, 'VND', 'System automatic calculate'
 from #InsuranceTmp sa
 where sa.InsPaymentStatus = 7 and not exists(select 1 from tblPR_Adjustment p
 where p.EmployeeID=sa.EmployeeID and p.IncomeID=23 and p.Month=@Month and p.Year=@Year)

 --cong tru neu chi dong 1 ben
 UPDATE #InsuranceTmp SET
 EmployeeSI = EmployeeSI*IsEmpSI + CompanySI*~IsComSI + CompanySM*~IsComSI, CompanySI = CompanySI*IsComSI + EmployeeSI*~IsEmpSI,
 EmployeeHI = EmployeeHI*IsEmpHI + CompanyHI*~IsComHI, CompanyHI = CompanyHI*IsComHI + EmployeeHI*~IsEmpHI,
 EmployeeUI = EmployeeUI*IsEmpUI + CompanyUI*~IsComUI, CompanyUI = CompanyUI*IsComUI + EmployeeUI*~IsEmpUI
 where (IsEmpSI <> IsComSI or IsEmpHI <> IsComHI or IsEmpUI <> IsComUI)


 --truong hop 2 ben deu khong dong 1 loai bao hiem, vd nguoi nuoc ngoai chi dong BHYT
 UPDATE #InsuranceTmp SET EmployeeSI = 0, CompanySI = 0, CompanySM = 0 where IsEmpSI = 0 and IsComSI = 0
 UPDATE #InsuranceTmp SET EmployeeHI = 0, CompanyHI = 0 where IsEmpHI = 0 and IsComHI = 0
 UPDATE #InsuranceTmp SET EmployeeUI = 0, CompanyUI = 0 where IsEmpUI = 0 and IsComUI = 0

 /*
 UPDATE #InsuranceTmp SET EmployeeHI = EmployeeHI + CompanyHI, CompanyHI = 0
 FROM #InsuranceTmp isn
 WHERE InsPaymentStatus = 7
 AND EXISTS(SELECT 1 FROM tblEmployee ee
INNER JOIN tblNation na ON ISNULL(ee.NationID,234) = na.NationID AND na.IsVietNam = 1 WHERE isn.EmployeeID = ee.EmployeeID)

 UPDATE #InsuranceTmp SET CompanyHI = EmployeeHI + CompanyHI, EmployeeHI = 0
 FROM #InsuranceTmp isn
 WHERE InsPaymentStatus = 7
 AND NOT EXISTS(SELECT 1 FROM tblEmployee ee
  INNER JOIN tblNation na ON ISNULL(ee.NationID,234) = na.NationID AND na.IsVietNam = 1 WHERE isn.EmployeeID = ee.EmployeeID)
 */

 UPDATE #InsuranceTmp SET Notes = 'Salary changed'
 from #InsuranceTmp t
  inner join tblSal_Insurance s on t.EmployeeID = s.EmployeeID and s.Year*12+s.Month = @Year*12+@Month-1
 where (t.SIIncome <> s.SIIncome or t.UIIncome <> s.UIIncome)
 and t.Notes is null

 UPDATE #InsuranceTmp SET Notes = 'Encrease'
 from #InsuranceTmp t
  left join tblSal_Insurance s on t.EmployeeID = s.EmployeeID and s.Year*12+s.Month = @Year*12+@Month-1
 where (s.EmployeeID is null or ISNULL(s.Total,0) = 0)
 and (t.EmployeeSI <> 0 or t.CompanySI <> 0 or t.EmployeeHI <> 0 or t.CompanyHI <> 0 or t.EmployeeUI <> 0 or t.CompanyUI <> 0)
 and t.Notes is null

 -- đóng ở cty khác thì chỉ đong 0.5% Bảo hiểm tai nạn
 --update tmp set OtherCompanyIns = 1
 --from #InsuranceTmp tmp inner join #tblEmployeeIDList te on tmp.EmployeeID = te.EmployeeID
 --where te.EmpInsuranceStatusID = 3

 UPDATE #InsuranceTmp SET
 EmployeeSI = 0,
 CompanySI  = ROUND(SIIncome * p.AI_CompPercent/100.0,0),
 EmployeeHI = 0,
 CompanyHI  = 0,
 EmployeeUI = 0,
 CompanyUI  = 0
 from #InsuranceTmp tmp cross join dbo.fn_CurrentInsurancePercentage(@SIDate) p
 where tmp.OtherCompanyIns = 1

 -- người nước ngoài mà có tham gia bảo hiểm thì đóng BHYT và BHXH, và đóng theo mức riêng (nếu có set) ExpatIns
 --update tmp set ExpatIns = 1
 --from #InsuranceTmp tmp inner join tblEmployee te on tmp.EmployeeID = te.EmployeeID
 --where isnull(te.EmpInsuranceStatusID,-1) = -1 and (te.NationID is not null and te.NationID not in (select NationID from tblNation where IsVietNam =1))

 UPDATE #InsuranceTmp SET
 EmployeeSI = ROUND(SIIncome * ISNULL(p.Ex_SI_EmpPercent, p.SI_EmpPercent)/100.0,0),
 CompanySI  =  ROUND(SIIncome * ISNULL( p.Ex_SI_CompPercent, p.SI_CompPercent)/100.0,0),
 EmployeeHI =  ROUND(HIIncome * isnull(p.Ex_HI_EmpPercent,p.HI_EmpPercent)/100.0,0),
 CompanyHI  =  ROUND(HIIncome * isnull(p.Ex_HI_CompPercent,p.HI_CompPercent)/100.0,0),
 EmployeeUI =  0,
 CompanyUI  =  0
 from #InsuranceTmp tmp cross join dbo.fn_CurrentInsurancePercentage(@SIDate) p
 where tmp.ExpatIns = 1 and tmp.InsPaymentStatus = 0

 --Cập nhật dữ liệu tổng
 UPDATE #InsuranceTmp SET EmployeeTotal = ISNULL(EmployeeHI,0) + ISNULL(EmployeeSI,0) + ISNULL(EmployeeUI,0)
 ,CompanyTotal = ISNULL(CompanyHI,0) + ISNULL(CompanySI,0) + ISNULL(CompanySM,0)  + ISNULL(CompanyUI,0)
 ,Total = ISNULL(EmployeeHI,0) + ISNULL(EmployeeSI,0) + ISNULL(EmployeeUI,0)
 + ISNULL(CompanyHI,0) + ISNULL(CompanySI,0) + ISNULL(CompanySM,0)  + ISNULL(CompanyUI,0)

 --tính toán lại
 delete si from tblSal_Insurance si where Month = @Month and Year = @Year and ISNULL(Approval,0) = 0
 and exists(select 1 from #InsuranceTmp ins where ins.EmployeeID=si.EmployeeID)

 insert into tblSal_Insurance (EmployeeID, Year, Month, HIIncome, SIIncome, UIIncome, EmployeeHI, EmployeeSI, EmployeeUI, CompanyHI, CompanySI, CompanySM,
 CompanyUI, SalaryHistoryID,InsPaymentStatus,Notes,Approval,EmployeeTotal,CompanyTotal,Total)
 select tmp.EmployeeID, @Year, @Month, HIIncome, SIIncome, UIIncome,
 EmployeeHI, EmployeeSI, EmployeeUI,
 CompanyHI, CompanySI, CompanySM, CompanyUI,
 SalaryHistoryID ,InsPaymentStatus,Notes,0,EmployeeTotal,CompanyTotal,Total
 from #InsuranceTmp tmp
 where not exists(select 1 from tblSal_Insurance sa where sa.EmployeeID=tmp.EmployeeID and sa.Month = @Month and sa.Year = @Year)

end

----khong co cham cong thi khong dong bao


--select si.EmployeeTotal,TaxableIncomeBeforeDeduction,TaxableIncomeBeforeDeduction*0.15,*
update sal set
 TaxableIncomeBeforeDeduction = TaxableIncomeBeforeDeduction + isnull(si.EmployeeTotal,0)
 ,GrossedUpWithoutHousing_WithoutGrossIncome_Custom = GrossedUpWithoutHousing_WithoutGrossIncome_Custom + isnull(si.EmployeeTotal,0)
from #tblSalDetail sal
inner join tblSal_Insurance si on sal.EmployeeID = si.EmployeeID and si.Month= @Month and si.Year = @Year
where sal.LatestSalEntry = 1
and sal.IsNet =1
and @PeriodID in (0,2)

-- cộng thêm lương gross từ nước ngoài
update sal set TaxableIncomeBeforeDeduction = TaxableIncomeBeforeDeduction + isnull(ca.GrossAmountVND,0)
from #tblSalDetail sal
cross apply(select sum(GrossAmountVND) as GrossAmountVND
 from #tblSal_Abroad_ForTaxPurpose_des sa
 where sa.Month=@Month and sa.Year= @Year and sa.EmployeeID = sal.EmployeeID) ca
where sal.LatestSalEntry = 1
and sal.IsNet =1

update #tblSalDetail set GrossedUpWithoutHousing_Custom = round(TaxableIncomeBeforeDeduction,0)

--tien nha mac dinh tinh thue het, neu vuot qua 15% thu nhap chiu thue thi duoc mien thue phan du tren 15% đó ~~ TriNg: la khoản fixed - nen thue f lay full thang
UPDATE a set
UntaxableAmount = round(CASE WHEN ISNULL(a.ReceiveAmount,0)>s.TaxableIncomeBeforeDeduction*@HouseAllPercent/100.0
 THEN a.ReceiveAmount - s.TaxableIncomeBeforeDeduction*@HouseAllPercent/100.0 ELSE 0 END,@ROUND_SALARY_UNIT)
 from #tblAllowance a
 inner join tblAllowanceSetting sa
    on a.AllowanceID = sa.AllowanceID and sa.IsHouseAllowance = 1 and a.ReceiveAmount >0
inner join (SELECT EmployeeID, SUM(TaxableIncomeBeforeDeduction)TaxableIncomeBeforeDeduction FROM #tblSalDetail GROUP BY EmployeeID) s on a.EmployeeID = s.EmployeeID



if(OBJECT_ID('SALCAL_ALLOWANCE_FINISHED' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_ALLOWANCE_FINISHED
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20),
 @CalculateRetro bit =0
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_ALLOWANCE_FINISHED @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID,@CalculateRetro


UPDATE #tblAllowance SET TaxableAmount = ISNULL(ReceiveAmount,0) - ISNULL(RetroAmount,0)   - ISNULL(UntaxableAmount,0)

delete #tblAllowance where DefaultAmount is null and ReceiveAmount is null

UPDATE #tblAllowance set ReceiveAmount = 0 where ReceiveAmount is null

update #tblAllowance set
ReceiveAmount = ROUND(ReceiveAmount,@ROUND_SALARY_UNIT),
 TaxableAmount = ROUND(TaxableAmount,@ROUND_SALARY_UNIT),
 UntaxableAmount = ROUND(UntaxableAmount,@ROUND_SALARY_UNIT),
 MonthlyCustomAmount = ROUND(MonthlyCustomAmount,@ROUND_SALARY_UNIT),
 DefaultAmount = ROUND(DefaultAmount_WithoutCustomAmount,@ROUND_SALARY_UNIT)

--bang detail cung sum luôn, vi se co nhung thang thu viec trùng salaryhistoryid wtc
insert into #tblSal_Allowance_Detail_des (
 EmployeeID, AllowanceID, Year, Month, SalaryHistoryID, Amount,
 TakeHome, TaxableAmount, UntaxableAmount,
 DefaultAmount --chay lenh nay neu bao loi: ALTER TABLE #tblSal_Allowance_Detail_des ADD DefaultAmount float(53)
 ,Raw_DefaultAmount, Raw_CurrencyCode,
 Raw_ExchangeRate, RetroAmount
 ,RetroAmountNonTax
 ,MonthlyCustomAmount
 ,PeriodID
 ,TotalPaidDays
 )
 select
 a.EmployeeID,
 a.AllowanceID,
 @Year,
 @Month,
 a.SalaryHistoryID,
 sum(a.ReceiveAmount),
 a.TakeHome,
 sum(a.TaxableAmount),
 sum(a.UntaxableAmount),
 sum(DefaultAmount),
 sum(a.Raw_DefaultAmount),
 max(a.Raw_CurrencyCode),
 max(a.Raw_ExchangeRate)
 ,sum(a.RetroAmount)
 ,sum(a.RetroAmountNonTax)
 ,sum(a.MonthlyCustomAmount)
 ,@PeriodID
 ,sum(a.TotalPaidDays)
 from #tblAllowance a group by a.EmployeeID,a.AllowanceID,a.SalaryHistoryID,a.TakeHome


  INSERT INTO #tblSal_Allowance_des(EmployeeID,AllowanceID,[Year],[Month],Amount,TakeHome,UntaxableAmount,TaxableAmount
 ,Raw_DefaultAmount,Raw_CurrencyCode,Raw_ExchangeRate,RetroAmount,RetroAmountNonTax
 ,MonthlyCustomAmount,PeriodID)
 (
 SELECT al.EmployeeID,al.AllowanceID,@Year,@Month,SUM(ISNULL(al.ReceiveAmount,0)),al.TakeHome
  ,sum(UntaxableAmount) as UntaxableAmount,sum(TaxableAmount) as TaxableAmount
  ,sum(Raw_DefaultAmount) as Raw_DefaultAmount
  ,max(Raw_CurrencyCode) as Raw_CurrencyCode
  ,max(Raw_ExchangeRate) as Raw_ExchangeRate
  ,sum(RetroAmount) as RetroAmount
  ,SUM(RetroAmountNonTax) as RetroAmountNonTax
  ,SUM(MonthlyCustomAmount) as MonthlyCustomAmount
  ,@PeriodID
  FROM #tblAllowance al
  GROUP BY al.EmployeeID, al.AllowanceID,al.TakeHome
 )


-- taxable allowance
 UPDATE #tblSalDetail set TaxableAllowanceTotal = round(tmp.TaxableAmount,@ROUND_SALARY_UNIT)
 from #tblSalDetail sal,(
 select SUM(ISNULL(al.TaxableAmount,0)+ISNULL(al.RetroAmount,0) -ISNULL(al.RetroAmountNonTax,0)) TaxableAmount ,al.EmployeeID from #tblAllowance al group by al.EmployeeID
 ) tmp where sal.EmployeeID = tmp.EmployeeID and sal.LatestSalEntry = 1


-- Nonetaxable allowance
 UPDATE #tblSalDetail set NoneTaxableAllowanceTotal = round(tmp.UntaxableAmount,@ROUND_SALARY_UNIT) from #tblSalDetail sal,(
 select SUM(ISNULL(al.UntaxableAmount,0) + ISNULL(al.RetroAmountNonTax,0)) UntaxableAmount ,al.EmployeeID from #tblAllowance al group by al.EmployeeID
 ) tmp where sal.EmployeeID = tmp.EmployeeID and sal.LatestSalEntry = 1



 UPDATE #tblSalDetail set TotalAllowanceForSalary = tmp.ReceiveAmount from
 #tblSalDetail sal,(
  select SUM(ISNULL(al.ReceiveAmount,0)) ReceiveAmount ,al.EmployeeID
  from #tblAllowance al

  inner join tblAllowanceSetting a on al.AllowanceID = a.AllowanceID and ISNULL(a.ForSalary,0) = 1
 group by al.EmployeeID
 ) tmp where sal.EmployeeID = tmp.EmployeeID and sal.LatestSalEntry = 1




 -------------------------Calculate Employee insurance --------------------------------
--exec EmpInsuranceMonthly_List @Month = @Month,@Year = @Year ,@LoginID = @LoginID, @CalFromSalCal = 1


--bao hiem
UPDATE #tblSalDetail SET
InsAmtComp = CompanyTotal--ISNULL(CompanySI,0) + ISNULL(CompanyHI,0) + ISNULL(CompanyUI,0)
,InsAmt = EmployeeTotal--ISNULL(EmployeeSI,0) + ISNULL(EmployeeHI,0) + ISNULL(EmployeeUI,0)
FROM #tblSalDetail sd
inner join tblSal_Insurance ins
on sd.EmployeeID = ins.EmployeeID
--AND sd.SalaryHistoryID = ins.SalaryHistoryID
AND ins.[Month] = @Month
AND ins.[Year] = @Year
and sd.LatestSalEntry = 1
and @PeriodID in (0,2)
-------------------------Calculate Trade Union fee--------------------------------
declare @UNION_FEE_METHOD tinyint
-- 1: Dựa vào phần trăm lương,
-- 2: Số tiền đóng cố định,
-- 3: nhân viên đóng số tiền cố định, công ty đóng theo % lương cơ bản,
-- 4: đóng theo phần trăm lương tối thiểu,
-- 5: đóng theo phần trăm lương cơ bản, nhân viên đóng tối đa 10% lương tối thiểu
SET @UNION_FEE_METHOD = (SELECT CAST([Value] AS FLOAT) FROM tblParameter WHERE Code = 'UNION_FEE_METHOD')
set @UNION_FEE_METHOD = isnull(@UNION_FEE_METHOD,1)
-- danh sach tham gia cong doan
--co phat sinh bao hiem xa hoi trong thang nay thi se dong tien cong doan


 DECLARE @UnionPercentEmp float,@UnionPercentComp float,@UnionPackageEmp float,@UnionPackageComp float
 CREATE table #tblTradeUnion (
 EmployeeID varchar(20)
 ,BasicSalary float(53)
 ,BaseSalaryRegional float(53)
 ,IsEmpPaid bit
 ,IsComPaid bit
 ,UnionFeeEmp float(53)
 ,UnionFeeComp float(53)
 ,Comp_ByPercent bit
 ,Emp_ByPercent bit
 ,Is_CeilSalary bit
 ,UNION_PERCENT_COMP float
 ,UNION_PERCENT_EMP float
 ,UNION_PACKAGE_COMP float
 ,UNION_PACKAGE_EMP float
 ,UNION_PACKAGE_EMP_MAX float
 ,UNION_PACKAGE_COMP_MAX float
 ,MaximumByPercentsOfBaseSalaryRegional float
 )


 insert into #tblTradeUnion (EmployeeID,IsEmpPaid, IsComPaid
 ,Comp_ByPercent,Emp_ByPercent,Is_CeilSalary,UNION_PERCENT_COMP,UNION_PERCENT_EMP,UNION_PACKAGE_COMP,UNION_PACKAGE_EMP
 ,UNION_PACKAGE_EMP_MAX,UNION_PACKAGE_COMP_MAX
 ,MaximumByPercentsOfBaseSalaryRegional
 )
 select u.EmployeeID,0,1
 ,Comp_ByPercent,Emp_ByPercent,Is_CeilSalary,UNION_PERCENT_COMP,UNION_PERCENT_EMP,UNION_PACKAGE_COMP,UNION_PACKAGE_EMP
 ,isnull(UNION_PACKAGE_EMP_MAX,0),isnull(UNION_PACKAGE_COMP_MAX,0)
 ,MaximumByPercentsOfBaseSalaryRegional
 from #tblEmployeeIDList u
 inner join tblDivision div on u.DivisionID = div.DivisionID
 cross apply (select top 1(UNION_FEE_METHOD) as UNION_FEE_METHOD from tblCompany c) c
 left join tblUnionFeeMethod f on f.UnionFeeMethodID = isnull(isnull(div.UNION_FEE_METHOD,c.UNION_FEE_METHOD),3)


 --Hiếu: mặc định sẽ đóng dù không đóng bảo hiểm
UPDATE #tblTradeUnion SET IsEmpPaid = eu.EmployeePay
FROM #tblTradeUnion u INNER JOIN dbo.fn_EmployeeUnion_ByDate(@ToDate) eu ON u.EmployeeID = eu.EmployeeID
where eu.EmployeePay = 1
and eu.BeginDate <= @SIDate and (eu.EndDate is null or eu.EndDate >= @SIDate)

select EmployeeID,Year,Month,HIIncome,SIIncome,EmployeeHI,EmployeeSI,
EmployeeTotal,CompanyHI,CompanySI,CompanySM,CompanyTotal,Total,SalaryHistoryID,UIIncome,
EmployeeUI,CompanyUI,Approval,UnionFeeEmp,UnionFeeComp,Notes,InsPaymentStatus
into #tblSal_Insurance_Forquery
  from tblSal_Insurance_Retro where @CalculateRetro = 1 and Month = @Month and Year = @Year and EmployeeID in (select EmployeeID from #tblEmployeeIDList)

insert into #tblSal_Insurance_Forquery(EmployeeID,Year,Month,HIIncome,SIIncome,EmployeeHI,EmployeeSI,
EmployeeTotal,CompanyHI,CompanySI,CompanySM,CompanyTotal,Total,SalaryHistoryID,UIIncome,
EmployeeUI,CompanyUI,Approval,UnionFeeEmp,UnionFeeComp,Notes,InsPaymentStatus)
 select EmployeeID,Year,Month,HIIncome,SIIncome,EmployeeHI,EmployeeSI,
EmployeeTotal,CompanyHI,CompanySI,CompanySM,CompanyTotal,Total,SalaryHistoryID,UIIncome,
EmployeeUI,CompanyUI,Approval,UnionFeeEmp,UnionFeeComp,Notes,InsPaymentStatus
  from tblSal_Insurance
 where Month = @Month and Year = @Year
 and EmployeeID in (select EmployeeID from #tblEmployeeIDList)
 and EmployeeID not in (select EmployeeID from #tblSal_Insurance_Forquery)


 ----bao giam thi ko dong tien cong doan thang nay
 --UPDATE #tblTradeUnion set IsComPaid = 0, IsEmpPaid = 0
 --from #tblTradeUnion u
 --where u.EmployeeID not in (select EmployeeID from #tblSal_Insurance_Forquery i where (ISNULL(i.EmployeeSI,0) <> 0 or ISNULL(i.CompanySI,0) <> 0))
 --and u.EmployeeID in (select EmployeeID from #tblEmployeeIDList e)



 UPDATE #tblTradeUnion SET IsEmpPaid = 0
 from #tblTradeUnion t
 left join #tblSaldetail ta on t.EmployeeID = ta.EmployeeID
 where (ta.EmployeeID is null or ISNULL(ta.DaysOfSalEntry,0) = 0)

 UPDATE #tblTradeUnion set BasicSalary = i.SIIncome from #tblTradeUnion u
 inner join #tblSal_Insurance_Forquery i on u.EmployeeID = i.EmployeeID
 --where i.Month = @Month and i.Year = @Year and i.EmployeeID in (select EmployeeID from #tblEmployeeIDList)

 UPDATE #tblTradeUnion set BasicSalary = s.SI_Salary
 from #tblTradeUnion u inner join
 dbo.fn_CurrentSISalary_byDate(@SIDate,@LoginID) s on u.EmployeeID = s.EmployeeID
 where u.BasicSalary is null or u.BasicSalary <=0

 declare @miniMumsal money =(
SELECT TOP 1 a.MinimumSal
 from tblSI_CeilSalary a WHERE a.EffectiveDate = (
 SELECT Max(sie.EffectiveDate) EffectiveDate FROM tblSI_CeilSalary sie WHERE sie.EffectiveDate <= @FromDate))


 UPDATE u set BaseSalaryRegional = @miniMumsal from #tblTradeUnion u -- thay đổi đóng theo lương tối thiểu
 -- inner join #tblSalDetail s on u.EmployeeID = s.EmployeeID
 --inner join dbo.fn_CurrentBaseSalRegionalByDate(@SIDate) b on s.BaseSalRegionalID = b.BaseSalRegionalID
 --where s.LatestSalEntry = 1




 -- nếu đóng theo lương cơ sở
 UPDATE #tblTradeUnion SET BasicSalary = @miniMumsal
 where Is_CeilSalary =1
 -- nếu dc chặn lại bởi 10% lương cơ sở vùng

 update #tblTradeUnion
 set UnionFeeEmp = case when isnull(Emp_ByPercent,0) =1 then UNION_PERCENT_EMP * BasicSalary/100 else UNION_PACKAGE_EMP end
 * IsEmpPaid
 , UnionFeeComp = case when isnull(Comp_ByPercent,0) =1 then UNION_PERCENT_COMP * BasicSalary/100 else UNION_PACKAGE_COMP end * IsComPaid


 UPDATE #tblTradeUnion set UnionFeeEmp = BaseSalaryRegional *MaximumByPercentsOfBaseSalaryRegional/100
 where MaximumByPercentsOfBaseSalaryRegional >0
 and UnionFeeEmp > BaseSalaryRegional * MaximumByPercentsOfBaseSalaryRegional/100


 UPDATE #tblTradeUnion SET UnionFeeEmp = ISNULL(i.UnionFeeEmp,u.UnionFeeEmp), UnionFeeComp = ISNULL(i.UnionFeeComp,u.UnionFeeComp)
 from #tblTradeUnion u
 inner join #tblSal_Insurance_Forquery i on u.EmployeeID = i.EmployeeID
 -- and i.Month = @Month and i.Year = @Year
  and (i.UnionFeeEmp is not null or i.UnionFeeComp is not null)

-- Bị chặn bởi mức max trong thiết lập công đoàn
update #tblTradeUnion set UnionFeeEmp = UNION_PACKAGE_EMP_MAX where UNION_PACKAGE_EMP_MAX > 0 and UnionFeeEmp > UNION_PACKAGE_EMP_MAX
update #tblTradeUnion set UnionFeeComp = UNION_PACKAGE_COMP_MAX where UNION_PACKAGE_COMP_MAX > 0 and UnionFeeComp > UNION_PACKAGE_COMP_MAX

 insert into #tblTradeUnion(EmployeeID, UnionFeeEmp,UnionFeeComp)
 select EmployeeID,ISNULL(UnionFeeEmp,0),ISNULL(UnionFeeComp,0)
  from #tblSal_Insurance_Forquery i where --i.Month = @Month and i.Year = @Year and
  (i.UnionFeeEmp is not null or i.UnionFeeComp is not null)
 and i.EmployeeID in (select EmployeeID from #tblEmployeeIDList)
 UPDATE sal set
  EmpUnion_RETRO = round(re.Union_RETRO_EE,0)
  ,EmpUnion = round(uni.UnionFeeEmp,0)
 ,CompUnion_RETRO = round(re.Union_RETRO_ER,0)
,CompUnion = round(uni.UnionFeeComp,0)
 from #tblSalDetail sal
 left join #tblTradeUnion uni on sal.EmployeeID = uni.EmployeeID
 left join #tblsal_retro_Final re on sal.EmployeeID = re.EmployeeID --and re.Month = @Month and re.Year = @Year
 where sal.LatestSalEntry = 1


 --------------------- Calculate IO ----------------------------------

if(OBJECT_ID('SALCAL_IO_INITIAL' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_IO_INITIAL
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20) = ''-1''
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_IO_INITIAL @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

 if @StopUPDATE = 0
 begin
  insert into #tblSal_IO_des(EmployeeID,Month,Year,InLateHours,InLateAmount,PeriodID)
  select EmployeeID,Month,Year,InLateHours,InLateAmount,@PeriodID
  from (
  insert into #tblSal_IO_Detail_des(EmployeeID,Month,Year,SalaryHistoryID,InLateHours,OutEarlyHours,InLateAmount,OutEarlyAmount,PeriodID) output inserted.*
  select sal1.EmployeeID,@Month,@Year,isnull(sal1.ProbationSalaryHistoryID,SalaryHistoryID),sal2.DeductionHours,0,sal1.IOAmt,0
  ,@PeriodID
  from #tblSalDetail sal1
  inner join #tblSal_AttendanceData sal2 on sal1.EmployeeID = sal2.EmployeeID
  where sal2.DeductionHours is not null
  ) tmp
  where tmp.InLateAmount is not null
end


 ----------------------Payroll sumaried items-----------------------------------------
 select * into #tblSalDetail_ForTax
 from #tblSalDetail where LatestSalEntry = 1 --lấy dòng lương cuối cùng chắc chắn có


 UPDATE #tblSalDetail_ForTax SET ActualMonthlyBasic = s.ActualMonthlyBasic, UnpaidLeaveAmount = s.UnpaidLeaveAmount
 ,TaxableOTTotal = s.TaxableOTTotal, NoneTaxableOTTotal = s.NoneTaxableOTTotal, TotalOTAmount = s.TotalOTAmount, TotalNSAmt = s.TotalNSAmt, NoneTaxableNSAmt = s.NoneTaxableNSAmt
 from #tblSalDetail_ForTax t inner join(

 select EmployeeID, SUM(ActualMonthlyBasic) ActualMonthlyBasic,SUM(UnpaidLeaveAmount) UnpaidLeaveAmount
 ,SUM(TaxableOTTotal) TaxableOTTotal,SUM(NoneTaxableOTTotal) NoneTaxableOTTotal, SUM(TotalOTAmount) TotalOTAmount
 ,SUM(TotalNSAmt) TotalNSAmt,  SUM(NoneTaxableNSAmt) NoneTaxableNSAmt
 from #tblSalDetail d group by EmployeeID
 ) s on t.EmployeeID = s.EmployeeID



 UPDATE #tblSalDetail_ForTax
SET GrossTakeHome = round((ActualMonthlyBasic + isnull(TotalOTAmount,0) +isnull(TotalNSAmt,0)
 + ISNULL(TotalAllowanceForSalary,0) + isnull(TotalAdjustmentForSalary,0)),@ROUND_TAKE)
 - (ISNULL(InsAmt,0)+ ISNULL(IOAmt,0) + ISNULL(EmpUnion,0))
 ,TotalCostComPaid = ActualMonthlyBasic + isnull(TotalOTAmount,0) + isnull(TotalNSAmt,0) + ISNULL(TaxableAllowanceTotal,0) + ISNULL(NoneTaxableAllowanceTotal,0)
 + ISNULL(InsAmtComp,0) - ISNULL(IOAmt,0) + ISNULL(CompUnion,0)+ isnull(CompUnion_RETRO,0)
 +case when ISNULL(IsNet,0) =1 then ISNULL(InsAmt,0) else 0 end
 update #tblSalDetail_ForTax set  TotalPayrollFund  = TotalCostComPaid

 update #tblSalDetail_ForTax  set TotalCostComPaid = ISNULL(TotalCostComPaid,0)
 + adj.AdjustmentAmount
 from #tblSalDetail_ForTax  sal
 inner join
 (
select a.EmployeeID,SUM(case when ir.IncomeKind  = 1 then  a.AdjustmentAmount else -1 * a.AdjustmentAmount end) as AdjustmentAmount
from #AdjustmentSum a
inner join tblIrregularIncome ir on a.IncomeID = ir.IncomeID and ISNULL(ir.isNotLabourCost,0) = 0
group by a.EmployeeID) adj on sal.EmployeeID = adj.EmployeeID

 update #tblSalDetail_ForTax  set TotalPayrollFund = ISNULL(TotalPayrollFund,0)
 + adj.AdjustmentAmount
 from #tblSalDetail_ForTax  sal
 inner join
 (
select a.EmployeeID,SUM(case when ir.IncomeKind  = 1 then  a.AdjustmentAmount else -1 * a.AdjustmentAmount end) as AdjustmentAmount
from #AdjustmentSum a
inner join tblIrregularIncome ir on a.IncomeID = ir.IncomeID-- and ISNULL(ir.isNotLabourCost,0) = 0
group by a.EmployeeID) adj on sal.EmployeeID = adj.EmployeeID



 --Taxable before deduct co tru luon tien bao hiem 10.5% cua nhan vien
 UPDATE #tblSalDetail_ForTax set
 TaxableIncomeBeforeDeduction = ISNULL(ActualMonthlyBasic,0)
  + ISNULL(TotalNSAmt,0) - isnull(NoneTaxableNSAmt,0) + ISNULL(TaxableAllowanceTotal,0) + ISNULL(TaxableAdjustmentTotal,0) - ISNULL(IOAmt,0) + ISNULL(TaxableOTTotal,0) - ISNULL(InsAmt,0)

 , TotalIncome_Taxable_Without_INS_Persion_family = ISNULL(ActualMonthlyBasic,0)
 + ISNULL(TotalNSAmt,0) - isnull(NoneTaxableNSAmt,0) + ISNULL(TaxableAllowanceTotal,0) + ISNULL(TaxableAdjustmentTotal,0) - ISNULL(IOAmt,0) + ISNULL(TaxableOTTotal,0)




 update #tblSalDetail_ForTax set TaxableIncomeBeforeDeduction = TaxableIncomeBeforeDeduction+ ISNULL(InsAmt,0)
 where IsNet =1

 -- nếu muốn cộng insurance vào nếu 10%
 update #tblSalDetail_ForTax set TaxableIncomeBeforeDeduction = TaxableIncomeBeforeDeduction+ ISNULL(InsAmt,0)
 from #tblSalDetail_ForTax t
 inner join #tblEmployeeIDList e on t.EmployeeId = e.EmployeeID
 --inner join tblDivision div on e.DivisionId = div.DivisionID and div.Add_EE_Insurance_Into_TaxableIncome = 1
 where isnull(t.IsNet,0) =0 and t.employeeID in(select employeeId from #tblTemporaryContractTax)




 -- cộng INS vào làm tổng lương trước khi trừ deduction
 -- trừ các khoảng thuế gross ra
 -- + với net từ nước ngoài
 -- gross up nó
 -- + lại allowance gross
 -- + insurance + gross từ nước ngoài

   -- tính toán lại tổng số lương trước khi nhảy qua đoạn thu
   --select 9999,* from tblSal_Abroad_ForTaxPurpose
   -- lấy danh sách allowance Gross ra trừ đi trước khi grossup
   -- có thể net hóa nó nhưng mà khó lém
   truncate table #grossAllowanceAmount
   insert into #grossAllowanceAmount
   select EmployeeID,sum(TaxableAmount) as TotalGrossAllowanceAmount_Taxable
   from #tblAllowance a
   inner join tblAllowanceSetting al on a.AllowanceCode = al.AllowanceCode
   where al.IsTaxable = 1 and al.IsGrossAllowance_InNetSal = 1
   group by EmployeeID

   if @@ROWCOUNT >0 -- nếu có gross allowance thì phải trừ đi rồi mới gross up
   begin
    update #tblSalDetail_ForTax
    set TaxableIncomeBeforeDeduction = TaxableIncomeBeforeDeduction - isnull(gross.TotalGrossAllowanceAmount_Taxable,0)
    from #tblSalDetail_ForTax sal
    inner join #grossAllowanceAmount gross
    on sal.EmployeeID =gross.EmployeeID and sal.LatestSalEntry =1
    where sal.IsNet= 1
   end

    -- cộng cục này với phần Net từ nước ngoài trả
    update #tblSalDetail_ForTax set TaxableIncomeBeforeDeduction += ISNULL(ca.NetAmountVND,0) -- cộng phần net để grossup trước
    from #tblSalDetail_ForTax sal
    cross apply(select sum(NetAmountVND) as NetAmountVND
    from #tblSal_Abroad_ForTaxPurpose_des sa
    where sa.Month=@Month and sa.Year= @Year and sa.EmployeeID = sal.EmployeeID) ca
    where sal.LatestSalEntry = 1 and sal.IsNet = 1

   --gross it up
   ----update dependant truocws nhes

   --select TaxableIncomeBeforeDeduction,-- tính before tax coi có ngon chưa nào
   update sal set TaxableIncomeBeforeDeduction =
   round((IncomeFrom-1)+ -- lấy khoản Income from
   ((TaxableIncomeBeforeDeduction -(MinNet + @PesonalDeduct +(isnull(c.CountDeduct,0)*@RelationDeduct) ))/(1-TaxPercent)) -- cộng với công thức ba lăng nhăng
   + @PesonalDeduct +(isnull(c.CountDeduct,0)*@RelationDeduct) -- cộng với giảm trừ bản thân, gia đình, tới đây còn thiếu cái tiền bảo hiểm tý mới cộng
    --as TaxableIncomeBeforeDeduction_GrossedUp
   --,MinNet
   --,*
   ,0,1)
   from #tblSalDetail_ForTax sal
   left join #CountRelation c on sal.EmployeeID = c.EmployeeID

   inner join #TaxForGrossup tg on sal.TaxableIncomeBeforeDeduction -- đổi với những người lương NET thì cái này được hiểu là tổng lương net Nhé anh em
    - @PesonalDeduct -(isnull(c.CountDeduct,0)*@RelationDeduct) between tg.MinNet and tg.MaxNet
   where IsNet = 1


    -- lấy cái net của cty ra trước khi cộng gross - ee trả thuế vào
  update #tblSalDetail_ForTax set TaxableIncomeBeforeDeduction_EROnly_ForNETOnly = TaxableIncomeBeforeDeduction where IsNet= 1


   if exists(select 1 from #grossAllowanceAmount)-- nếu có gross allowance thì cộng vào lại chứ ko vỡ mồm
   begin
    update #tblSalDetail_ForTax
    set TaxableIncomeBeforeDeduction = TaxableIncomeBeforeDeduction
    + isnull(gross.TotalGrossAllowanceAmount_Taxable,0)
    from #tblSalDetail_ForTax sal
    inner join #grossAllowanceAmount gross on sal.EmployeeID =gross.EmployeeID
    where sal.IsNet= 1 and sal.LatestSalEntry =1
   end



    -------------------------Calculate Employee insurance --------------------------------

   --select si.EmployeeTotal,TaxableIncomeBeforeDeduction,TaxableIncomeBeforeDeduction*0.15,*

   update sal set TotalIncome_Taxable_Without_INS_Persion_family = TaxableIncomeBeforeDeduction + isnull(si.EmployeeTotal,0)
   from #tblSalDetail_ForTax sal
left join tblSal_Insurance si on sal.EmployeeID = si.EmployeeID and si.Month= @Month and si.Year = @Year
   where sal.LatestSalEntry = 1 and IsNet= 1


   -- cộng thêm lương gross từ nước ngoài
   update sal set TaxableIncomeBeforeDeduction = TaxableIncomeBeforeDeduction + isnull(ca.GrossAmountVND,0)
   from #tblSalDetail_ForTax sal
   cross apply(select sum(GrossAmountVND) as GrossAmountVND
    from #tblSal_Abroad_ForTaxPurpose_des sa
    where sa.Month=@Month and sa.Year= @Year and sa.EmployeeID = sal.EmployeeID) ca
   where sal.LatestSalEntry = 1
   and sal.IsNet= 1
    -- kết thúc gross up




 UPDATE #tblSalDetail_ForTax
 set TotalIncome = round(isnull(ActualMonthlyBasic,0) + isnull(TotalOTAmount,0)+ isnull(TotalNSAmt,0)
 + ISNULL(TotalAllowanceForSalary,0) + isnull(TotalAdjustmentForSalary,0) + isnull(OtherDeductionAfterPIT,0)
 - ISNULL(IOAmt,0),@ROUND_NET)
 , TaxableIncome = TaxableIncomeBeforeDeduction
 , TaxableIncome_EROnly_ForNETOnly = TaxableIncomeBeforeDeduction_EROnly_ForNETOnly
 ,TotalIncome_ForSalaryTaxedAdj = round(isnull(ActualMonthlyBasic,0) + isnull(TotalOTAmount,0) + isnull(TotalNSAmt,0) + ISNULL(TotalAllowanceForSalary,0) + isnull(TaxableAdjustmentTotal_ForSalary,0)-ISNULL(IOAmt,0),@ROUND_NET)


 UPDATE #tblSalDetail_ForTax set TotalEarn = isnull(ActualMonthlyBasic,0) + isnull(TotalOTAmount,0) + isnull(TotalNSAmt,0) + ISNULL(TotalAllowanceForSalary,0)



 update #tblSalDetail_ForTax set TotalEarn = ISNULL(TotalEarn,0) + t.AdjustmentAmount

 from #tblSalDetail_ForTax tx inner join (
 select a.EmployeeID, SUM(a.AdjustmentAmount) AdjustmentAmount from #tblAdjustment a
 inner join tblIrregularIncome ir on a.IncomeID = ir.IncomeID and ir.IncomeKind = 1 and ir.ForSalary = 1
 and (ISNULL(DoNotAddToTotalEarnIfNegative,0) = 0 or AdjustmentAmount>0)
 group by A.EmployeeID
 ) t on tx.EmployeeID = t.EmployeeID



-- select 7878787878 as asdasdsa,EmployeeID
-- ,sum(case when i.incomeKind = 1 then 1 else 0 end * a.AdjustmentAmount) as TotalDeductFromTotalEarnCauseOfNegativeAmount
--from #AdjustmentSum a
--inner join tblIrregularIncome i on a.IncomeID = i.IncomeID  and i.DoNotAddToTotalEarnIfNegative =1
--group by a.EmployeeID

 -------------------------------------Calculate tax----------------------------------------------

if(OBJECT_ID('SALCAL_TAX_INITIAL' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_TAX_INITIAL
(
 @StopUPDATE bit output,
 @Month int, @Year int,

 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20) = ''-1''
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_TAX_INITIAL @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

--tinh thue 10% thi khong duoc mien thue tang ca


select EMployeeId into #empNeedToFixTaxAmount
from #tblTemporaryContractTax c



UPDATE #tblSalDetail_ForTax
SET TaxableIncomeBeforeDeduction =
TaxableIncomeBeforeDeduction - ISNULL(TaxableOTTotal,0) + ISNULL(TotalOTAmount,0)
 -ISNULL(TaxableAdjustmentTotal,0) + ISNULL(TotalAdjustment_WithoutForce,0)
 -ISNULL(TaxableAllowanceTotal,0) + ISNULL(TotalAllowanceForSalary,0)
 ,TotalIncome_Taxable_Without_INS_Persion_family
  = TotalIncome_Taxable_Without_INS_Persion_family- ISNULL(TaxableOTTotal,0) + ISNULL(TotalOTAmount,0)
 -ISNULL(TaxableAdjustmentTotal,0) + ISNULL(TotalAdjustment_WithoutForce,0)
 -ISNULL(TaxableAllowanceTotal,0) + ISNULL(TotalAllowanceForSalary,0)
from #tblSalDetail_ForTax s
where EmployeeID in(select EmployeeID from #empNeedToFixTaxAmount)




-- ở đây sẽ xử lý hết mấy thằng OT, Allowance, Adjustment
 update #tblSal_OT_des set
 Raw_TaxableOTAmount = TaxableOTAmount
 ,Raw_NoneTaxableOTAmount =  NoneTaxableOTAmount

 update #tblSal_OT_des
 set
  TaxableOTAmount =OTAmount
  ,NoneTaxableOTAmount = 0
 where EmployeeID in(select EmployeeID from #empNeedToFixTaxAmount)



 update #tblSal_Allowance_des set
 Raw_TaxableAmount = TaxableAmount
 ,Raw_UntaxableAmount = UntaxableAmount
 ,Raw_RetroAmountNonTax= RetroAmountNonTax
 update #tblSal_Allowance_des
 set
  TaxableAmount =Amount
  ,UntaxableAmount = 0
  ,RetroAmountNonTax = 0
 where EmployeeID in(select EmployeeID from #empNeedToFixTaxAmount)

  update #tblSal_Allowance_Detail_des set
 Raw_TaxableAmount = TaxableAmount
 ,Raw_UntaxableAmount = UntaxableAmount
 ,Raw_RetroAmountNonTax= RetroAmountNonTax

 update #tblSal_Allowance_Detail_des
 set
  TaxableAmount =Amount
  ,UntaxableAmount = 0
  ,RetroAmountNonTax = 0
 where EmployeeID in(select EmployeeID from #empNeedToFixTaxAmount)

 update #tblSal_Adjustment_des
 set Raw_TaxableAmount = TaxableAmount,Raw_UntaxableAmount = UntaxableAmount

 update #tblSal_Adjustment_des
 set
  TaxableAmount =Amount
  ,UntaxableAmount = 0
 where EmployeeID in(select EmployeeID from #empNeedToFixTaxAmount)
 and IncomeID not in(select IncomeID from tblIrregularIncome where ForceNonTax =1)
 and IncomeID in (select IncomeID from tblIrregularIncome where IncomeKind =1)

drop table #empNeedToFixTaxAmount


if(OBJECT_ID('SALCAL_TAX_10_INITIAL' )is null)
begin
exec('CREATE PROCEDURE dbo.SALCAL_TAX_10_INITIAL
(
 @StopUPDATE bit output,

 @Month int, @Year int,

 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20) = ''-1''
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
-- custom
exec SALCAL_TAX_10_INITIAL @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID


-- TAX_DEDUCTION: Khấu trừ thuế khi tính lương? 0: không trừ, 1: có trừ tiền thuế
-- không tính thuế từ phần mềm, có thể import từ bên ngoài vào
DECLARE @TAX_DEDUCTION bit
SET @TAX_DEDUCTION = ISNULL((select Value from tblParameter where Code = 'TAX_DEDUCTION'),1) --mot vai cong ty khong tinh thue ma import tu file - nếu từ file thì phải set = 0

if @TAX_DEDUCTION = 1

begin
 create table #TableVarTax (
  EmployeeID varchar(20)
  ,TaxableIncome float(53)
  ,TaxableIncome_EROnly_ForNETOnly float(53)
  ,TaxableIncomeFrom float(53)
  ,TaxableIncomeFrom_EROnly_ForNETOnly float(53)
  ,TaxableIncomeTo float(53)
  ,TaxableIncomeTo_EROnly_ForNETOnly float(53)
  ,TaxPercent float
  ,TaxPercent_EROnly_ForNETOnly float
  ,ProgressiveAmount float(53)
  ,ProgressiveAmount_EROnly_ForNETOnly float(53)
  ,PITAmt float(53)
  ,PITAmt_ER float(53)
  ,SalaryHistoryID BIGINT
  ,FixedPercent bit
  ,IncomeTaxableEmployeeOld float(53)
  ,TaxRetroImported float(53)
 )

 select te.EmployeeID, te.TaxRegNo into #tmpEmpTaxNo from tblEmployee te inner join #tblEmployeeIDList a on te.EmployeeID = a.EmployeeID

 -- Family deduction

 select EmployeeID, cast(0.0 as float(53)) as DeductionAmount
 , cast(@PesonalDeduct as float(53)) PesonalDeduct
 , CAST(0 as float(53)) FamilyDeduction
 into #Deduction
 from #tblEmployeeIDList

 UPDATE #Deduction SET DeductionAmount = ISNULL(PesonalDeduct,@PesonalDeduct)

 UPDATE #Deduction
 set DeductionAmount = DeductionAmount + @RelationDeduct * isnull(CountDeduct,0)
 ,FamilyDeduction = @RelationDeduct * isnull(CountDeduct,0)
 from #Deduction a
 inner join #CountRelation b on a.EmployeeID = b.EmployeeID





 update #CountRelation set CountDeduct = 0
 where EmployeeID in(select EmployeeID from #tblTemporaryContractTax)

 update #Deduction set DeductionAmount = 0 ,FamilyDeduction =0 ,PesonalDeduct =0
 where EmployeeID in(select EmployeeID from #tblTemporaryContractTax)


 UPDATE #tblSalDetail_ForTax
 set
 TaxableIncome = TaxableIncome - (DeductionAmount)
 ,TaxableIncome_EROnly_ForNETOnly = TaxableIncome_EROnly_ForNETOnly - (DeductionAmount)
 from #tblSalDetail_ForTax a
 inner join #Deduction b on a.EmployeeID = b.EmployeeID
 --nhung nguoi hd duoi 3 thang ko duoc huong tang ca mien thue, neu luong < 9tr va co tich lowincome va co ma so thue thi duoc giam tru OTnontax




 INSERT INTO #TableVarTax(EmployeeID,TaxableIncome,TaxableIncome_EROnly_ForNETOnly)
 SELECT EmployeeID,TaxableIncome,TaxableIncome_EROnly_ForNETOnly
  FROM #tblSalDetail_ForTax


  declare @EffectDate date
 SELECT @EffectDate = MAX(EffectDate) FROM tblTax where EffectDate < @ToDate

 UPDATE #TableVarTax
 SET TaxableIncomeFrom = tx.IncomeFrom

  ,TaxableIncomeTo = tx.IncomeTo
  ,TaxPercent = tx.TaxPercent
  ,ProgressiveAmount = tx.ProgressiveAmount
 FROM #TableVarTax txv, (SELECT * FROM tblTax tt WHERE tt.EffectDate = @EffectDate) tx
 WHERE txv.TaxableIncome BETWEEN tx.IncomeFrom AND tx.IncomeTo



 UPDATE #TableVarTax
 SET TaxableIncomeFrom_EROnly_ForNETOnly = tx.IncomeFrom
  ,TaxableIncomeTo_EROnly_ForNETOnly = tx.IncomeTo
  ,TaxPercent_EROnly_ForNETOnly = tx.TaxPercent
  ,ProgressiveAmount_EROnly_ForNETOnly = tx.ProgressiveAmount
 FROM #TableVarTax txv, (SELECT * FROM tblTax tt WHERE tt.EffectDate = @EffectDate) tx
 WHERE txv.TaxableIncome_EROnly_ForNETOnly BETWEEN tx.IncomeFrom AND tx.IncomeTo


 UPDATE #TableVarTax SET
  TaxableIncomeFrom = ISNULL(TaxableIncomeFrom,0)
  ,TaxableIncomeTo = ISNULL(TaxableIncomeTo,0)
  ,TaxPercent = ISNULL(TaxPercent,0)


  ,ProgressiveAmount = ISNULL(ProgressiveAmount,0)

  ,TaxableIncomeFrom_EROnly_ForNETOnly = ISNULL(TaxableIncomeFrom_EROnly_ForNETOnly,0)
  ,TaxableIncomeTo_EROnly_ForNETOnly = ISNULL(TaxableIncomeTo_EROnly_ForNETOnly,0)
  ,TaxPercent_EROnly_ForNETOnly = ISNULL(TaxPercent_EROnly_ForNETOnly,0)
  ,ProgressiveAmount_EROnly_ForNETOnly = ISNULL(ProgressiveAmount_EROnly_ForNETOnly,0)



 UPDATE #TableVarTax
 SET
  PITAmt = (TaxableIncome - (TaxableIncomeFrom - 1)) * TaxPercent + ProgressiveAmount
,PITAmt_ER = (TaxableIncome_EROnly_ForNETOnly - (TaxableIncomeFrom_EROnly_ForNETOnly - 1)) * TaxPercent_EROnly_ForNETOnly + ProgressiveAmount_EROnly_ForNETOnly
 FROM #TableVarTax a
 where EmployeeID not in (select EmployeeID from #tblTemporaryContractTax)


 -- thuế cho người chưa có hợp đồng chính thức, mac dinh 10%
 UPDATE #TableVarTax
 SET TaxableIncome =
 case when  ISNULL(sal.TaxableIncomeBeforeDeduction,0) < 0 and e.DivisionID is null then 0
  else  ISNULL(sal.TaxableIncomeBeforeDeduction,0) end
 , PITAmt = case when  ISNULL(sal.TaxableIncomeBeforeDeduction,0) < 2000000 then 0 else  ISNULL(sal.TaxableIncomeBeforeDeduction,0)*tmp.TaxPercentage end
 , FixedPercent = 1
 FROM #TableVarTax a
 inner join #tblTemporaryContractTax tmp on a.EmployeeID = tmp.EmployeeID
 left join #tblEmployeeIDList e on a.EmployeeID = e.EmployeeId
  --and e.DivisionID in(select DivisionID from tblDivision where DoNotFixTaxableIncome = 1)
 inner join #tblSalDetail_ForTax sal on a.EmployeeID = sal.EmployeeID


 UPDATE #TableVarTax SET PITAmt = 0, TaxableIncome = 0, FixedPercent = 0 WHERE PITAmt <= 0.05
 --co ma so thue + cam ket thu nhap thap + < 9tr: khong tinh thue nhung duoc tru tang ca mien thue, dong phuc mien thue, tien an mien thue



 UPDATE #TableVarTax SET
  PITAmt = CASE
 WHEN LTRIM(RTRIM(ISNULL(te.TaxRegNo,''))) <> '' and tmp.IsLowSalary = 1 AND sal.TotalSalary <= @PesonalDeduct THEN 0
 ELSE t.PITAmt END
 ,TaxableIncome = CASE
 WHEN LTRIM(RTRIM(ISNULL(te.TaxRegNo,''))) <> '' and tmp.IsLowSalary = 1 AND sal.TotalSalary <= @PesonalDeduct THEN 0
 ELSE t.TaxableIncome END
 from #TableVarTax t
 inner join #tblTemporaryContractTax tmp on t.EmployeeID = tmp.EmployeeID
 inner join #tblSalDetail_ForTax sal on t.EmployeeID = sal.EmployeeID
 inner join #tmpEmpTaxNo te on t.EmployeeID = te.EmployeeID


 UPDATE #TableVarTax SET SalaryHistoryID = b.SalaryHistoryID FROM #TableVarTax a,
  (SELECT MAX(SalaryHistoryID) SalaryHistoryID , EmployeeID from #tblSalDetail_ForTax GROUP BY EmployeeID) b WHERE a.EmployeeID = b.EmployeeID

 UPDATE #TableVarTax set TaxableIncome = 0 where TaxableIncome < 0 or TaxableIncome is null

 UPDATE #TableVarTax set TaxableIncome_EROnly_ForNETOnly = 0 where TaxableIncome_EROnly_ForNETOnly < 0 or TaxableIncome_EROnly_ForNETOnly is null

 UPDATE #TableVarTax SET
 TaxableIncome = ROUND(TaxableIncome,@ROUND_SALARY_UNIT), PITAmt = ROUND(PITAmt,@ROUND_SALARY_UNIT)
 --UPDATE #Sal_OT1_0 SET OTDeduction = OTDeduction

 UPDATE #TableVarTax SET FixedPercent = 0 WHERE PITAmt <= 0.05

 update #TableVarTax set
 TaxRetroImported = pit.totalPITRetro
 , PITAmt= round(ISNULL(PITAmt,0) +ISNULL(pit.totalPITRetro,0),0) from #TableVarTax tax
 inner join
 (
  select EmployeeID,SUM(Amount) as totalPITRetro
  from tblPR_Adjustment p
  where p.EmployeeID in(select EmployeeID from #tblEmployeeIDList)
  and p.Month = @Month and p.Year = @Year
  and p.IncomeID in(select IncomeID from tblIrregularIncome where AppendToPIT =1)
  group by p.EmployeeID
 ) pit on tax.EmployeeID = pit.EmployeeID

 update #TableVarTax set TaxRetroImported = isnull(TaxRetroImported,0) + isnull(re.PIT_Retro_Amount,0)
  ,PITAmt= round(ISNULL(PITAmt,0) +ISNULL( re.PIT_Retro_Amount,0),0)
  from #TableVarTax tax
  inner join tblSal_Retro_Imported re on tax.EmployeeID = re.EmployeeID and re.Month = @month and re.YEar = @year
  and re.PIT_Retro_Amount <>0
update #TableVarTax set PITAmt = ROUND(PITAmt,0),PITAmt_ER=ROUND(PITAmt_ER,0)


-- calculate PIT retro by cal back dependants
exec sp_ProcessDependentAdjustment @LoginID,@Month,@Year,@NotSelect=1

update #TableVarTax set PITAmt = case when Round( ISNULL(PITAmt,0) + a.PITAdjustment ,@ROUND_SALARY_UNIT) < 0 then 0 else Round( ISNULL(PITAmt,0) + a.PITAdjustment ,@ROUND_SALARY_UNIT) end
from #TableVarTax p
inner join

(
select EmployeeId,sum(PITAdjustment) as PITAdjustment
from tblPIT_Adjustment_For_ChangedDependants
where ToMonth = @month and ToYear= @year
group by EmployeeID
) a on p.EmployeeID = a.EmployeeID


-- end calculate PIT retro by cal back dependants


if(OBJECT_ID('SALCAL_TAX_FINISHED' )is null)
begin
 exec('CREATE PROCEDURE dbo.SALCAL_TAX_FINISHED
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20) = ''-1''
)
as
begin
 SET NOCOUNT ON;
end')
end
set @StopUPDATE = 0
exec SALCAL_TAX_FINISHED @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID

 --alter table tblSal_tax add FixedPercents float

 insert into #tblSal_tax_des
 (
 EmployeeID,Month,year,
 IncomeTaxable,DeductionAmt,
 EmployeeExemption,FamilyExemption,DependantNumber,OTDeduction,
 TaxAmt, IsNET
 ,TaxableIncome_EROnly_ForNETOnly,PITAmt_ER
 ,TaxRetroImported
 ,FixedPercents
 ,isLowSalary
 ,PeriodID
 )
 select
 tx.EmployeeID,@Month,@Year,
 tx.TaxableIncome,d.DeductionAmount,
 d.PesonalDeduct,isnull(dp.CountDeduct,0) * isnull(@RelationDeduct,0) ,dp.CountDeduct,sal.NoneTaxableOTTotal,
 tx.PITAmt, sh.IsNET
 ,tx.TaxableIncome_EROnly_ForNETOnly,tx.PITAmt_ER
 ,TaxRetroImported
 ,tc.TaxPercentage as FixedPercents
 ,tc.isLowSalary
 ,@PeriodID
 from #TableVarTax tx
 inner join #tblSalDetail_ForTax sal on tx.SalaryHistoryID = sal.SalaryHistoryID and sal.LatestSalEntry =1
 left join tblSalaryHistory sh on tx.SalaryHistoryID = sh.SalaryHistoryID
 left join #Deduction d on tx.EmployeeID = d.EmployeeID
 left join #CountRelation dp on tx.EmployeeID = dp.EmployeeID
 left join #tblTemporaryContractTax tc on tx.EmployeeID = tc.EmployeeID



 UPDATE #tblSalDetail_ForTax
 set
 PITAmt = tx.PITAmt
 ,PITAmt_ER = tx.PITAmt_ER
 from #tblSalDetail_ForTax sal
 inner join #TableVarTax tx on sal.EmployeeID = tx.EmployeeID and sal.LatestSalEntry = 1



end
else
begin
 delete #tblSal_tax_des where month = @Month and Year = @Year and EmployeeID in (select EmployeeID from #tblEmployeeIDList)
 select t.EmployeeID,t.IncomeTaxable,t.TaxAmt
 into #tblSal_TaxImport
 from tblSal_TaxImport t where Month = @Month and Year = @Year and EmployeeID in (select EmployeeID from #tblEmployeeIDList)
 insert into #tblSal_tax_des(EmployeeID,Month,Year,IncomeTaxable,TaxAmt)
 select t.EmployeeID,@Month,@Year,t.IncomeTaxable,t.TaxAmt from #tblSal_TaxImport t

 UPDATE #tblSalDetail_ForTax set PITAmt = tx.TaxAmt from #tblSalDetail_ForTax sal
 inner join #tblSal_TaxImport tx on sal.EmployeeID = tx.EmployeeID and sal.LatestSalEntry = 1
end
--------------------------UPDATE other sumaried items of Sumary Table--------------------------


 UPDATE #tblSalDetail_ForTax set IncomeAfterPIT = TotalIncome - ISNULL(InsAmt,0)-ISNULL(PITAmt,0)-(ISNULL(EmpUnion,0) + ISNULL(EmpUnion_RETRO,0))
 where isnull(IsNet,0)=0
 UPDATE #tblSalDetail_ForTax set IncomeAfterPIT = TotalIncome -(ISNULL(PITAmt,0) - isnull(PITAmt_ER,0))
 where isnull(IsNet,0)=1



 --UPDATE #tblSalDetail_ForTax set PITReturn = ISNULL(TaxableAdjustmentTotal,0) + ISNULL(NoneTaxableAdjustmentTotal,0) - ISNULL(TotalAdjustmentForSalary,0)

--deduct advance and union
 UPDATE sal set AdvanceAmt = av.AdvanceAmount
 from tblSal_Advance av
 inner join #tblSalDetail_ForTax sal on av.EmployeeID = sal.EmployeeID and sal.LatestSalEntry = 1
 where av.Month = @Month and av.Year = @Year and av.IsLock = 1




 UPDATE #tblSalDetail_ForTax
 set GrossTakeHome = ROUND(IncomeAfterPIT - ISNULL(OtherDeductionAfterPIT,0) - ISNULL(PITReturn,0) - ISNULL(AdvanceAmt,0) ,@ROUND_SALARY_UNIT)
 where IncomeAfterPIT<>0



 --select GrossTakeHome,@ROUND_SALARY_UNIT from #tblSalDetail_ForTax
-- total cost thì phải trừ các khoản không dc tính trong total Cót Com Paid
-- use IsNotLabourCost column
update sal

 set sal.TotalCostComPaid
  = sal.TotalCostComPaid - isnull(al.Total_Allowance_NotInLabourCost,0)
  from #tblSalDetail_ForTax sal
 inner join
 (
 select employeeID,sum(ReceiveAmount) as Total_Allowance_NotInLabourCost
 from #tblAllowance a
 inner join tblAllowanceSetting al on a.AllowanceID = al.AllowanceID and al.IsNotLabourCost = 1
 group by EmployeeID
 ) al on sal.EmployeeID = al.EmployeeID
 where sal.LatestSalEntry =1





 -----------------------UPDATE salary detail records-----------------------------
 --already delete old data
UPDATE #tblSalDetail SET GrossTakeHome = sal2.GrossTakeHome
,TotalCostComPaid= sal2.TotalCostComPaid
+ case when isnull(sal2.IsNet,0) =1 then
    isnull(sal2.PITAmt_ER,0) else 0 end -- nếu là net thì phải trả thêm nha
,TotalPayrollFund = sal2.TotalPayrollFund + case when isnull(sal2.IsNet,0) =1 then
    isnull(sal2.PITAmt_ER,0) else 0 end -- nếu là net thì phải trả thêm nha
,TaxableIncomeBeforeDeduction = sal2.TaxableIncomeBeforeDeduction
,TaxableIncomeBeforeDeduction_EROnly_ForNETOnly = sal2.TaxableIncomeBeforeDeduction_EROnly_ForNETOnly
,TotalIncome= sal2.TotalIncome
,TotalEarn= sal2.TotalEarn
,TaxableIncome= sal2.TaxableIncome
,TaxableIncome_EROnly_ForNETOnly= sal2.TaxableIncome_EROnly_ForNETOnly
,PITAmt= sal2.PITAmt
,PITAmt_ER= sal2.PITAmt_ER
,IncomeAfterPIT= sal2.IncomeAfterPIT
,PITReturn= sal2.PITReturn
,AdvanceAmt= sal2.AdvanceAmt
,TotalIncome_ForSalaryTaxedAdj = sal2.TotalIncome_ForSalaryTaxedAdj
,TotalIncome_Taxable_Without_INS_Persion_family = sal2.TotalIncome_Taxable_Without_INS_Persion_family
from #tblSalDetail sal1
inner join #tblSalDetail_ForTax sal2 on sal1.EmployeeID = sal2.EmployeeID and sal1.LatestSalEntry = 1



drop table #tblSalDetail_ForTax


UPDATE #tblSalDetail SET GrossTakeHome = ROUND(GrossTakeHome,@ROUND_TAKE)
,TotalEarn = ROUND(TotalEarn,@ROUND_NET),TotalIncome = ROUND(TotalIncome,@ROUND_NET)

if @PROBATION_PERECNT > 0 and @PROBATION_PERECNT < 100.0 --xu ly mot vai nguoi co probation tu dong
 UPDATE #tblSalDetail SET BasicSalaryOrg = BasicSalary where LatestSalEntry = 0 and BasicSalaryOrg is not null

--xoa mot so du lieu thua o lan tinh luong truoc
delete from #tblSalDetail where EmployeeID in (select EmployeeID from #tblEmployeeIDList where TerminatedStaff = 1 and TerminateDate <= @FromDate)
 and GrossTakeHome = 0 and ISNULL(TotalIncome,0) = 0 and ISNULL(PITAmt,0) = 0 and ISNULL(TotalCostComPaid,0) = 0



--luu du lieu truoc khi delete
select EmployeeID,IsCash,RemainAL,Notes into #tmpSalSal_Backup
from tblSal_Sal WHERE [Month]=@Month AND [Year]=@Year AND EmployeeID IN (SELECT EmployeeID FROM #tblEmployeeIDList)

update #tblSalDetail set ActualMonthlyBasic = ISNULL(ActualMonthlyBasic,0)
- isnull(sr.ActualMonthlyBasic_Retro_Amount,0)
from #tblSalDetail  sal
inner join #tblsal_retro_Final sr on sal.EmployeeID = sr.EmployeeID --and sr.Month= @Month and sr.Year= @Year
where sal.LatestSalEntry = 1

 insert into #tblSal_Sal_Detail_des(EmployeeID,Month,Year,PeriodID,SalaryHistoryID,FromDate,ToDate,
DepartmentID,SectionID,PositionID,StandardWDays,BasicSalary,
SalaryPerDay,ActualMonthlyBasic,TaxableAllowance,NontaxableAllowance
,TaxableAdjustment,NontaxableAdj
,TaxableAdjustmentTotal_ForSalary,TaxableAdjustmentTotal_NotForSalary,TotalIncome,TotalEarn,
IOAmt,EmpUnion,CompUnion,TaxableIncomeBeforeDeduction,IncomeAfterPIT,GrossTakeHome,SalaryPerHour,
SalCalRuleID,LatestSalEntry,DaysOfSalEntry
,Raw_BasicSalary,Raw_CurrencyCode,Raw_ExchangeRate,IsNet,UnpaidLeaveAmount
,TotalNetIncome_Custom,GrossedUpWithoutHousing_Custom
,GrossedUpWithoutHousing_WithoutGrossIncome_Custom
)
select sal.EmployeeID,@Month,@Year,@PeriodID,ISNULL(sal.ProbationSalaryHistoryID,sal.SalaryHistoryID) ,sal.FromDate,sal.ToDate,
e.DepartmentID,e.SectionID,e.PositionID,sal.STD_WD,sal.BasicSalaryOrg,
sal.SalaryPerDay,sal.ActualMonthlyBasic,sal.TaxableAllowanceTotal,sal.NoneTaxableAllowanceTotal
,sal.TaxableAdjustmentTotal,sal.NoneTaxableAdjustmentTotal,TaxableAdjustmentTotal_ForSalary,TaxableAdjustmentTotal_NotForSalary,sal.TotalIncome,TotalEarn,

sal.IOAmt,sal.EmpUnion,sal.CompUnion,sal.TaxableIncomeBeforeDeduction,sal.IncomeAfterPIT,sal.GrossTakeHome,sal.SalaryPerHour,
sal.SalCalRuleID,LatestSalEntry,DaysOfSalEntry
,sh.Salary as Raw_BasicSalary
,sal.CurrencyCode as Raw_CurrencyCode
,sal.ExchangeRate as Raw_ExchangeRate,sal.IsNet,UnpaidLeaveAmount
,TotalNetIncome_Custom,GrossedUpWithoutHousing_Custom
,round(GrossedUpWithoutHousing_WithoutGrossIncome_Custom,0)
from #tblSalDetail sal
inner join #tblEmployeeIDList e on sal.EmployeeID = e.EmployeeID
inner join tblSalaryHistory sh on sal.SalaryHistoryID = sh.SalaryHistoryID


--select 9999,TotalNetIncome_Custom,GrossedUpWithoutHousing_Custom,* from #tblSalDetail
if(OBJECT_ID('SALCAL_FinishUpdateSalDetail' )is null)
 begin
 exec('CREATE PROCEDURE dbo.SALCAL_FinishUpdateSalDetail
(
 @StopUPDATE bit output,
 @Month int,
 @Year int,
 @FromDate datetime,
 @ToDate datetime,
 @LoginID int,
 @PeriodID int = 0,
 @EmployeeID nvarchar(20)
)
as
begin
 SET NOCOUNT ON;
end')
 end
 set @StopUPDATE = 0
 exec SALCAL_FinishUpdateSalDetail @StopUPDATE output, @Month,@Year, @FromDate ,@ToDate ,@LoginID,@PeriodID,@EmployeeID
 ----------------------------UPDATE Salary sumary record-----------------------------
 --already delete old data
 INSERT INTO #tblSal_Sal_des(EmployeeID,Month,Year,PeriodID,ActualMonthlyBasic ,TaxableAllowance,NontaxableAllowance,
TaxableAdjustment,NontaxableAdj
,TaxableAdjustmentTotal_ForSalary,TaxableAdjustmentTotal_NotForSalary
,TotalIncome,TotalEarn,IOAmt,EmpUnion,CompUnion,EmpUnion_RETRO,CompUnion_RETRO,TaxableIncomeBeforeDeduction,
IncomeAfterPIT,GrossTakeHome,TotalCostComPaid,TotalPayrollFund
,TotalIncome_ForSalaryTaxedAdj,TotalIncome_Taxable_Without_INS_Persion_family,UnpaidLeaveAmount
,TotalNetIncome_Custom,GrossedUpWithoutHousing_Custom
,GrossedUpWithoutHousing_WithoutGrossIncome_Custom
)
 SELECT EmployeeID,@Month,@Year,@PeriodID,SUM(ActualMonthlyBasic)
 ,SUM(TaxableAllowanceTotal),SUM(NoneTaxableAllowanceTotal)
 ,SUM(TaxableAdjustmentTotal)
 ,SUM(NoneTaxableAdjustmentTotal)
 ,SUM(TaxableAdjustmentTotal_ForSalary),SUM(TaxableAdjustmentTotal_NotForSalary)
 ,SUM(TotalIncome),SUM(TotalEarn),SUM(IOAmt),SUM(EmpUnion),SUM(CompUnion),SUM(EmpUnion_RETRO),SUM(CompUnion_RETRO),SUM(TaxableIncomeBeforeDeduction),
SUM(IncomeAfterPIT),SUM(GrossTakeHome),Round(SUM(TotalCostComPaid),@ROUND_SALARY_UNIT),Round(SUM(TotalPayrollFund),@ROUND_SALARY_UNIT)
,SUM(TotalIncome_ForSalaryTaxedAdj),SUM(TotalIncome_Taxable_Without_INS_Persion_family)
,SUM(UnpaidLeaveAmount)
,SUM(TotalNetIncome_Custom),SUM(GrossedUpWithoutHousing_Custom)
,sum(GrossedUpWithoutHousing_WithoutGrossIncome_Custom)
 FROM #tblSalDetail
 group by EmployeeID

UPDATE #tblSal_Sal_des SET IsCash = b.IsCash,Notes = b.Notes
from #tblSal_Sal_des sal
inner join #tmpSalSal_Backup b on sal.EmployeeID = b.EmployeeID and sal.Month = @Month and Year = @Year

/*
TakeHome_Actual_VND

TakeHome_RequestedAmount
TakeHome_Requested_Currency
Takehome_Requested_ExchangeRate
*/
-- kiểm tra coi có ai cần dc trả ngoại tệ không
  select EmployeeID,CurrencyCode,RequestAmount,AlsoViewVNDAmount,TransferAll
  into #PaidInAnotherCurrency
  from tblSal_RequestPaidInAnotherCurrency
  where @month +@year*12 >= FromMonth + FromYear *12
  and (ToMonth is null or @month +@year*12 <= ToMonth + ToYear *12)
  and EmployeeID in (select EmployeeID from #tblEmployeeIDList)

  --select sal.EmployeeID,sal.GrossTakeHome,p.RequestAmount,p.CurrencyCode,ex.ExchangeRate

  update sal set
  TakeHome_RequestedAmount = p.RequestAmount
  ,TakeHome_Requested_Currency = p.CurrencyCode
  ,Takehome_Requested_ExchangeRate = ex.ExchangeRate
  ,TakeHome_Actual_VND= ROUND(
   case when sal.GrossTakeHome -(p.RequestAmount * ex.ExchangeRate) >0 then sal.GrossTakeHome -(p.RequestAmount * ex.ExchangeRate) else 0 end
   ,0)
  from  #tblSal_Sal_des sal
  inner join  #PaidInAnotherCurrency p on sal.EmployeeID = p.EmployeeID
  inner join #EmployeeExchangeRate ex on p.EmployeeID = ex.EmployeeID and p.CurrencyCode = ex.CurrencyCode

-- cập nhật Key của table
 SET ANSI_WARNINGS ON
 SELECT KU.table_name as TABLENAME,column_name as PRIMARYKEYCOLUMN into #tmpPRIMARYKEYCOLUMN
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS TC
INNER JOIN
    INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS KU
          ON TC.CONSTRAINT_TYPE = 'PRIMARY KEY' AND
          TC.CONSTRAINT_NAME = KU.CONSTRAINT_NAME AND
             KU.table_name in (select PhysicTableName from #NameOfPhysicTables)

update t set PrimaryKeyCOlumns = tmp.PrimaryKeyCOlumns from #NameOfPhysicTables t inner join (
 SELECT TABLENAME,
  STUFF((
    SELECT ',' + CAST(tmp.PRIMARYKEYCOLUMN AS VARCHAR(MAX))
    FROM #tmpPRIMARYKEYCOLUMN tmp
 WHERE (tmp.TABLENAME = Results.TABLENAME)
    FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)')
  ,1,1,'') as PrimaryKeyCOlumns
FROM    #tmpPRIMARYKEYCOLUMN Results
GROUP BY TABLENAME
) tmp on t.PhysicTableName = tmp.TABLENAME
 SET ANSI_WARNINGS Off
declare @tempTableName nvarchar(500),@PhysicTableName nvarchar(500)



if @CalculateRetro= 0 -- nếu @CalculateRetro= 0 thì chẳng có trong bảng tạm cũng như bảng danh sách nhân viên đâu, nhưng mà cứ chạy cái cho nó chắc
begin
 -- delêt bảng danh sách nhân viên
 --(EmployeeID IN (SELECT EmployeeID FROM #tblEmployeeIDList))
delete #tblEmployeeIDList from #tblEmployeeIDList e
where exists(select 1 from tblSal_Lock sl where e.EmployeeID = sl.EmployeeID and sl.Month = @Month and sl.Year = @Year)
 -- tạo cái base query
  -- chắc ăn hơn nữa thì xóa 1 lần trong các bảng tạm đi nào a e
  set @Query = N'delete %temptableName% from %temptableName% tmp where tmp.EmployeeId not in(select EmployeeID from #tblEmployeeIDList)
  -- delete bảng thực cho nó gọn
  delete %PhysicTableName% from %PhysicTableName% phy where phy.Month= '+CAST(@Month as varchar(2))+' and phy.Year= '+CAST(@year as varchar(4))+' and isnull(phy.PeriodID,0) = '+cast(@PeriodID as varchar(20))+'
  and exists (select 1 from #tblEmployeeIDList tel where phy.EmployeeID = tel.EmployeeID)
  '
 declare @UpdateQuery nvarchar(max) = ''
 if exists (select 1 from #NameOfPhysicTables where len (ISNULL(PrimaryKeyCOlumns,'')) <= 1)
 begin
 select N'Những bảng không có key cần xem lại', * from #NameOfPhysicTables where len (ISNULL(PrimaryKeyCOlumns,'')) <= 1 -- không có key kô cho lưu
 delete #NameOfPhysicTables where len (ISNULL(PrimaryKeyCOlumns,'')) <= 1 -- không có key kô cho lưu
 end
 while exists(select 1 from #NameOfPhysicTables)
 begin
  select top 1 @tempTableName = TempTablename,@PhysicTableName = PhysicTableName from #NameOfPhysicTables
  --print @tempTableName + '-'+@PhysicTableName
  set @UpdateQuery = REPLACE(REPLACE(@Query,'%PhysicTableName%',@PhysicTableName),'%temptableName%',@tempTableName)
  --print @UpdateQuery
  execute (@UpdateQuery)

  exec sp_InsertUpdateFromTempTableTOTable @TempTableName = @tempTableName, @TableName = @PhysicTableName
  delete #NameOfPhysicTables where @tempTableName = TempTablename and @PhysicTableName = PhysicTableName
 end
 if @CalculateRetro = 0
 update sal1
 set
 Attdays =  sal1.Attdays  - ISNULL(sal2.Attdays,0)
 ,TotalPaidDays =  sal1.TotalPaidDays  - ISNULL(sal2.TotalPaidDays,0)
 ,PaidLeaves =  sal1.PaidLeaves  - ISNULL(sal2.PaidLeaves,0)
 ,UnPaidLeaves =  sal1.UnPaidLeaves  - ISNULL(sal2.UnPaidLeaves,0)
 ,TotalSunDay =  sal1.TotalSunDay  - ISNULL(sal2.TotalSunDay,0)
  from tblSal_AttDataSumary_ForReport sal1
 inner join tblSal_AttDataSumary_ForReport sal2 on sal1.EmployeeID = sal2.EmployeeID and sal2.Month= @Month and sal2.Year =@Year and sal2.PeriodID = 1
where sal1.EmployeeID in(select EmployeeID from #tblEmployeeIDList) and sal1.Month = @Month and sal1.Year= @Year
and sal1.PeriodID = 0

end
else if @CalculateRetro = 1
begin
 select sal1.EmployeeID,sal1.DaysOfSalEntry-ISNULL(sal2.DaysOfSalEntry,0) as BalanceDays
 into #DiffDaysofSalEntry
 from (select EmployeeID,SUM(DaysOfSalEntry) as DaysOfSalEntry
from #tblSal_Sal_Detail_des
group by EmployeeID)sal1
cross apply(select SUM(DaysOfSalEntry) as DaysOfSalEntry from tblSal_Sal_Detail sd where sd.EmployeeID = sal1.EmployeeID and sd.Month = @Month and sd.Year= @Year and sd.PeriodID= 0)sal2

 -- diff basic
 select sal1.EmployeeID,sal1.ActualMonthlyBasic as ActualMonthlyBasic_Retro,sal2.ActualMonthlyBasic
 ,sal1.ActualMonthlyBasic-isnull(sal2.ActualMonthlyBasic,0) as Diff
  into #DiffBasic
 from #tblSal_Sal_des sal1
 left join tblSal_Sal sal2 on sal1.EmployeeID = sal2.EmployeeID and sal2.Month = @Month and sal2.Year= @Year and sal2.PeriodID = 0
 where ISNULL(sal1.ActualMonthlyBasic,0) <> ISNULL(sal2.ActualMonthlyBasic,0)

 --diff ot
 select ot1.EmployeeID
 ,ISNULL(ot1.OTAmount,0)-ISNULL(ot2.OTAmount,0) as DiffOTAmount
 ,ISNULL(ot1.TaxableOTAmount,0)-ISNULL(ot2.TaxableOTAmount,0) as DiffTaxableOTAmount
 ,ISNULL(ot1.NoneTaxableOTAmount,0)-ISNULL(ot2.NoneTaxableOTAmount,0) as DiffNoneTaxableOTAmount
 into #DiffOT
 from #tblSal_OT_des ot1
 left join tblSal_OT ot2 on ot1.EmployeeID= ot2.EmployeeID and ot2.Month = @Month and ot2.Year = @Year
 and ot2.PeriodID = 0


 -- diff allowance
 select al1.EmployeeID
 ,sum(ISNULL(al1.Amount,0) - isnull(al2.Amount,0)) as DiffAmount
 ,sum(ISNULL(al1.TaxableAmount,0) - isnull(al2.TaxableAmount,0)) as DiffTaxableAmount
 ,sum(ISNULL(al1.UntaxableAmount,0) - isnull(al2.UntaxableAmount,0)) as DiffNontaxableAmount
 ,'AL_'+als.AllowanceCode+ '_Retro' as RetroTablecolumnName
  into #DiffAllowance
 from #tblSal_Allowance_des al1
 inner join tblAllowanceSetting als on al1.AllowanceID = als.AllowanceID
 left join tblSal_Allowance al2 on  al2.Month= @Month and al2.Year = @Year and al1.EmployeeID = al2.EmployeeID and al1.AllowanceID = al2.AllowanceID and al2.PeriodID = 0
 group by al1.EmployeeID,al1.AllowanceID,'AL_'+als.AllowanceCode+ '_Retro'

 delete #DiffAllowance where  ISNULL(DiffAmount ,0)=0

 -- diff Night shift -- added

 select ns1.EmployeeID,ISNULL(ns1.NSAmount,0) - isnull(ns2.NSAmount,0) as DiffAmount
 into #DiffNightShift
 from #tblSal_NS_des ns1
 left join tblSal_NS ns2 on ns1.EmployeeID = ns2.EmployeeID and ns2.Month = @Month and ns2.Year= @Year
 and ns2.PeriodID= 0
 where ISNULL(ns1.NSAmount,0) - isnull(ns2.NSAmount,0) <>0



 delete #tblEmployeeIDList where EmployeeID in(select EmployeeID from tblSal_Lock where Month = @nextMonth and Year = @nextYear) -- xóa những thằng đã khóa lương tháng sau


 delete tblSal_Retro
 from tblSal_Retro re
 where Month = @nextMonth and Year = @nextYear and
  EmployeeID in( select EmployeeID from #tblEmployeeIDList)
 and not exists(select 1 from tblSal_Lock sl where sl.Month = @nextMonth and sl.Year = @nextYear)
  and  EmployeeID not in(select EmployeeID
      from tblSal_AttendanceData_Retro r
      where r.Month = @Month and r.Year = @Year
       union
    select c.EmployeeID from tblCustomAttendanceData c where c.Month= @Month and c.Year = @Year and c.IsRetro= 1
    )
    and ISNULL(IsImported,0) =0


  -- xóa những thằng ko phải imported, nằm trong danh sách working, mà ko nằm trong danh sách nhân viên retro
  -- ịn vào nếu chưa có

 insert into tblSal_Retro(EmployeeID,Month,Year)
 select distinct EmployeeID,@nextMonth,@nextYear from (
  select EmployeeID from #DiffAllowance
  union
  select EmployeeID from #DiffBasic
  union
  select EmployeeID from #DiffOT
  )u where u.EmployeeID not in(select EmployeeID from tblSal_Retro r where r.Month= @nextMonth and r.Year = @nextYear)


  -- update thôi
  -- basic
  update tblSal_Retro set ActualMonthlyBasic_Retro_Amount = ROUND(b.Diff,0)
  from tblSal_Retro re
 left join #DiffBasic b on re.EmployeeID = b.EmployeeID
 where re.Month = @nextMonth and re.Year = @nextYear
 and re.EmployeeID in(select EmployeeID from #tblEmployeeIDList)

  -- ot
  update tblSal_Retro set
  OT_Retro_Amount = ROUND(b.DiffOTAmount,0), Nontax_OT_Retro_Amount= ROUND(b.DiffNoneTaxableOTAmount,0)
  from tblSal_Retro re
 left join #DiffOT b on re.EmployeeID = b.EmployeeID
 where re.Month = @nextMonth and re.Year = @nextYear
 and re.EmployeeID in(select EmployeeID from #tblEmployeeIDList)

 -- allowance
 set @Query = ''

  select @Query+='
  if COL_LENGTH(''tblSal_Retro'','''+RetroTablecolumnName+''') is null
  begin
   alter table tblSal_Retro add ['+RetroTablecolumnName+'] money
   alter table tblSal_Retro_Sumary add ['+RetroTablecolumnName+'] money
   alter table #tblSal_Retro_tmpImport add ['+RetroTablecolumnName+'] money
  end
  ' from (select distinct RetroTablecolumnName from #DiffAllowance) s

  exec(@Query)

  set @Query =''
  select @Query +='
  update tblSal_Retro set ['+RetroTablecolumnName+'] = ROUND(tmp.DiffAmount,0)
  from tblSal_Retro  t
  inner join #DiffAllowance tmp  on t.EmployeeID = tmp.EmployeeID and tmp.RetroTablecolumnName = '''+RetroTablecolumnName+'''' from (select distinct RetroTablecolumnName from #DiffAllowance) s
  --print @Query
  exec(@Query)
  --select * from #DiffAllowance

  --  diff ins
  select re.EmployeeID, ISNULL(re.EmployeeTotal,0) - isnull(ins.EmployeeTotal,0)  as DiffEMployee
  ,ISNULL(re.CompanyTotal,0) - ISNULL(ins.CompanyTotal,0) as DiffCompany
  into #DiffIns
   from tblSal_Insurance_Retro re
  left join tblSal_Insurance ins on re.EmployeeID = ins.EmployeeID  and ins.Month = @Month and ins.Year = @Year
 -- and  (ISNULL(re.EmployeeTotal,0) <> isnull(ins.EmployeeTotal,0) or ISNULL(re.CompanyTotal,0) <> ISNULL(ins.CompanyTotal,0))
  where re.Month = @Month and re.Year = @Year
  and re.EmployeeID in(select EmployeeID from
  #tblEmployeeIDList)
  update tblSal_Retro set
  INS_Retro_Amount_EE = ROUND(b.DiffEMployee,0), INS_Retro_Amount_ER = ROUND(b.DiffCompany,0)
  from tblSal_Retro re
 left join #DiffIns b on re.EmployeeID = b.EmployeeID
 where re.Month = @nextMonth and re.Year = @nextYear
 and re.EmployeeID in(select EmployeeID from #tblEmployeeIDList)


 -- diff union
 -- do đã delete đi add lại ròi nên đừng có sợ gì cả
 select u.EmployeeID
 ,ISNULL(u.UnionFeeEmp,0) -ISNULL(sal.EmpUnion,0) as DiffEmployee
 ,ISNULL(u.UnionFeeComp,0) -ISNULL(sal.CompUnion,0) as DiffCompany
  into #diffUnion
 from #tblTradeUnion u
 left join tblSal_Sal sal on u.EmployeeID = sal.EmployeeID and sal.Month = @Month and sal.Year= @Year
 where  ISNULL(u.UnionFeeEmp,0) <> ISNULL(sal.EmpUnion,0) or ISNULL(u.UnionFeeComp,0) <>ISNULL(sal.CompUnion,0)


  update tblSal_Retro set
  Union_RETRO_EE = ROUND(b.DiffEmployee,0), Union_RETRO_ER = ROUND(b.DiffCompany,0)
  from tblSal_Retro re
 left join #diffUnion b on re.EmployeeID = b.EmployeeID
 where re.Month = @nextMonth and re.Year = @nextYear
 and re.EmployeeID in(select EmployeeID from #tblEmployeeIDList)

 -- diff Night Shift -- finalize

  update tblSal_Retro set
  NightShift_RETRO =ROUND( b.DiffAmount,0)
  from tblSal_Retro re
left join #DiffNightShift b on re.EmployeeID = b.EmployeeID
 where re.Month = @nextMonth and re.Year = @nextYear
 and re.EmployeeID in(select EmployeeID from #tblEmployeeIDList)


 -- balance days
  update tblSal_Retro set
  BalanceDays = b.BalanceDays
  from tblSal_Retro re
 left join #DiffDaysofSalEntry b on re.EmployeeID = b.EmployeeID
 where re.Month = @nextMonth and re.Year = @nextYear
 and re.EmployeeID in(select EmployeeID from #tblEmployeeIDList)



 --drop table #DiffBasic
 --drop table #DiffOT
 --drop table #DiffAllowance
 --drop table #DiffInspiut
end
 ----------------------Error in salary period-------------------------------
 INSERT INTO #tblSal_Error_des([Month],[Year],EmployeeID,Remark,PeriodID)
 SELECT @Month ,@Year,EmployeeID,Reason,@PeriodID
 FROM #TableVarSalError
 --------------------Drop temporary table--------------------------------

 DROP TABLE #tblEmployeeIDList
 DROP TABLE #tblSalDetail
 DROP TABLE #tblLvHistory
END
print 'eof'
--exec SALCAL_MAIN 1,2018,3,0,'-1',0
GO
exec SALCAL_MAIN 2,2026,3,0,'-1',0
