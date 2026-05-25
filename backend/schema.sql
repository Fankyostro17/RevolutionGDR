-- 🔹 Crea database e utente (solo se non esistono già)
CREATE DATABASE IF NOT EXISTS rpg_portal_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'Fanky17'@'localhost' IDENTIFIED BY 'Thom.2007';
GRANT ALL PRIVILEGES ON rpg_portal_db.* TO 'Fanky17'@'localhost';
FLUSH PRIVILEGES;

USE rpg_portal_db;

-- 🔹 Tabella utenti (invariata)
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    nickname VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    date_of_birth DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_email (email),
    INDEX idx_nickname (nickname)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 🔹 Tabella avventure (AGGIORNATA con tutti i nuovi campi)
CREATE TABLE IF NOT EXISTS adventures (
    id VARCHAR(36) PRIMARY KEY,
    
    -- Info base
    title VARCHAR(255) NOT NULL,
    subtitle VARCHAR(255),
    description TEXT,
    
    -- Ruolo e stato
    role ENUM('master', 'player') NOT NULL DEFAULT 'master',
    status ENUM('active', 'paused', 'completed', 'locked', 'ended') DEFAULT 'active',
    
    -- Autore e date
    created_by VARCHAR(36) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    next_session DATETIME NULL,
    last_session DATETIME NULL,
    
    -- 🔹 NUOVI CAMPI per livello, giocatori, codice, one-shot
    level_min INT DEFAULT 1,
    level_max INT DEFAULT 20,
    max_players INT DEFAULT 0,
    join_code VARCHAR(8) UNIQUE,
    is_one_shot BOOLEAN DEFAULT FALSE,
    
    -- Foreign key e indici
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_created_by (created_by),
    INDEX idx_role (role),
    INDEX idx_status (status),
    INDEX idx_join_code (join_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 🔹 Tabella partecipanti (con CASCADE DELETE per rimozione automatica)
CREATE TABLE IF NOT EXISTS adventure_participants (
    id VARCHAR(36) PRIMARY KEY,
    adventure_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (adventure_id) REFERENCES adventures(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_participation (adventure_id, user_id),
    INDEX idx_user (user_id),
    INDEX idx_adventure (adventure_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 🔹 VIEW opzionale per contare i giocatori in tempo reale (utile per query veloci)
CREATE OR REPLACE VIEW v_adventure_stats AS
SELECT 
    a.id,
    a.title,
    a.status,
    a.max_players,
    COUNT(ap.user_id) as current_players
FROM adventures a
LEFT JOIN adventure_participants ap ON a.id = ap.adventure_id
GROUP BY a.id;