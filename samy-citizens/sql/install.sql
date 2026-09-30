-- samy-citizens veritabanı şeması
-- Kaynak başlarken otomatik çalıştırılır (CREATE TABLE IF NOT EXISTS); elle de içe aktarabilirsin.
-- Eski kurulumlar: eksik sütun/indeksler server/db.lua tarafından otomatik eklenir (elle yapmak için sql/upgrade_v3.sql).

CREATE TABLE IF NOT EXISTS `samy_citizens_residents` (
  `id` VARCHAR(50) NOT NULL,
  `firstname` VARCHAR(50) NOT NULL,
  `lastname` VARCHAR(50) NOT NULL,
  `age` INT NOT NULL DEFAULT 30,
  `gender` VARCHAR(10) NOT NULL DEFAULT 'male',
  `model` VARCHAR(64) NOT NULL,
  `appearance` LONGTEXT NULL,
  `voice_id` VARCHAR(64) NULL,
  `personality` LONGTEXT NULL,
  `backstory` TEXT NULL,
  `job` LONGTEXT NULL,
  `home_id` VARCHAR(64) NULL,
  `vehicle` LONGTEXT NULL,
  `favorite_places` LONGTEXT NULL,
  `acquaintances` LONGTEXT NULL,
  `topics` LONGTEXT NULL,
  `routine_id` VARCHAR(64) NULL,
  `phone_number` VARCHAR(20) NULL,
  `needs` LONGTEXT NULL,
  `mood` INT NOT NULL DEFAULT 0,
  `mood_reason` VARCHAR(255) NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'alive',
  `status_until` BIGINT NOT NULL DEFAULT 0,
  `state` LONGTEXT NULL,
  `profile` LONGTEXT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_phone` (`phone_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `samy_citizens_locations` (
  `id` VARCHAR(64) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `type` VARCHAR(20) NOT NULL DEFAULT 'other',
  `area` VARCHAR(50) NULL,
  `public` TINYINT(1) NOT NULL DEFAULT 1,
  `data` LONGTEXT NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `samy_citizens_routines` (
  `id` VARCHAR(64) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `samy_citizens_relationships` (
  `npc_id` VARCHAR(50) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `char_name` VARCHAR(100) NULL,
  `familiarity` INT NOT NULL DEFAULT 0,
  `affinity` INT NOT NULL DEFAULT 0,
  `trust` INT NOT NULL DEFAULT 10,
  `stage` VARCHAR(20) NOT NULL DEFAULT 'stranger',
  `last_seen` BIGINT NOT NULL DEFAULT 0,
  `times_met` INT NOT NULL DEFAULT 0,
  `meet_days` INT NOT NULL DEFAULT 0,
  `last_meet_day` VARCHAR(16) NULL,
  `phone_known` TINYINT(1) NOT NULL DEFAULT 0,
  `player_phone` VARCHAR(32) NULL,
  `name_known` TINYINT(1) NOT NULL DEFAULT 0,
  `npc_name_shown` TINYINT(1) NOT NULL DEFAULT 0,
  `nickname` VARCHAR(50) NULL,
  `facts` LONGTEXT NULL,
  `daily_date` VARCHAR(16) NULL,
  `daily_affinity` INT NOT NULL DEFAULT 0,
  `daily_trust` INT NOT NULL DEFAULT 0,
  `daily_familiarity` INT NOT NULL DEFAULT 0,
  `daily_gifts` INT NOT NULL DEFAULT 0,
  `proactive_date` VARCHAR(16) NULL,
  `proactive_count` INT NOT NULL DEFAULT 0,
  `last_decay_day` VARCHAR(16) NULL,
  `xp` INT NOT NULL DEFAULT 0,
  `romance` VARCHAR(16) NOT NULL DEFAULT 'none',
  `first_met` BIGINT NOT NULL DEFAULT 0,
  `last_contact` BIGINT NOT NULL DEFAULT 0,
  `daily_xp` INT NOT NULL DEFAULT 0,
  `stats` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`npc_id`, `citizenid`),
  KEY `idx_citizen` (`citizenid`),
  KEY `idx_npc_phone` (`npc_id`, `phone_known`),
  KEY `idx_citizen_romance` (`citizenid`, `romance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `samy_citizens_memories` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `npc_id` VARCHAR(50) NOT NULL,
  `citizenid` VARCHAR(64) NULL,
  `text` VARCHAR(600) NOT NULL,
  `importance` TINYINT NOT NULL DEFAULT 3,
  `type` VARCHAR(20) NOT NULL DEFAULT 'conversation',
  `valence` TINYINT NOT NULL DEFAULT 0,
  `shareable` TINYINT(1) NOT NULL DEFAULT 0,
  `shared` TINYINT(1) NOT NULL DEFAULT 0,
  `archived` TINYINT(1) NOT NULL DEFAULT 0,
  `source_id` INT NULL,
  `source_npc` VARCHAR(50) NULL,
  `keywords` TEXT NULL,
  `data` TEXT NULL,
  `created_at` BIGINT NOT NULL,
  `last_accessed` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_npc_citizen` (`npc_id`, `citizenid`),
  KEY `idx_importance` (`importance`),
  KEY `idx_source` (`source_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `samy_citizens_appointments` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `npc_id` VARCHAR(50) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `location_id` VARCHAR(64) NOT NULL,
  `start_min` BIGINT NOT NULL,
  `purpose` VARCHAR(200) NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
  `met_at` BIGINT NULL,
  `created_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_npc` (`npc_id`),
  KEY `idx_citizen` (`citizenid`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `samy_citizens_messages` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `npc_id` VARCHAR(50) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `player_phone` VARCHAR(32) NULL,
  `direction` VARCHAR(4) NOT NULL,
  `body` TEXT NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'sent',
  `created_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_thread` (`npc_id`, `citizenid`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `samy_citizens_conversations` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `npc_id` VARCHAR(50) NOT NULL,
  `citizenid` VARCHAR(64) NULL,
  `char_name` VARCHAR(100) NULL,
  `channel` VARCHAR(10) NOT NULL DEFAULT 'talk',
  `speaker` VARCHAR(10) NOT NULL,
  `message` TEXT NOT NULL,
  `meta` TEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_npc` (`npc_id`),
  KEY `idx_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `samy_citizens_daily_log` (
  `npc_id` VARCHAR(50) NOT NULL,
  `game_day` INT NOT NULL,
  `entries` LONGTEXT NULL,
  `summary` TEXT NULL,
  PRIMARY KEY (`npc_id`, `game_day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
