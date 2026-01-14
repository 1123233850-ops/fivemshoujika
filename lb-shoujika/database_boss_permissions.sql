-- ============================================
-- LB手机运营商系统 - 老板职位和权限设置
-- ============================================

-- 此文件用于在ESX数据库中创建boss职位和相关权限
-- 执行前请确保已连接到正确的数据库（通常是 es_extended 数据库）

-- ============================================
-- 创建boss职位（如果不存在）
-- ============================================
INSERT INTO `jobs` (`name`, `label`) 
VALUES ('boss', '老板')
ON DUPLICATE KEY UPDATE `label` = '老板';

-- ============================================
-- 创建boss职位的等级
-- ============================================
-- 员工等级（0级）
INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) 
VALUES ('boss', 0, 'employee', '员工', 500, '{}', '{}')
ON DUPLICATE KEY UPDATE 
    `label` = '员工',
    `salary` = 500,
    `skin_male` = '{}',
    `skin_female` = '{}';

-- 经理等级（1级）
INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) 
VALUES ('boss', 1, 'manager', '经理', 1000, '{}', '{}')
ON DUPLICATE KEY UPDATE 
    `label` = '经理',
    `salary` = 1000,
    `skin_male` = '{}',
    `skin_female` = '{}';

-- 老板等级（2级）- 最高权限
INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) 
VALUES ('boss', 2, 'boss', '老板', 2000, '{}', '{}')
ON DUPLICATE KEY UPDATE 
    `label` = '老板',
    `salary` = 2000,
    `skin_male` = '{}',
    `skin_female` = '{}';
