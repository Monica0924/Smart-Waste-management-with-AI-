-- =============================================
-- EcoWaste Admin Tracking Database Schema
-- Comprehensive tracking of all admin activities and analytics
-- =============================================

-- Create database (uncomment if needed)
-- CREATE DATABASE IF NOT EXISTS ecowaste_admin_tracking CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE ecowaste_admin_tracking;

-- =============================================
-- ADMIN ACTIVITY TRACKING TABLES
-- =============================================

-- Admin login sessions
CREATE TABLE IF NOT EXISTS admin_sessions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NOT NULL,
  session_token VARCHAR(255) NOT NULL UNIQUE,
  ip_address VARCHAR(45) NOT NULL,
  user_agent TEXT NULL,
  login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  logout_time TIMESTAMP NULL,
  is_active BOOLEAN DEFAULT TRUE,
  session_duration INT DEFAULT 0, -- in seconds
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_admin_id (admin_id),
  INDEX idx_session_token (session_token),
  INDEX idx_is_active (is_active),
  INDEX idx_login_time (login_time),
  CONSTRAINT fk_admin_sessions_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Admin activity log (detailed tracking)
CREATE TABLE IF NOT EXISTS admin_activity_log (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NOT NULL,
  session_id INT UNSIGNED NULL,
  activity_type VARCHAR(100) NOT NULL,
  activity_category VARCHAR(50) NOT NULL,
  activity_description TEXT NOT NULL,
  target_resource VARCHAR(100) NULL,
  target_id VARCHAR(100) NULL,
  old_values JSON NULL,
  new_values JSON NULL,
  ip_address VARCHAR(45) NOT NULL,
  user_agent TEXT NULL,
  request_method VARCHAR(10) NULL,
  request_url TEXT NULL,
  response_status INT NULL,
  execution_time_ms INT DEFAULT 0,
  additional_data JSON NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_admin_id (admin_id),
  INDEX idx_session_id (session_id),
  INDEX idx_activity_type (activity_type),
  INDEX idx_activity_category (activity_category),
  INDEX idx_created_at (created_at),
  INDEX idx_target_resource (target_resource),
  CONSTRAINT fk_activity_log_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE,
  CONSTRAINT fk_activity_log_session FOREIGN KEY (session_id) REFERENCES admin_sessions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Admin page visits tracking
CREATE TABLE IF NOT EXISTS admin_page_visits (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NOT NULL,
  session_id INT UNSIGNED NULL,
  page_name VARCHAR(100) NOT NULL,
  page_url TEXT NOT NULL,
  visit_duration INT DEFAULT 0, -- in seconds
  referrer_url TEXT NULL,
  ip_address VARCHAR(45) NOT NULL,
  user_agent TEXT NULL,
  screen_resolution VARCHAR(20) NULL,
  browser_name VARCHAR(50) NULL,
  browser_version VARCHAR(20) NULL,
  os_name VARCHAR(50) NULL,
  device_type ENUM('desktop', 'tablet', 'mobile') NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_admin_id (admin_id),
  INDEX idx_session_id (session_id),
  INDEX idx_page_name (page_name),
  INDEX idx_created_at (created_at),
  CONSTRAINT fk_page_visits_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE,
  CONSTRAINT fk_page_visits_session FOREIGN KEY (session_id) REFERENCES admin_sessions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Admin data modifications tracking
CREATE TABLE IF NOT EXISTS admin_data_changes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NOT NULL,
  session_id INT UNSIGNED NULL,
  table_name VARCHAR(100) NOT NULL,
  record_id VARCHAR(100) NOT NULL,
  operation_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  field_name VARCHAR(100) NULL,
  old_value TEXT NULL,
  new_value TEXT NULL,
  change_reason TEXT NULL,
  ip_address VARCHAR(45) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_admin_id (admin_id),
  INDEX idx_session_id (session_id),
  INDEX idx_table_name (table_name),
  INDEX idx_operation_type (operation_type),
  INDEX idx_created_at (created_at),
  CONSTRAINT fk_data_changes_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE,
  CONSTRAINT fk_data_changes_session FOREIGN KEY (session_id) REFERENCES admin_sessions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Admin security events
CREATE TABLE IF NOT EXISTS admin_security_events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NULL,
  event_type VARCHAR(50) NOT NULL,
  event_severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL,
  event_description TEXT NOT NULL,
  ip_address VARCHAR(45) NOT NULL,
  user_agent TEXT NULL,
  additional_data JSON NULL,
  is_resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMP NULL,
  resolved_by INT UNSIGNED NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_admin_id (admin_id),
  INDEX idx_event_type (event_type),
  INDEX idx_event_severity (event_severity),
  INDEX idx_is_resolved (is_resolved),
  INDEX idx_created_at (created_at),
  CONSTRAINT fk_security_events_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE SET NULL,
  CONSTRAINT fk_security_events_resolved_by FOREIGN KEY (resolved_by) REFERENCES admins(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- ANALYTICS & REPORTING TABLES
-- =============================================

-- Admin performance metrics
CREATE TABLE IF NOT EXISTS admin_performance_metrics (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NOT NULL,
  date DATE NOT NULL,
  total_login_time INT DEFAULT 0, -- in seconds
  total_activities INT DEFAULT 0,
  total_page_views INT DEFAULT 0,
  avg_session_duration INT DEFAULT 0,
  most_used_feature VARCHAR(100) NULL,
  error_count INT DEFAULT 0,
  success_rate DECIMAL(5,2) DEFAULT 0.00,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_admin_date (admin_id, date),
  INDEX idx_admin_id (admin_id),
  INDEX idx_date (date),
  CONSTRAINT fk_performance_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- System usage statistics
CREATE TABLE IF NOT EXISTS system_usage_stats (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  date DATE NOT NULL UNIQUE,
  total_admin_logins INT DEFAULT 0,
  total_active_sessions INT DEFAULT 0,
  total_activities INT DEFAULT 0,
  total_page_views INT DEFAULT 0,
  peak_concurrent_users INT DEFAULT 0,
  avg_response_time_ms INT DEFAULT 0,
  error_rate DECIMAL(5,2) DEFAULT 0.00,
  most_active_admin INT UNSIGNED NULL,
  most_used_feature VARCHAR(100) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_date (date),
  CONSTRAINT fk_usage_stats_admin FOREIGN KEY (most_active_admin) REFERENCES admins(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Feature usage tracking
CREATE TABLE IF NOT EXISTS feature_usage_tracking (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NOT NULL,
  feature_name VARCHAR(100) NOT NULL,
  feature_category VARCHAR(50) NOT NULL,
  usage_count INT DEFAULT 1,
  last_used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  total_time_spent INT DEFAULT 0, -- in seconds
  success_count INT DEFAULT 0,
  error_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_admin_feature (admin_id, feature_name),
  INDEX idx_admin_id (admin_id),
  INDEX idx_feature_name (feature_name),
  INDEX idx_feature_category (feature_category),
  CONSTRAINT fk_feature_usage_admin FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- VIEWS FOR ANALYTICS
-- =============================================

-- Admin activity summary
CREATE OR REPLACE VIEW v_admin_activity_summary AS
SELECT 
  a.id as admin_id,
  a.username,
  a.display_name,
  COUNT(DISTINCT s.id) as total_sessions,
  COUNT(al.id) as total_activities,
  MAX(s.login_time) as last_login,
  AVG(s.session_duration) as avg_session_duration,
  COUNT(DISTINCT DATE(s.login_time)) as active_days,
  COUNT(DISTINCT al.activity_type) as unique_activity_types
FROM admins a
LEFT JOIN admin_sessions s ON a.id = s.admin_id
LEFT JOIN admin_activity_log al ON a.id = al.admin_id
GROUP BY a.id, a.username, a.display_name;

-- Daily admin activity
CREATE OR REPLACE VIEW v_daily_admin_activity AS
SELECT 
  DATE(al.created_at) as date,
  a.username,
  a.display_name,
  COUNT(al.id) as activity_count,
  COUNT(DISTINCT al.activity_type) as unique_activities,
  COUNT(DISTINCT al.target_resource) as resources_accessed,
  SUM(al.execution_time_ms) as total_execution_time,
  AVG(al.execution_time_ms) as avg_execution_time
FROM admin_activity_log al
JOIN admins a ON al.admin_id = a.id
GROUP BY DATE(al.created_at), a.id, a.username, a.display_name
ORDER BY date DESC, activity_count DESC;

-- Security events summary
CREATE OR REPLACE VIEW v_security_events_summary AS
SELECT 
  event_type,
  event_severity,
  COUNT(*) as event_count,
  COUNT(CASE WHEN is_resolved = TRUE THEN 1 END) as resolved_count,
  COUNT(CASE WHEN is_resolved = FALSE THEN 1 END) as pending_count,
  MIN(created_at) as first_occurrence,
  MAX(created_at) as last_occurrence
FROM admin_security_events
GROUP BY event_type, event_severity
ORDER BY event_count DESC;

-- Feature usage analytics
CREATE OR REPLACE VIEW v_feature_usage_analytics AS
SELECT 
  feature_name,
  feature_category,
  COUNT(DISTINCT admin_id) as unique_users,
  SUM(usage_count) as total_usage,
  AVG(usage_count) as avg_usage_per_user,
  SUM(total_time_spent) as total_time_spent,
  SUM(success_count) as total_successes,
  SUM(error_count) as total_errors,
  (SUM(success_count) / (SUM(success_count) + SUM(error_count))) * 100 as success_rate
FROM feature_usage_tracking
GROUP BY feature_name, feature_category
ORDER BY total_usage DESC;

-- =============================================
-- STORED PROCEDURES
-- =============================================

-- Track admin login
DELIMITER //
CREATE PROCEDURE TrackAdminLogin(
  IN p_admin_id INT UNSIGNED,
  IN p_ip_address VARCHAR(45),
  IN p_user_agent TEXT
)
BEGIN
  DECLARE v_session_token VARCHAR(255);
  DECLARE v_session_id INT UNSIGNED;
  
  -- Generate session token
  SET v_session_token = CONCAT('sess_', UNIX_TIMESTAMP(), '_', p_admin_id, '_', SUBSTRING(MD5(RAND()), 1, 16));
  
  -- Create session
  INSERT INTO admin_sessions (admin_id, session_token, ip_address, user_agent)
  VALUES (p_admin_id, v_session_token, p_ip_address, p_user_agent);
  
  SET v_session_id = LAST_INSERT_ID();
  
  -- Log login activity
  INSERT INTO admin_activity_log (admin_id, session_id, activity_type, activity_category, activity_description, ip_address, user_agent)
  VALUES (p_admin_id, v_session_id, 'LOGIN', 'AUTHENTICATION', 'Admin logged in successfully', p_ip_address, p_user_agent);
  
  SELECT v_session_id as session_id, v_session_token as session_token;
END //
DELIMITER ;

-- Track admin activity
DELIMITER //
CREATE PROCEDURE TrackAdminActivity(
  IN p_admin_id INT UNSIGNED,
  IN p_session_id INT UNSIGNED,
  IN p_activity_type VARCHAR(100),
  IN p_activity_category VARCHAR(50),
  IN p_activity_description TEXT,
  IN p_target_resource VARCHAR(100),
  IN p_target_id VARCHAR(100),
  IN p_old_values JSON,
  IN p_new_values JSON,
  IN p_ip_address VARCHAR(45),
  IN p_user_agent TEXT,
  IN p_request_method VARCHAR(10),
  IN p_request_url TEXT,
  IN p_response_status INT,
  IN p_execution_time_ms INT,
  IN p_additional_data JSON
)
BEGIN
  INSERT INTO admin_activity_log (
    admin_id, session_id, activity_type, activity_category, activity_description,
    target_resource, target_id, old_values, new_values, ip_address, user_agent,
    request_method, request_url, response_status, execution_time_ms, additional_data
  ) VALUES (
    p_admin_id, p_session_id, p_activity_type, p_activity_category, p_activity_description,
    p_target_resource, p_target_id, p_old_values, p_new_values, p_ip_address, p_user_agent,
    p_request_method, p_request_url, p_response_status, p_execution_time_ms, p_additional_data
  );
  
  -- Update feature usage tracking
  IF p_target_resource IS NOT NULL THEN
    INSERT INTO feature_usage_tracking (admin_id, feature_name, feature_category, usage_count, success_count, error_count)
    VALUES (p_admin_id, p_target_resource, p_activity_category, 1, 
            CASE WHEN p_response_status >= 200 AND p_response_status < 300 THEN 1 ELSE 0 END,
            CASE WHEN p_response_status >= 400 THEN 1 ELSE 0 END)
    ON DUPLICATE KEY UPDATE
      usage_count = usage_count + 1,
      last_used_at = CURRENT_TIMESTAMP,
      total_time_spent = total_time_spent + COALESCE(p_execution_time_ms, 0),
      success_count = success_count + CASE WHEN p_response_status >= 200 AND p_response_status < 300 THEN 1 ELSE 0 END,
      error_count = error_count + CASE WHEN p_response_status >= 400 THEN 1 ELSE 0 END,
      updated_at = CURRENT_TIMESTAMP;
  END IF;
END //
DELIMITER ;

-- Track admin logout
DELIMITER //
CREATE PROCEDURE TrackAdminLogout(
  IN p_session_id INT UNSIGNED,
  IN p_admin_id INT UNSIGNED
)
BEGIN
  DECLARE v_session_duration INT DEFAULT 0;
  
  -- Calculate session duration
  SELECT TIMESTAMPDIFF(SECOND, login_time, NOW()) INTO v_session_duration
  FROM admin_sessions 
  WHERE id = p_session_id AND admin_id = p_admin_id;
  
  -- Update session
  UPDATE admin_sessions 
  SET logout_time = NOW(), 
      is_active = FALSE, 
      session_duration = v_session_duration
  WHERE id = p_session_id AND admin_id = p_admin_id;
  
  -- Log logout activity
  INSERT INTO admin_activity_log (admin_id, session_id, activity_type, activity_category, activity_description, ip_address)
  VALUES (p_admin_id, p_session_id, 'LOGOUT', 'AUTHENTICATION', 
          CONCAT('Admin logged out after ', v_session_duration, ' seconds'), 
          (SELECT ip_address FROM admin_sessions WHERE id = p_session_id));
END //
DELIMITER ;

-- Generate daily analytics
DELIMITER //
CREATE PROCEDURE GenerateDailyAnalytics(IN p_date DATE)
BEGIN
  DECLARE v_total_logins INT DEFAULT 0;
  DECLARE v_total_activities INT DEFAULT 0;
  DECLARE v_total_page_views INT DEFAULT 0;
  DECLARE v_most_active_admin INT UNSIGNED DEFAULT NULL;
  DECLARE v_most_used_feature VARCHAR(100) DEFAULT NULL;
  
  -- Calculate metrics
  SELECT COUNT(*) INTO v_total_logins FROM admin_sessions WHERE DATE(login_time) = p_date;
  SELECT COUNT(*) INTO v_total_activities FROM admin_activity_log WHERE DATE(created_at) = p_date;
  SELECT COUNT(*) INTO v_total_page_views FROM admin_page_visits WHERE DATE(created_at) = p_date;
  
  -- Find most active admin
  SELECT admin_id INTO v_most_active_admin 
  FROM admin_activity_log 
  WHERE DATE(created_at) = p_date 
  GROUP BY admin_id 
  ORDER BY COUNT(*) DESC 
  LIMIT 1;
  
  -- Find most used feature
  SELECT feature_name INTO v_most_used_feature
  FROM feature_usage_tracking 
  WHERE DATE(last_used_at) = p_date
  GROUP BY feature_name
  ORDER BY SUM(usage_count) DESC
  LIMIT 1;
  
  -- Insert or update daily stats
  INSERT INTO system_usage_stats (
    date, total_admin_logins, total_activities, total_page_views, 
    most_active_admin, most_used_feature
  ) VALUES (
    p_date, v_total_logins, v_total_activities, v_total_page_views,
    v_most_active_admin, v_most_used_feature
  ) ON DUPLICATE KEY UPDATE
    total_admin_logins = v_total_logins,
    total_activities = v_total_activities,
    total_page_views = v_total_page_views,
    most_active_admin = v_most_active_admin,
    most_used_feature = v_most_used_feature,
    updated_at = CURRENT_TIMESTAMP;
END //
DELIMITER ;

-- =============================================
-- TRIGGERS
-- =============================================

-- Auto-update performance metrics
DELIMITER //
CREATE TRIGGER tr_update_performance_metrics
AFTER INSERT ON admin_activity_log
FOR EACH ROW
BEGIN
  INSERT INTO admin_performance_metrics (admin_id, date, total_activities)
  VALUES (NEW.admin_id, DATE(NEW.created_at), 1)
  ON DUPLICATE KEY UPDATE
    total_activities = total_activities + 1,
    updated_at = CURRENT_TIMESTAMP;
END //
DELIMITER ;

-- =============================================
-- SAMPLE DATA
-- =============================================

-- Insert sample admin sessions
INSERT INTO admin_sessions (admin_id, session_token, ip_address, user_agent, login_time, is_active) VALUES
(1, 'sess_1703123456_1_abc123def456', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', NOW() - INTERVAL 2 HOUR, TRUE),
(1, 'sess_1703120000_1_xyz789uvw012', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', NOW() - INTERVAL 1 DAY, FALSE)
ON DUPLICATE KEY UPDATE session_token = VALUES(session_token);

-- Insert sample activities
INSERT INTO admin_activity_log (admin_id, session_id, activity_type, activity_category, activity_description, target_resource, ip_address, user_agent, response_status, execution_time_ms) VALUES
(1, 1, 'VIEW', 'DASHBOARD', 'Viewed admin dashboard', 'dashboard', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 200, 150),
(1, 1, 'EXPORT', 'DATA', 'Exported user data to CSV', 'users_export', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 200, 2500),
(1, 1, 'UPDATE', 'USER', 'Updated user profile', 'user_profile', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 200, 300)
ON DUPLICATE KEY UPDATE activity_description = VALUES(activity_description);

-- =============================================
-- VERIFICATION QUERIES
-- =============================================

-- Check if everything was created successfully
SELECT 'Admin tracking database setup complete!' AS status;

-- Show table counts
SELECT 
  'admin_sessions' AS table_name, COUNT(*) AS count FROM admin_sessions
UNION ALL
SELECT 'admin_activity_log', COUNT(*) FROM admin_activity_log
UNION ALL
SELECT 'admin_page_visits', COUNT(*) FROM admin_page_visits
UNION ALL
SELECT 'admin_data_changes', COUNT(*) FROM admin_data_changes
UNION ALL
SELECT 'admin_security_events', COUNT(*) FROM admin_security_events
UNION ALL
SELECT 'admin_performance_metrics', COUNT(*) FROM admin_performance_metrics
UNION ALL
SELECT 'system_usage_stats', COUNT(*) FROM system_usage_stats
UNION ALL
SELECT 'feature_usage_tracking', COUNT(*) FROM feature_usage_tracking;

-- Show sample analytics
SELECT 'Admin Activity Summary:' AS info;
SELECT * FROM v_admin_activity_summary LIMIT 5;

SELECT 'Security Events Summary:' AS info;
SELECT * FROM v_security_events_summary LIMIT 5;
