--Lương chính thức: cột grosstakehome là cột Netpayment cuối cùng
select * from tblSal_Sal where EmployeeID = '210289'
EmployeeID	Month	Year	PeriodID	ActualMonthlyBasic	TaxableAllowance	NontaxableAllowance	TaxableAdjustment	NontaxableAdj	TotalIncome	IOAmt	EmpUnion	CompUnion	TaxableIncomeBeforeDeduction	IncomeAfterPIT	GrossTakeHome	SalCalRuleID	DepartmentID	SectionID	PositionID	IsCash	TotalEarn	RemainAL	Notes	TaxableAdjustmentTotal_ForSalary	TaxableAdjustmentTotal_NotForSalary	TotalIncome_Taxable_Without_INS_Persion_family	TotalIncome_ForSalaryTaxedAdj	TotalCostComPaid	TotalDeduction	UnpaidLeaveAmount	EmpUnion_RETRO	CompUnion_RETRO	TotalNetIncome_Custom	GrossedUpWithoutHousing_Custom	GrossedUpWithoutHousing_WithoutGrossIncome_Custom	NSAmount	TotalPayrollFund	Payroll_PrepareBy	Payroll_ReviewedBy	Payroll_Reviewed_SencondBy	Payroll_CheckedBy	Payroll_ApprovedBy	TakeHome_Actual_VND	TakeHome_RequestedAmount	TakeHome_Requested_Currency	Takehome_Requested_ExchangeRate
210289	3	2026	0	10807000.00	2406289.0909	267000.00	-27290.404	388419.00	15516440.4142	NULL	40000.00	244140.00	13013990.9596	14194705.4142	14194705.00	NULL	NULL	NULL	NULL	NULL	15543730.8182	NULL	NULL	-27290.404	0.00	14295725.9596	15128021.4142	18652085.4142	NULL	NULL	NULL	NULL	14295725.9596	14295726.00	14295725.9596	NULL	18652085.4142	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL
select * from tblSal_Sal_Detail where EmployeeID = '210289'
EmployeeID	Month	Year	PeriodID	SalaryHistoryID	FromDate	ToDate	DepartmentID	SectionID	PositionID	StandardWDays	ATTHours	WorkingHours	BasicSalary	SalaryPerDay	ActualMonthlyBasic	TaxableAllowance	NontaxableAllowance	TaxableAdjustment	NontaxableAdj	TotalIncome	IOAmt	EmpUnion	CompUnion	TaxableIncomeBeforeDeduction	IncomeAfterPIT	GrossTakeHome	SalaryPerHour	SalCalRuleID	LatestSalEntry	TotalEarn	DaysOfSalEntry	TaxableAdjustmentTotal_ForSalary	TaxableAdjustmentTotal_NotForSalary	Raw_BasicSalary	Raw_CurrencyCode	Raw_ExchangeRate	IsNet	UnpaidLeaveAmount	TotalNetIncome_Custom	GrossedUpWithoutHousing_Custom	GrossedUpWithoutHousing_WithoutGrossIncome_Custom	PayrollTypeCode	NSAmount
210289	3	2026	0	39849	2026-03-01 00:00:00.000	2026-03-31 23:59:59.000	13	90	1470	22	NULL	NULL	10807000.00	491227.2727	10807000.00	2406289.0909	267000.00	-27290.404	388419.00	15516440.4142	NULL	40000.00	244140.00	13013990.9596	14194705.4142	14194705.00	54580.8081	1	1	15543730.8182	22	-27290.404	0.00	10540000.00	VND	NULL	0	NULL	14295725.9596	14295726.00	14295726.00	NULL	NULL
--Lương tăng ca
select * from tblSal_OT where EmployeeID = '210289'
EmployeeID	Year	Month	OTAmount	TaxableOTAmount	NoneTaxableOTAmount	PeriodID	Raw_TaxableOTAmount	Raw_NoneTaxableOTAmount	NightShiftAmount
210289	2026	3	1942022.7273	1109727.2727	832295.4545	0	1109727.2727	832295.4545	NULL
select * from tblSal_OT_Detail where EmployeeID = '210289'
OverTimeID	EmployeeID	Year	Month	SalaryHistoryID	OTHour	OTAmount	OTRate	SalaryPerDay	SalaryPerHour	LatestSalEntry	PeriodID	NightShiftAmount	TaxableOTAmount	NoneTaxableOTAmount
11	210289	2026	3	39849	9	832295.4545	150	554863.6364	61651.5152	1	0	NULL	554863.6364	277431.8182
23	210289	2026	3	39849	9	1109727.2727	200	554863.6364	61651.5152	1	0	NULL	554863.6364	554863.6364
--Lương ca đêm
select * from tblSal_NS --where EmployeeID = '210289'
EmployeeID	Month	Year	NSHours	NSAmount	PeriodID
10117	3	2026	80	2816826.9231	0
10158	3	2026	24	465796.1538	0
250392	3	2026	16	152923.0769	0
select * from tblSal_NS_Detail
EmployeeID	Month	Year	SalaryHistoryID	NSHours	NSAmount	LatestSalEntry	PeriodID	NSKind	NSAmount_Taxed
10117	3	2026	7688	80	2816826.9231	1	0	2	NULL
10158	3	2026	7875	24	465796.1538	1	0	2	NULL
250392	3	2026	42741	16	152923.0769	1	0	2	NULL
--Lương phụ cấp
select * from tblSal_Allowance where EmployeeID = '210289'
EmployeeID	AllowanceID	Year	Month	PaidDays	Amount	AmountLastMonth	TakeHome	Taxable	UntaxableAmount	TaxableAmount	Raw_DefaultAmount	Raw_ExchangeRate	Raw_CurrencyCode	GroupAllowanceName_PRVN	RetroAmount	RetroAmountNonTax	MonthlyCustomAmount	PeriodID	Raw_TaxableAmount	Raw_UntaxableAmount	Raw_RetroAmountNonTax
210289	57	2026	3	NULL	267000.00	NULL	0	NULL	267000.00	0.00	267000.00	NULL	VND	NULL	NULL	0.00	NULL	0	0.00	267000.00	0.00
select * from  tblSal_Allowance_Detail where EmployeeID = '210289'
EmployeeID	AllowanceID	Year	Month	SalaryHistoryID	Amount	AmountLastMonth	TakeHome	Taxable	TaxableAmount	UntaxableAmount	DefaultAmount	Raw_DefaultAmount	Raw_ExchangeRate	Raw_CurrencyCode	RetroAmount	RetroAmountNonTax	MonthlyCustomAmount	PeriodID	Raw_TaxableAmount	Raw_UntaxableAmount	Raw_RetroAmountNonTax	TotalPaidDays
210289	57	2026	3	39849	267000.00	NULL	0	NULL	0.00	267000.00	267000.00	267000.00	NULL	VND	NULL	0.00	NULL	0	0.00	267000.00	0.00	22
--Lương các khoản điều chỉnh
select * from tblSal_Adjustment where EmployeeID = '210289'
EmployeeID	Month	Year	IncomeID	Amount	PeriodID	TaxableAmount	UntaxableAmount	Raw_TaxableAmount	Raw_UntaxableAmount	Raw_Amount
210289	3	2026	5	388419.00	0	0.00	388419.00	0.00	388419.00	388419.00
210289	3	2026	33	27290.404	0	27290.404	0.00	27290.404	0.00	27290.404
--Bảng thuế thu nhập cá nhân
select * from tblSal_Tax where EmployeeID = '210289'
IncomeTaxable	Month	Year	DeductionAmt	EmployeeExemption	FamilyExemption	DependantNumber	TaxAmt	EmployeeID	OTDeduction	Salary13Amount	isNET	TaxableIncome_EROnly_ForNETOnly	PITAmt_ER	TaxRetroImported	FixedPercents	isLowSalary	PeriodID	RefNo
0.00	3	2026	15500000.00	15500000.00	0.00	NULL	0.00	210289	832295.4545	NULL	0	0.00	NULL	NULL	NULL	NULL	0	NULL
--Bảng bảo hiểm
select * from tblSal_Insurance  where EmployeeID = '210289'
EmployeeID	Year	Month	HIIncome	SIIncome	EmployeeHI	EmployeeSI	EmployeeTotal	CompanyHI	CompanySI	CompanyTotal	Total	SalaryHistoryID	UIIncome	EmployeeUI	CompanyUI	Approval	UnionFeeEmp	UnionFeeComp	Notes	InsPaymentStatus	EmployeeSM	CompanySM	TypeExportSI	ApproveIns
210289	2026	3	12207000.00	12207000.00	183105.00	976560.00	1281735.00	366210.00	2136225.00	2624505.00	3906240.00	39849	12207000.00	122070.00	122070.00	0	NULL	NULL	Encrease	0	NULL	NULL	NULL	NULL
--Bảng công đoàn là cột EmpUnion và ComUnion
select * from tblSal_Sal where EmployeeID = '210289'
EmployeeID	Month	Year	PeriodID	ActualMonthlyBasic	TaxableAllowance	NontaxableAllowance	TaxableAdjustment	NontaxableAdj	TotalIncome	IOAmt	EmpUnion	CompUnion
210289	3	2026	0	10807000.00	2406289.0909	267000.00	-27290.404	388419.00	15516440.4142	NULL	40000.00	244140.00
-- Bảng nghỉ phép
select * from tblLvHistory where EmployeeID = '210289'
EmployeeID	LeaveDate	LeaveStatus	LeaveCode	LvAmount	LvRegister	Reason	NotAllowDiligence	SubmitApplicationDate	StatusID	IdentityID	IsImport
210289	2026-01-02 00:00:00.000	3	AL	NULL	NULL	System automatically insert leave	0	NULL	NULL	NULL	NULL
210289	2026-02-02 00:00:00.000	3	UL	NULL	NULL	System automatically insert leave	0	NULL	NULL	NULL	NULL
-- Bảng đi trễ về sớm
select * from tblInLateOutEarly where EmployeeID = '210289'
EmployeeID	IODate	IOKind	IOStart	IOEnd	IOMinutes	IOMinutesDeduct	ApprovedDeduct	StatusID	Reason	Period	IdentityID	IsCD	IOMinutesRound
210289	2025-11-28 00:00:00.000	2	2025-11-28 12:54:00.000	2025-11-28 17:00:00.000	246	255	1	1	NULL	NULL	NULL	NULL	255
210289	2026-03-11 00:00:00.000	2	2026-03-11 16:33:00.000	2026-03-11 17:00:00.000	27	30	1	1	NULL	NULL	NULL	NULL	30
-- các cột mong muốn để in ra bảng lương
No                         : 1
Emp.ID                    : 210289
Employee Name             : Nguyễn Ngọc Trà My
Sex                       : F
Basic Income              : 10,807,000
Work days                 : 22
1.5                       : 9.0
Amount                    : 832,295
2                         : 9.0
Amount                    : 1,109,727
3                         : -
Amount                    : -
NS. Hour                  : -
NS. Amount                : -
Qualifi.                  : 600,000
Position                  : 800,000
Responsibilit             : -
Living support 1          : 350,000
Language                  : -
Transport                 : 436,289
Perfect Att               : 220,000
Others                    : -
Total Income              : 15,155,312
Social Ins 8%             : 976,560
Health Ins 1.5%           : 183,105
Jobless Ins 1%            : 122,070

---------------------------------------------------------------------------------
-- GHI CHÚ NGHIỆP VỤ & QUY TẮC PHẦN MỀM (DOCUMENTATION)
---------------------------------------------------------------------------------
-- 1. Trạng thái ngày (HolidayStatus):
--    - HolidayStatus = 0: Ngày làm việc bình thường (Normal working day).
--    - HolidayStatus = 1: Ngày nghỉ tuần (Chủ nhật / Day off).
--    - HolidayStatus = 2: Ngày nghỉ lễ quốc gia (Holiday).
--
-- 2. Trạng thái nhân sự (IsProbation):
--    - IsProbation = 1: Nhân viên đang thử việc (Probation).
--    - IsProbation = 0: Nhân viên đã chính thức (Official staff).
--
-- 3. Phân biệt phụ cấp theo TransportID:
--    - Nhân viên có TransportID = 2 (hoặc Kilometer = 2) -> Hưởng phụ cấp nhà ở (House_AL).
--    - Nhân viên có TransportID > 2 (mức 3, 6, 9,...) -> Hưởng phụ cấp đi lại (Transport_AL).
--    * Khi kết xuất báo cáo và đối chiếu so sánh, gộp tổng cả 2 loại này vào cột chung là "Transport".
--
-- 4. Quy tắc tính Chuyên cần (PerfectAtt):
--    - CNV Ca bình thường:
--      + Hưởng full 300,000 VND/tháng nếu không trễ, không sớm, không nghỉ CC (vắng không phép/không lương).
--      + Trễ hoặc sớm tổng cộng <= 30 phút/tháng: Bị trừ 80,000 VND (chỉ nhận 220,000 VND).
--      + Trễ/sớm > 30 phút hoặc nghỉ CC > 0 ngày hoặc nghỉ việc trong tháng: Bị trừ sạch chuyên cần (nhận 0 VND).
--    - CNV theo Kíp 5L1N (EmployeeTypeID = 2):
--      + Chỉ áp dụng cho CNV chính thức (IsProbation = 0).
--      + Được cộng thêm 200,000 VND (tổng tối đa 500,000 VND/tháng) nếu đi làm đầy đủ ít nhất 3 ngày Chủ Nhật trong tháng.
--      + Ngày Chủ Nhật được định nghĩa là ngày làm việc bình thường của Kíp (HolidayStatus = 0 và DATEPART(dw, AttDate) là Chủ nhật).
--      + Nhân viên phải đi làm thực tế vào ngày đó (AttDays = 1), đồng thời không được vi phạm trễ, sớm hay vắng trong cả tháng.
--      * Lưu ý đồng bộ: Đối với các tháng trước tháng 5 (@Month < 5), tiền chuyên cần sẽ được ghi đè trực tiếp từ cột Perfect_Att của bảng ImportPayrollCheck để đảm bảo đồng bộ 100% với dữ liệu Excel.
--
-- 5. Quy tắc tính các Phụ cấp Core (Qualification_AL, Pos_AL, Responsibility_AL, Language_AL):
--    - Đối với CNV mới vào làm trong tháng (NotYetWork > 0) hoặc nghỉ việc trong tháng (NotTermiWork > 0):
--      + Số tiền được hưởng tính theo tỷ lệ: (DefaultAmount / 26.0) * DaysOfSalEntry (Số ngày được tính lương).
--    - Đối với CNV cũ bình thường trong tháng:
--      + Đi làm thực tế (AttDays) > 7 ngày: Nhận đầy đủ 100% phụ cấp (DefaultAmount).
--      + Đi làm thực tế (AttDays) <= 7 ngày: Tính theo tỷ lệ công thực tế: (DefaultAmount / STD_WD) * AttDays.
Leave                     : -
LA                        : -
EL                        : 0.50
Leave                     : -
LA                        : -
EL                        : 27,290
Union Fee                 : 40,000
Work Off 70               : -
Other Deduction           : -
Total Deduction           : 1,349,025
Taxable Income            : -
Tax                       : -
Nontax Allowance          : 388,419
Nontax Deduction          : -
Net Payment               : 14,194,705
Social Ins 17.5%          : 2,136,225
Health Ins 3%             : 366,210
Jobless Ins 1%            : 122,070