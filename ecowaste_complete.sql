-- EcoWaste Complete Database Schema
-- Import this file into MySQL to set up the complete system

-- Create database (uncomment if needed)
-- CREATE DATABASE IF NOT EXISTS ecowaste CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE ecowaste;

-- =============================================
-- ADMIN SYSTEM TABLES
-- =============================================

-- Admin users table
CREATE TABLE IF NOT EXISTS admins (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(64) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  display_name VARCHAR(120) NULL,
  email VARCHAR(190) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Admin audit log
CREATE TABLE IF NOT EXISTS admin_audit (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NOT NULL,
  action VARCHAR(120) NOT NULL,
  details TEXT NULL,
  ip_address VARCHAR(45) NULL,
  user_agent TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_admin_audit_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- APP DATA TABLES (for your existing app)
-- =============================================

-- User profiles (matches your app's localStorage structure)
CREATE TABLE IF NOT EXISTS profiles (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL UNIQUE,
  email VARCHAR(190) NULL,
  display_name VARCHAR(120) NULL,
  eco_points INT DEFAULT 0,
  total_waste_deposited INT DEFAULT 0,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_eco_points (eco_points)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Transactions (matches your app's localStorage structure)
CREATE TABLE IF NOT EXISTS transactions (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  points INT NOT NULL,
  type VARCHAR(50) DEFAULT 'waste_deposit',
  waste_category VARCHAR(50) NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_timestamp (timestamp),
  INDEX idx_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Leaderboard cache (optional, for performance)
CREATE TABLE IF NOT EXISTS leaderboard_cache (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  display_name VARCHAR(120) NOT NULL,
  eco_points INT NOT NULL,
  rank_position INT NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_user (user_id),
  INDEX idx_rank (rank_position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- VIEWS FOR ADMIN DASHBOARD
-- =============================================

-- Current leaderboard view
CREATE OR REPLACE VIEW v_leaderboard AS
SELECT 
  COALESCE(p.display_name, p.email, p.user_id) AS name,
  p.eco_points AS points,
  p.user_id,
  p.joined_at
FROM profiles p
ORDER BY p.eco_points DESC, p.joined_at ASC;

-- Transaction summary view
CREATE OR REPLACE VIEW v_transaction_summary AS
SELECT 
  t.id,
  t.user_id,
  COALESCE(p.display_name, p.email, t.user_id) AS user_name,
  t.points,
  t.type,
  t.waste_category,
  t.timestamp,
  DATE(t.timestamp) AS date_only
FROM transactions t
LEFT JOIN profiles p ON t.user_id = p.user_id
ORDER BY t.timestamp DESC;

-- Daily stats view
CREATE OR REPLACE VIEW v_daily_stats AS
SELECT 
  DATE(timestamp) AS date,
  COUNT(*) AS total_transactions,
  SUM(CASE WHEN points > 0 THEN points ELSE 0 END) AS total_points_earned,
  SUM(CASE WHEN points < 0 THEN ABS(points) ELSE 0 END) AS total_points_redeemed,
  COUNT(DISTINCT user_id) AS unique_users,
  COUNT(CASE WHEN type = 'waste_deposit' THEN 1 END) AS waste_deposits,
  COUNT(CASE WHEN type = 'redeem' THEN 1 END) AS redemptions
FROM transactions
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- Category breakdown view
CREATE OR REPLACE VIEW v_category_stats AS
SELECT 
  waste_category,
  COUNT(*) AS count,
  SUM(points) AS total_points,
  AVG(points) AS avg_points,
  COUNT(DISTINCT user_id) AS unique_users
FROM transactions
WHERE waste_category IS NOT NULL
GROUP BY waste_category
ORDER BY count DESC;

-- =============================================
-- STORED PROCEDURES
-- =============================================

-- Update user points (atomic operation)
DELIMITER //
CREATE PROCEDURE UpdateUserPoints(
  IN p_user_id VARCHAR(64),
  IN p_points_delta INT,
  IN p_display_name VARCHAR(120),
  IN p_email VARCHAR(190)
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  
  START TRANSACTION;
  
  -- Insert or update profile
  INSERT INTO profiles (user_id, display_name, email, eco_points)
  VALUES (p_user_id, p_display_name, p_email, p_points_delta)
  ON DUPLICATE KEY UPDATE
    eco_points = eco_points + p_points_delta,
    display_name = COALESCE(p_display_name, display_name),
    email = COALESCE(p_email, email),
    updated_at = CURRENT_TIMESTAMP;
  
  COMMIT;
END //
DELIMITER ;

-- Refresh leaderboard cache
DELIMITER //
CREATE PROCEDURE RefreshLeaderboardCache()
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  
  START TRANSACTION;
  
  -- Clear existing cache
  DELETE FROM leaderboard_cache;
  
  -- Rebuild cache with rankings
  INSERT INTO leaderboard_cache (user_id, display_name, eco_points, rank_position)
  SELECT 
    user_id,
    COALESCE(display_name, email, user_id) AS display_name,
    eco_points,
    ROW_NUMBER() OVER (ORDER BY eco_points DESC, joined_at ASC) AS rank_position
  FROM profiles
  WHERE eco_points > 0
  ORDER BY eco_points DESC, joined_at ASC;
  
  COMMIT;
END //
DELIMITER ;

-- =============================================
-- TRIGGERS
-- =============================================

-- Auto-update leaderboard cache when profiles change
DELIMITER //
CREATE TRIGGER tr_profiles_after_update
AFTER UPDATE ON profiles
FOR EACH ROW
BEGIN
  IF OLD.eco_points != NEW.eco_points THEN
    CALL RefreshLeaderboardCache();
  END IF;
END //
DELIMITER ;

-- Auto-update leaderboard cache when new profile is inserted
DELIMITER //
CREATE TRIGGER tr_profiles_after_insert
AFTER INSERT ON profiles
FOR EACH ROW
BEGIN
  CALL RefreshLeaderboardCache();
END //
DELIMITER ;

-- =============================================
-- SAMPLE DATA
-- =============================================

-- Insert default admin (change password!)
INSERT INTO admins (username, password_hash, display_name, email) VALUES
('admin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Eco Admin', 'admin@ecowaste.com')
ON DUPLICATE KEY UPDATE username = username;

-- Insert sample profiles (optional)
INSERT INTO profiles (user_id, email, display_name, eco_points) VALUES
('guest', 'guest@local', 'Guest User', 0),
('user1', 'ava@example.com', 'Ava', 120),
('user2', 'liam@example.com', 'Liam', 95),
('user3', 'noah@example.com', 'Noah', 80)
ON DUPLICATE KEY UPDATE user_id = user_id;

-- Insert sample transactions (optional)
INSERT INTO transactions (id, user_id, points, type, waste_category) VALUES
(UUID(), 'user1', 10, 'waste_deposit', 'plastic'),
(UUID(), 'user1', 5, 'waste_deposit', 'paper'),
(UUID(), 'user2', 15, 'waste_deposit', 'steel'),
(UUID(), 'user3', 8, 'waste_deposit', 'organic'),
(UUID(), 'user1', -100, 'redeem', 'Redeem: ₹50 Off Eco Store')
ON DUPLICATE KEY UPDATE id = id;

-- =============================================
-- PERMISSIONS (adjust as needed)
-- =============================================

-- Create a dedicated app user (optional)
-- CREATE USER IF NOT EXISTS 'ecowaste_app'@'localhost' IDENTIFIED BY 'your_app_password';
-- GRANT SELECT, INSERT, UPDATE ON ecowaste.profiles TO 'ecowaste_app'@'localhost';
-- GRANT SELECT, INSERT ON ecowaste.transactions TO 'ecowaste_app'@'localhost';
-- GRANT EXECUTE ON PROCEDURE ecowaste.UpdateUserPoints TO 'ecowaste_app'@'localhost';

-- Create a read-only admin user (optional)
-- CREATE USER IF NOT EXISTS 'ecowaste_readonly'@'localhost' IDENTIFIED BY 'your_readonly_password';
-- GRANT SELECT ON ecowaste.* TO 'ecowaste_readonly'@'localhost';

-- =============================================
-- INITIALIZE CACHE
-- =============================================

-- Refresh leaderboard cache with initial data
CALL RefreshLeaderboardCache();

-- =============================================
-- VERIFICATION QUERIES
-- =============================================

-- Check if everything was created successfully
SELECT 'Database setup complete!' AS status;

-- Show table counts
SELECT 
  'admins' AS table_name, COUNT(*) AS count FROM admins
UNION ALL
SELECT 'profiles', COUNT(*) FROM profiles
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'leaderboard_cache', COUNT(*) FROM leaderboard_cache;

-- Show sample leaderboard
SELECT * FROM v_leaderboard LIMIT 5;

-- Show sample transactions
SELECT * FROM v_transaction_summary LIMIT 5;
