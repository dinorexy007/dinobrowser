-- ============================================
-- DINO BROWSER DATABASE SCHEMA
-- Target: MySQL 5.7+ / MariaDB 10.3+
-- Database: ahmeuesz_dino
-- ============================================

-- Create extensions table for Script Injection Store
CREATE TABLE IF NOT EXISTS `extensions` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `icon_url` VARCHAR(500) DEFAULT NULL,
    `js_code` LONGTEXT NOT NULL,
    `category` ENUM('productivity', 'privacy', 'appearance', 'social', 'utility') DEFAULT 'utility',
    `is_active` TINYINT(1) DEFAULT 1,
    `downloads` INT(11) UNSIGNED DEFAULT 0,
    `version` VARCHAR(20) DEFAULT '1.0.0',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_category` (`category`),
    INDEX `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create users table for Firebase Auth integration
CREATE TABLE IF NOT EXISTS `users` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `firebase_uid` VARCHAR(128) NOT NULL UNIQUE,
    `email` VARCHAR(255) NOT NULL,
    `display_name` VARCHAR(100) DEFAULT NULL,
    `premium_status` TINYINT(1) DEFAULT 0,
    `premium_expires_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE INDEX `idx_firebase_uid` (`firebase_uid`),
    INDEX `idx_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create user_extensions table to track installed extensions
CREATE TABLE IF NOT EXISTS `user_extensions` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` INT(11) UNSIGNED NOT NULL,
    `extension_id` INT(11) UNSIGNED NOT NULL,
    `is_enabled` TINYINT(1) DEFAULT 1,
    `installed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE INDEX `idx_user_extension` (`user_id`, `extension_id`),
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`extension_id`) REFERENCES `extensions`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- SAMPLE DATA FOR TESTING
-- ============================================

-- Insert sample extensions
INSERT INTO `extensions` (`name`, `description`, `icon_url`, `js_code`, `category`) VALUES
(
    'Dark Mode Pro',
    'Force dark mode on any website for comfortable night browsing',
    'https://bilalcode.site/icons/dark-mode.png',
    'document.documentElement.style.filter = "invert(1) hue-rotate(180deg)"; document.querySelectorAll("img, video, picture").forEach(el => el.style.filter = "invert(1) hue-rotate(180deg)");',
    'appearance'
),
(
    'Ad Blocker Lite',
    'Block common advertisement elements for cleaner browsing',
    'https://bilalcode.site/icons/ad-block.png',
    'const adSelectors = ["[class*=\"ad-\"]", "[id*=\"ad-\"]", "[class*=\"advertisement\"]", "iframe[src*=\"ads\"]"]; adSelectors.forEach(sel => document.querySelectorAll(sel).forEach(el => el.remove()));',
    'privacy'
),
(
    'Reading Mode',
    'Simplify page layout for distraction-free reading',
    'https://bilalcode.site/icons/reading.png',
    'document.body.innerHTML = "<div style=\"max-width:700px;margin:40px auto;padding:20px;font-size:18px;line-height:1.8;font-family:Georgia,serif;background:#fefefe;color:#333;\">" + (document.querySelector("article") || document.body).innerHTML + "</div>"; document.body.style.background = "#f4f4f4";',
    'productivity'
),
(
    'Screenshot Blocker',
    'Prevent websites from detecting screenshots',
    'https://bilalcode.site/icons/privacy.png',
    'Object.defineProperty(document, "visibilityState", {value: "visible", writable: false}); Object.defineProperty(document, "hidden", {value: false, writable: false});',
    'privacy'
),
(
    'Auto Scroll',
    'Automatically scroll pages at a comfortable reading pace',
    'https://bilalcode.site/icons/scroll.png',
    'let scrolling = true; let speed = 1; setInterval(() => { if(scrolling) window.scrollBy(0, speed); }, 50); document.addEventListener("click", () => scrolling = !scrolling);',
    'utility'
);
