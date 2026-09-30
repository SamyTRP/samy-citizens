-- samy-citizens v3 yükseltmesi (yaşayan NPC katmanı)
-- NORMALDE ÇALIŞTIRMANA GEREK YOK: kaynak başlarken server/db.lua eksik sütun ve indeksleri kendisi ekler
-- ve eski ilişkilerin XP'sini mevcut aşamalarına göre doldurur (kimse aşama kaybetmez).
-- Veritabanı kullanıcının ALTER yetkisi yoksa bu dosyayı bir kez elle içe aktar.
-- Not: Sütun zaten varsa MySQL "Duplicate column" hatası verir; o satırı atlayabilirsin.

ALTER TABLE `samy_citizens_residents` ADD COLUMN `profile` LONGTEXT NULL;

ALTER TABLE `samy_citizens_relationships` ADD COLUMN `xp` INT NOT NULL DEFAULT 0;
ALTER TABLE `samy_citizens_relationships` ADD COLUMN `romance` VARCHAR(16) NOT NULL DEFAULT 'none';
ALTER TABLE `samy_citizens_relationships` ADD COLUMN `first_met` BIGINT NOT NULL DEFAULT 0;
ALTER TABLE `samy_citizens_relationships` ADD COLUMN `last_contact` BIGINT NOT NULL DEFAULT 0;
ALTER TABLE `samy_citizens_relationships` ADD COLUMN `daily_xp` INT NOT NULL DEFAULT 0;
ALTER TABLE `samy_citizens_relationships` ADD COLUMN `stats` LONGTEXT NULL;

ALTER TABLE `samy_citizens_relationships` ADD INDEX `idx_npc_phone` (`npc_id`, `phone_known`);
ALTER TABLE `samy_citizens_relationships` ADD INDEX `idx_citizen_romance` (`citizenid`, `romance`);

-- Mevcut ilişkilere aşamalarına denk gelen XP (Config.Relationship.XP.Levels varsayılanları)
UPDATE `samy_citizens_relationships` SET `xp` = CASE `stage`
    WHEN 'acquaintance' THEN 100 WHEN 'friend' THEN 300 WHEN 'close_friend' THEN 700 ELSE 0 END
    WHERE `xp` = 0;
UPDATE `samy_citizens_relationships` SET `first_met` = UNIX_TIMESTAMP(`created_at`) WHERE `first_met` = 0;
