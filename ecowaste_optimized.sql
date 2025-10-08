-- =============================================
-- EcoWaste Optimized Database Schema
-- Analyzed from index.html and admin system
-- =============================================

-- Create database (uncomment if needed)
-- CREATE DATABASE IF NOT EXISTS ecowaste CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE ecowaste;

-- =============================================
-- ADMIN SYSTEM (from admin/login.php analysis)
-- =============================================

CREATE TABLE IF NOT EXISTS admins (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(64) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  display_name VARCHAR(120) NULL,
  email VARCHAR(190) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_username (username),
  INDEX idx_active (is_active)
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
  CONSTRAINT fk_admin_audit_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE,
  INDEX idx_admin_id (admin_id),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- APP CORE TABLES (matching localStorage structure)
-- =============================================

-- User profiles (matches ecowaste_profile localStorage)
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
  INDEX idx_eco_points (eco_points),
  INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Transactions (matches ecowaste_transactions localStorage)
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
  INDEX idx_type (type),
  INDEX idx_waste_category (waste_category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- CONFIGURATION TABLES (from app constants)
-- =============================================

-- Waste categories and points (from POINTS_BY_CATEGORY)
CREATE TABLE IF NOT EXISTS waste_categories (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  category_name VARCHAR(50) NOT NULL UNIQUE,
  points_value INT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_category_name (category_name),
  INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- AI detection mapping (from CATEGORY_MAP)
CREATE TABLE IF NOT EXISTS ai_detection_mapping (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  coco_class VARCHAR(100) NOT NULL,
  waste_category VARCHAR(50) NOT NULL,
  confidence_threshold DECIMAL(3,2) DEFAULT 0.35,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_coco_class (coco_class),
  INDEX idx_waste_category (waste_category),
  INDEX idx_is_active (is_active),
  CONSTRAINT fk_ai_mapping_category FOREIGN KEY (waste_category) REFERENCES waste_categories(category_name) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rewards system (from REWARDS array)
CREATE TABLE IF NOT EXISTS rewards (
  id VARCHAR(20) PRIMARY KEY,
  title VARCHAR(120) NOT NULL,
  description TEXT NULL,
  cost_points INT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_cost_points (cost_points),
  INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- ANALYTICS & CACHING TABLES
-- =============================================

-- Leaderboard cache (for performance)
CREATE TABLE IF NOT EXISTS leaderboard_cache (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  display_name VARCHAR(120) NOT NULL,
  eco_points INT NOT NULL,
  rank_position INT NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_user (user_id),
  INDEX idx_rank (rank_position),
  INDEX idx_eco_points (eco_points)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daily analytics
CREATE TABLE IF NOT EXISTS daily_analytics (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  date DATE NOT NULL UNIQUE,
  total_transactions INT DEFAULT 0,
  total_points_earned INT DEFAULT 0,
  total_points_redeemed INT DEFAULT 0,
  unique_users INT DEFAULT 0,
  waste_deposits INT DEFAULT 0,
  redemptions INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_date (date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- VIEWS FOR ADMIN DASHBOARD
-- =============================================

-- Current leaderboard (matches app's leaderboard display)
CREATE OR REPLACE VIEW v_leaderboard AS
SELECT 
  COALESCE(p.display_name, p.email, p.user_id) AS name,
  p.eco_points AS points,
  p.user_id,
  p.joined_at,
  ROW_NUMBER() OVER (ORDER BY p.eco_points DESC, p.joined_at ASC) AS rank_position
FROM profiles p
WHERE p.eco_points > 0
ORDER BY p.eco_points DESC, p.joined_at ASC;

-- Transaction summary (matches app's wallet display)
CREATE OR REPLACE VIEW v_transaction_summary AS
SELECT 
  t.id,
  t.user_id,
  COALESCE(p.display_name, p.email, t.user_id) AS user_name,
  t.points,
  t.type,
  t.waste_category,
  t.timestamp,
  DATE(t.timestamp) AS date_only,
  CASE WHEN t.points >= 0 THEN '+' ELSE '' END AS sign_display
FROM transactions t
LEFT JOIN profiles p ON t.user_id = p.user_id
ORDER BY t.timestamp DESC;

-- Category statistics
CREATE OR REPLACE VIEW v_category_stats AS
SELECT 
  t.waste_category,
  COUNT(*) AS transaction_count,
  SUM(t.points) AS total_points,
  AVG(t.points) AS avg_points,
  COUNT(DISTINCT t.user_id) AS unique_users,
  wc.points_value AS category_points_value
FROM transactions t
LEFT JOIN waste_categories wc ON t.waste_category = wc.category_name
WHERE t.waste_category IS NOT NULL
GROUP BY t.waste_category, wc.points_value
ORDER BY transaction_count DESC;

-- Daily stats
CREATE OR REPLACE VIEW v_daily_stats AS
SELECT 
  DATE(t.timestamp) AS date,
  COUNT(*) AS total_transactions,
  SUM(CASE WHEN t.points > 0 THEN t.points ELSE 0 END) AS total_points_earned,
  SUM(CASE WHEN t.points < 0 THEN ABS(t.points) ELSE 0 END) AS total_points_redeemed,
  COUNT(DISTINCT t.user_id) AS unique_users,
  COUNT(CASE WHEN t.type = 'waste_deposit' THEN 1 END) AS waste_deposits,
  COUNT(CASE WHEN t.type = 'redeem' THEN 1 END) AS redemptions
FROM transactions t
GROUP BY DATE(t.timestamp)
ORDER BY date DESC;

-- =============================================
-- STORED PROCEDURES
-- =============================================

-- Update user points (atomic operation)
DELIMITER //
CREATE PROCEDURE UpdateUserPoints(
  IN p_user_id VARCHAR(64),
  IN p_points_delta INT,
  IN p_display_name VARCHAR(120),
  IN p_email VARCHAR(190),
  IN p_transaction_type VARCHAR(50),
  IN p_waste_category VARCHAR(50)
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
  
  -- Insert transaction
  INSERT INTO transactions (id, user_id, points, type, waste_category)
  VALUES (UUID(), p_user_id, p_points_delta, p_transaction_type, p_waste_category);
  
  -- Update daily analytics
  INSERT INTO daily_analytics (date, total_transactions, total_points_earned, total_points_redeemed, unique_users, waste_deposits, redemptions)
  VALUES (
    CURDATE(),
    1,
    CASE WHEN p_points_delta > 0 THEN p_points_delta ELSE 0 END,
    CASE WHEN p_points_delta < 0 THEN ABS(p_points_delta) ELSE 0 END,
    1,
    CASE WHEN p_transaction_type = 'waste_deposit' THEN 1 ELSE 0 END,
    CASE WHEN p_transaction_type = 'redeem' THEN 1 ELSE 0 END
  )
  ON DUPLICATE KEY UPDATE
    total_transactions = total_transactions + 1,
    total_points_earned = total_points_earned + CASE WHEN p_points_delta > 0 THEN p_points_delta ELSE 0 END,
    total_points_redeemed = total_points_redeemed + CASE WHEN p_points_delta < 0 THEN ABS(p_points_delta) ELSE 0 END,
    unique_users = (SELECT COUNT(DISTINCT user_id) FROM transactions WHERE DATE(timestamp) = CURDATE()),
    waste_deposits = waste_deposits + CASE WHEN p_transaction_type = 'waste_deposit' THEN 1 ELSE 0 END,
    redemptions = redemptions + CASE WHEN p_transaction_type = 'redeem' THEN 1 ELSE 0 END,
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
-- SAMPLE DATA (matching app constants)
-- =============================================

-- Insert waste categories (from POINTS_BY_CATEGORY)
INSERT INTO waste_categories (category_name, points_value) VALUES
('plastic', 10),
('paper', 5),
('steel', 15),
('organic', 8)
ON DUPLICATE KEY UPDATE points_value = VALUES(points_value);

-- Insert AI detection mapping (from CATEGORY_MAP)
INSERT INTO ai_detection_mapping (coco_class, waste_category, confidence_threshold) VALUES
('bottle', 'plastic', 0.35),
('cup', 'plastic', 0.35),
('cell phone', 'plastic', 0.35),
('remote', 'plastic', 0.35),
('book', 'paper', 0.35),
('toilet paper', 'paper', 0.35),
('fork', 'steel', 0.35),
('knife', 'steel', 0.35),
('spoon', 'steel', 0.35),
('scissors', 'steel', 0.35),
('laptop', 'steel', 0.35),
('banana', 'organic', 0.35),
('apple', 'organic', 0.35),
('orange', 'organic', 0.35),
('broccoli', 'organic', 0.35),
('carrot', 'organic', 0.35)
ON DUPLICATE KEY UPDATE waste_category = VALUES(waste_category);

-- Insert rewards (from REWARDS array)
INSERT INTO rewards (id, title, description, cost_points) VALUES
('r-5off', '₹50 Off Eco Store', 'Save ₹50 on eco-friendly products.', 100),
('r-coffee', 'Free Coffee', '1 free coffee at partner cafes.', 80),
('r-bus', 'Bus Ticket 50% Off', 'Half price on one city bus ride.', 120),
('r-plant', 'Plant Sapling', 'Sponsor a sapling in your name.', 60)
ON DUPLICATE KEY UPDATE title = VALUES(title), description = VALUES(description), cost_points = VALUES(cost_points);

-- Insert default admin (change password!)
INSERT INTO admins (username, password_hash, display_name, email) VALUES
('admin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Eco Admin', 'admin@ecowaste.com')
ON DUPLICATE KEY UPDATE username = username;

-- Insert sample profiles (matching app's localStorage seed data)
INSERT INTO profiles (user_id, email, display_name, eco_points) VALUES
('guest', 'guest@local', 'Guest', 0),
('user1', 'ava@example.com', 'Ava', 120),
('user2', 'liam@example.com', 'Liam', 95),
('user3', 'noah@example.com', 'Noah', 80)
ON DUPLICATE KEY UPDATE user_id = user_id;

-- Insert sample transactions (matching app's localStorage seed data)
INSERT INTO transactions (id, user_id, points, type, waste_category) VALUES
(UUID(), 'user1', 10, 'waste_deposit', 'plastic'),
(UUID(), 'user1', 5, 'waste_deposit', 'paper'),
(UUID(), 'user2', 15, 'waste_deposit', 'steel'),
(UUID(), 'user3', 8, 'waste_deposit', 'organic'),
(UUID(), 'user1', -100, 'redeem', 'Redeem: ₹50 Off Eco Store')
ON DUPLICATE KEY UPDATE id = id;

-- =============================================
-- INITIALIZE CACHE
-- =============================================

-- Refresh leaderboard cache with initial data
CALL RefreshLeaderboardCache();

-- =============================================
-- VERIFICATION QUERIES
-- =============================================

-- Check if everything was created successfully
SELECT 'EcoWaste database setup complete!' AS status;

-- Show table counts
SELECT 
  'admins' AS table_name, COUNT(*) AS count FROM admins
UNION ALL
SELECT 'profiles', COUNT(*) FROM profiles
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'waste_categories', COUNT(*) FROM waste_categories
UNION ALL
SELECT 'ai_detection_mapping', COUNT(*) FROM ai_detection_mapping
UNION ALL
SELECT 'rewards', COUNT(*) FROM rewards
UNION ALL
SELECT 'leaderboard_cache', COUNT(*) FROM leaderboard_cache;

-- Show sample leaderboard (matching app display)
SELECT * FROM v_leaderboard LIMIT 5;

-- Show sample transactions (matching app wallet)
SELECT * FROM v_transaction_summary LIMIT 5;

-- Show category stats
SELECT * FROM v_category_stats;

-- Show rewards (matching app rewards modal)
SELECT * FROM rewards WHERE is_active = TRUE ORDER BY cost_points;
