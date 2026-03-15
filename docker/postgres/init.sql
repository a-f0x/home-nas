-- =====================================================
-- Home Server PostgreSQL Initialization
-- =====================================================
-- Этот скрипт создаёт базы данных для всех приложений
-- на домашнем сервере. Добавляйте новые приложения ниже.
-- =====================================================

-- Nextcloud
CREATE DATABASE nextcloud;
CREATE USER nextclouduser WITH ENCRYPTED PASSWORD 'cad44ae9-d336-44fe-a565-e357da7480d5';
ALTER DATABASE nextcloud OWNER TO nextclouduser;
GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextclouduser;
GRANT ALL ON SCHEMA public TO nextclouduser;

-- =====================================================
-- Добавьте новые приложения ниже
-- =====================================================

-- Пример: WordPress
-- CREATE DATABASE wordpress;
-- CREATE USER wpuser WITH ENCRYPTED PASSWORD 'your-password-here';
-- ALTER DATABASE wordpress OWNER TO wpuser;
-- GRANT ALL PRIVILEGES ON DATABASE wordpress TO wpuser;
-- GRANT ALL ON SCHEMA public TO wpuser;

-- Пример: Gitea
-- CREATE DATABASE gitea;
-- CREATE USER giteauser WITH ENCRYPTED PASSWORD 'your-password-here';
-- ALTER DATABASE gitea OWNER TO giteauser;
-- GRANT ALL PRIVILEGES ON DATABASE gitea TO giteauser;
-- GRANT ALL ON SCHEMA public TO giteauser;
