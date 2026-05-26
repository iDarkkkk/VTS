-- Nâng cấp 5 cấp duyệt cho Tăng ca thực tế
-- 1. Bảng Tăng ca Thực tế (Actual)
ALTER TABLE tblOTActualMasterNIVS ADD Approver_5 VARCHAR(50);
ALTER TABLE tblOTActualMasterNIVS ADD ApproveDate_5 DATETIME;
ALTER TABLE tblOTActualMasterNIVS ADD ApproverRemark_5 NVARCHAR(MAX);
ALTER TABLE tblOTActualMasterNIVS ADD ApproveDate_5_Old DATETIME;
ALTER TABLE tblOTActualMasterNIVS ADD ApproverRemark_5_Old NVARCHAR(MAX);
