-- ============================================
-- LB手机运营商系统 - 靓号上架表
-- ============================================

-- 靓号上架表（老板批量生成并上架的靓号）
CREATE TABLE IF NOT EXISTS `phone_operator_premium_numbers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `phone_number` VARCHAR(15) NOT NULL COMMENT '手机号码（靓号）',
    `package_id` INT UNSIGNED NOT NULL COMMENT '关联的套餐ID',
    `premium_type` VARCHAR(50) DEFAULT NULL COMMENT '靓号类型（如：六连号、顺子号等）',
    `price_multiplier` DECIMAL(5, 2) NOT NULL DEFAULT 1.00 COMMENT '价格倍数',
    `base_price` INT(11) NOT NULL COMMENT '基础价格（套餐价格）',
    `final_price` INT(11) NOT NULL COMMENT '最终价格（基础价格 * 倍数）',
    `status` ENUM('available', 'sold', 'reserved') NOT NULL DEFAULT 'available' COMMENT '状态：可购买/已售出/已预留',
    `sold_to` VARCHAR(100) DEFAULT NULL COMMENT '购买者标识符',
    `sold_at` TIMESTAMP NULL DEFAULT NULL COMMENT '售出时间',
    `created_by` VARCHAR(100) DEFAULT NULL COMMENT '创建者（老板）标识符',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_phone_number` (`phone_number`),
    KEY `idx_package_id` (`package_id`),
    KEY `idx_status` (`status`),
    KEY `idx_premium_type` (`premium_type`),
    FOREIGN KEY (`package_id`) REFERENCES `phone_operator_packages`(`id`) ON DELETE RESTRICT
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='靓号上架表';

