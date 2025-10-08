- =============================================
-- EcoWaste AI Chatbot Database Schema
-- Stores all user data, chat history, and analytics
-- =============================================

-- Create database (uncomment if needed)
-- CREATE DATABASE IF NOT EXISTS ecowaste_chatbot CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE ecowaste_chatbot;

-- =============================================
-- USER MANAGEMENT TABLES
-- =============================================

-- User profiles (extends main app profiles)
CREATE TABLE IF NOT EXISTS chatbot_users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL UNIQUE,
  email VARCHAR(190) NULL,
  display_name VARCHAR(120) NULL,
  first_name VARCHAR(60) NULL,
  last_name VARCHAR(60) NULL,
  phone VARCHAR(20) NULL,
  avatar_url VARCHAR(255) NULL,
  timezone VARCHAR(50) DEFAULT 'UTC',
  language VARCHAR(10) DEFAULT 'en',
  is_active BOOLEAN DEFAULT TRUE,
  is_premium BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_active_at TIMESTAMP NULL,
  INDEX idx_user_id (user_id),
  INDEX idx_email (email),
  INDEX idx_is_active (is_active),
  INDEX idx_last_active (last_active_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User preferences and settings
CREATE TABLE IF NOT EXISTS user_preferences (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  preference_key VARCHAR(100) NOT NULL,
  preference_value TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_user_preference (user_id, preference_key),
  INDEX idx_user_id (user_id),
  INDEX idx_preference_key (preference_key),
  CONSTRAINT fk_user_preferences_user FOREIGN KEY (user_id) REFERENCES chatbot_users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- CHAT SYSTEM TABLES
-- =============================================

-- Chat sessions
CREATE TABLE IF NOT EXISTS chat_sessions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  session_id VARCHAR(36) NOT NULL UNIQUE,
  user_id VARCHAR(64) NOT NULL,
  session_name VARCHAR(120) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ended_at TIMESTAMP NULL,
  message_count INT DEFAULT 0,
  total_tokens_used INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_session_id (session_id),
  INDEX idx_user_id (user_id),
  INDEX idx_is_active (is_active),
  INDEX idx_started_at (started_at),
  CONSTRAINT fk_chat_sessions_user FOREIGN KEY (user_id) REFERENCES chatbot_users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Chat messages
CREATE TABLE IF NOT EXISTS chat_messages (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  session_id VARCHAR(36) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  message_type ENUM('user', 'bot', 'system') NOT NULL,
  message_content TEXT NOT NULL,
  message_tokens INT DEFAULT 0,
  response_time_ms INT DEFAULT 0,
  sentiment_score DECIMAL(3,2) NULL,
  intent_category VARCHAR(100) NULL,
  confidence_score DECIMAL(3,2) NULL,
  is_helpful BOOLEAN NULL,
  user_rating TINYINT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_session_id (session_id),
  INDEX idx_user_id (user_id),
  INDEX idx_message_type (message_type),
  INDEX idx_created_at (created_at),
  INDEX idx_intent_category (intent_category),
  CONSTRAINT fk_chat_messages_session FOREIGN KEY (session_id) REFERENCES chat_sessions(session_id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_messages_user FOREIGN KEY (user_id) REFERENCES chatbot_users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- AI knowledge base (for dynamic responses)
CREATE TABLE IF NOT EXISTS ai_knowledge_base (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  category VARCHAR(100) NOT NULL,
  question_patterns JSON NOT NULL,
  response_template TEXT NOT NULL,
  keywords JSON NOT NULL,
  priority INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  usage_count INT DEFAULT 0,
  success_rate DECIMAL(3,2) DEFAULT 0.00,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_category (category),
  INDEX idx_is_active (is_active),
  INDEX idx_priority (priority),
  INDEX idx_usage_count (usage_count)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- ANALYTICS & TRACKING TABLES
-- =============================================

-- User activity tracking
CREATE TABLE IF NOT EXISTS user_activity_log (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  activity_type VARCHAR(50) NOT NULL,
  activity_data JSON NULL,
  ip_address VARCHAR(45) NULL,
  user_agent TEXT NULL,
  session_id VARCHAR(36) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_activity_type (activity_type),
  INDEX idx_created_at (created_at),
  INDEX idx_session_id (session_id),
  CONSTRAINT fk_activity_log_user FOREIGN KEY (user_id) REFERENCES chatbot_users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Chat analytics
CREATE TABLE IF NOT EXISTS chat_analytics (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  date DATE NOT NULL,
  total_sessions INT DEFAULT 0,
  total_messages INT DEFAULT 0,
  unique_users INT DEFAULT 0,
  avg_session_duration INT DEFAULT 0,
  avg_messages_per_session DECIMAL(5,2) DEFAULT 0.00,
  most_common_intent VARCHAR(100) NULL,
  satisfaction_score DECIMAL(3,2) DEFAULT 0.00,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_date (date),
  INDEX idx_date (date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Intent tracking
CREATE TABLE IF NOT EXISTS intent_tracking (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  intent_name VARCHAR(100) NOT NULL,
  intent_category VARCHAR(50) NOT NULL,
  trigger_count INT DEFAULT 0,
  success_count INT DEFAULT 0,
  avg_confidence DECIMAL(3,2) DEFAULT 0.00,
  last_triggered_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_intent (intent_name),
  INDEX idx_intent_category (intent_category),
  INDEX idx_trigger_count (trigger_count)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- FEEDBACK & RATINGS TABLES
-- =============================================

-- User feedback
CREATE TABLE IF NOT EXISTS user_feedback (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  session_id VARCHAR(36) NULL,
  message_id BIGINT UNSIGNED NULL,
  feedback_type ENUM('positive', 'negative', 'neutral') NOT NULL,
  feedback_text TEXT NULL,
  rating TINYINT NULL,
  is_resolved BOOLEAN DEFAULT FALSE,
  admin_notes TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_feedback_type (feedback_type),
  INDEX idx_created_at (created_at),
  CONSTRAINT fk_feedback_user FOREIGN KEY (user_id) REFERENCES chatbot_users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_feedback_message FOREIGN KEY (message_id) REFERENCES chat_messages(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- VIEWS FOR ANALYTICS
-- =============================================

-- User chat summary
CREATE OR REPLACE VIEW v_user_chat_summary AS
SELECT 
  u.user_id,
  u.display_name,
  u.email,
  COUNT(DISTINCT s.id) as total_sessions,
  COUNT(m.id) as total_messages,
  MAX(s.started_at) as last_chat_at,
  AVG(m.response_time_ms) as avg_response_time,
  AVG(m.user_rating) as avg_rating
FROM chatbot_users u
LEFT JOIN chat_sessions s ON u.user_id = s.user_id
LEFT JOIN chat_messages m ON s.session_id = m.session_id
GROUP BY u.user_id, u.display_name, u.email;

-- Daily chat analytics
CREATE OR REPLACE VIEW v_daily_chat_analytics AS
SELECT 
  DATE(s.started_at) as date,
  COUNT(DISTINCT s.id) as sessions,
  COUNT(m.id) as messages,
  COUNT(DISTINCT s.user_id) as unique_users,
  AVG(TIMESTAMPDIFF(SECOND, s.started_at, COALESCE(s.ended_at, NOW()))) as avg_session_duration,
  AVG(m.user_rating) as avg_satisfaction
FROM chat_sessions s
LEFT JOIN chat_messages m ON s.session_id = m.session_id
GROUP BY DATE(s.started_at)
ORDER BY date DESC;

-- Intent performance
CREATE OR REPLACE VIEW v_intent_performance AS
SELECT 
  m.intent_category,
  COUNT(*) as total_occurrences,
  AVG(m.confidence_score) as avg_confidence,
  AVG(m.user_rating) as avg_rating,
  COUNT(CASE WHEN m.is_helpful = TRUE THEN 1 END) as helpful_count,
  (COUNT(CASE WHEN m.is_helpful = TRUE THEN 1 END) / COUNT(*)) * 100 as helpful_percentage
FROM chat_messages m
WHERE m.intent_category IS NOT NULL
GROUP BY m.intent_category
ORDER BY total_occurrences DESC;

-- =============================================
-- STORED PROCEDURES
-- =============================================

-- Create or update user
DELIMITER //
CREATE PROCEDURE CreateOrUpdateUser(
  IN p_user_id VARCHAR(64),
  IN p_email VARCHAR(190),
  IN p_display_name VARCHAR(120),
  IN p_first_name VARCHAR(60),
  IN p_last_name VARCHAR(60),
  IN p_phone VARCHAR(20)
)
BEGIN
  INSERT INTO chatbot_users (user_id, email, display_name, first_name, last_name, phone)
  VALUES (p_user_id, p_email, p_display_name, p_first_name, p_last_name, p_phone)
  ON DUPLICATE KEY UPDATE
    email = COALESCE(p_email, email),
    display_name = COALESCE(p_display_name, display_name),
    first_name = COALESCE(p_first_name, first_name),
    last_name = COALESCE(p_last_name, last_name),
    phone = COALESCE(p_phone, phone),
    last_active_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP;
END //
DELIMITER ;

-- Start new chat session
DELIMITER //
CREATE PROCEDURE StartChatSession(
  IN p_user_id VARCHAR(64),
  IN p_session_name VARCHAR(120)
)
BEGIN
  DECLARE v_session_id VARCHAR(36);
  SET v_session_id = UUID();
  
  INSERT INTO chat_sessions (session_id, user_id, session_name)
  VALUES (v_session_id, p_user_id, p_session_name);
  
  SELECT v_session_id as session_id;
END //
DELIMITER ;

-- Add chat message
DELIMITER //
CREATE PROCEDURE AddChatMessage(
  IN p_session_id VARCHAR(36),
  IN p_user_id VARCHAR(64),
  IN p_message_type ENUM('user', 'bot', 'system'),
  IN p_message_content TEXT,
  IN p_intent_category VARCHAR(100),
  IN p_confidence_score DECIMAL(3,2)
)
BEGIN
  DECLARE v_message_id BIGINT UNSIGNED;
  
  INSERT INTO chat_messages (session_id, user_id, message_type, message_content, intent_category, confidence_score)
  VALUES (p_session_id, p_user_id, p_message_type, p_message_content, p_intent_category, p_confidence_score);
  
  SET v_message_id = LAST_INSERT_ID();
  
  -- Update session message count
  UPDATE chat_sessions 
  SET message_count = message_count + 1,
      updated_at = CURRENT_TIMESTAMP
  WHERE session_id = p_session_id;
  
  -- Update intent tracking
  IF p_intent_category IS NOT NULL THEN
    INSERT INTO intent_tracking (intent_name, intent_category, trigger_count, last_triggered_at)
    VALUES (p_intent_category, p_intent_category, 1, CURRENT_TIMESTAMP)
    ON DUPLICATE KEY UPDATE
      trigger_count = trigger_count + 1,
      last_triggered_at = CURRENT_TIMESTAMP,
      updated_at = CURRENT_TIMESTAMP;
  END IF;
  
  SELECT v_message_id as message_id;
END //
DELIMITER ;

-- =============================================
-- SAMPLE DATA
-- =============================================

-- Insert sample users
INSERT INTO chatbot_users (user_id, email, display_name, first_name, last_name, is_premium) VALUES
('user1', 'ava@example.com', 'Ava', 'Ava', 'Smith', TRUE),
('user2', 'liam@example.com', 'Liam', 'Liam', 'Johnson', FALSE),
('user3', 'noah@example.com', 'Noah', 'Noah', 'Williams', FALSE),
('guest', 'guest@local', 'Guest User', 'Guest', 'User', FALSE)
ON DUPLICATE KEY UPDATE user_id = user_id;

-- Insert AI knowledge base
INSERT INTO ai_knowledge_base (category, question_patterns, response_template, keywords, priority) VALUES
('earn_points', '["how to earn points", "earning points", "get points", "point system"]', 'You can earn eco-points by scanning waste items with our AI camera! Here''s how:\n\n• Plastic items: 10 points\n• Paper items: 5 points\n• Steel/Metal items: 15 points\n• Organic waste: 8 points\n\nJust tap "Deposit Waste" in the app and point your camera at recyclable items!', '["points", "earn", "scoring", "rewards"]', 10),
('recycling', '["what can I recycle", "recycling guide", "recyclable items", "waste types"]', 'Great question! Here''s what you can recycle with EcoWaste:\n\n♻️ **Plastic**: Bottles, cups, containers\n📄 **Paper**: Books, newspapers, cardboard\n🔧 **Steel/Metal**: Cans, utensils, electronics\n🍎 **Organic**: Food scraps, fruit peels, vegetables\n\nOur AI can detect these automatically when you scan them!', '["recycle", "recycling", "what can", "materials", "waste types"]', 10),
('ai_detection', '["how does AI work", "camera detection", "scanning technology", "AI system"]', 'Our AI uses advanced computer vision to identify waste items! Here''s how it works:\n\n🤖 **TensorFlow.js**: Real-time object detection\n📱 **Camera Integration**: Uses your phone''s camera\n🎯 **Smart Classification**: Maps items to waste categories\n⚡ **Instant Results**: Get points immediately\n\nJust point and scan - it''s that simple!', '["ai", "detection", "how does", "camera", "scanning", "technology"]', 9),
('rewards', '["rewards", "redeem points", "prizes", "offers"]', 'Redeem your eco-points for amazing rewards! 🎁\n\n💰 **₹50 Off Eco Store** - 100 points\n☕ **Free Coffee** - 80 points\n🚌 **Bus Ticket 50% Off** - 120 points\n🌱 **Plant Sapling** - 60 points\n\nCheck the "Rewards" section in the app to redeem!', '["rewards", "redeem", "prizes", "gifts", "offers"]', 8),
('environment', '["environment", "planet", "sustainability", "green living"]', 'Every small action counts for our planet! 🌍\n\n• Recycling reduces landfill waste\n• Proper sorting helps processing\n• Eco-points encourage good habits\n• Together we make a difference\n\nKeep up the great work! Every item you recycle helps protect our environment.', '["environment", "planet", "earth", "sustainability", "green", "eco"]', 7)
ON DUPLICATE KEY UPDATE category = VALUES(category);

-- =============================================
-- VERIFICATION QUERIES
-- =============================================

-- Check if everything was created successfully
SELECT 'EcoWaste Chatbot database setup complete!' AS status;

-- Show table counts
SELECT 
  'chatbot_users' AS table_name, COUNT(*) AS count FROM chatbot_users
UNION ALL
SELECT 'chat_sessions', COUNT(*) FROM chat_sessions
UNION ALL
SELECT 'chat_messages', COUNT(*) FROM chat_messages
UNION ALL
SELECT 'ai_knowledge_base', COUNT(*) FROM ai_knowledge_base
UNION ALL
SELECT 'user_activity_log', COUNT(*) FROM user_activity_log
UNION ALL
SELECT 'chat_analytics', COUNT(*) FROM chat_analytics
UNION ALL
SELECT 'intent_tracking', COUNT(*) FROM intent_tracking
UNION ALL
SELECT 'user_feedback', COUNT(*) FROM user_feedback;

-- Show sample data
SELECT 'Sample users:' AS info;
SELECT user_id, display_name, email, is_premium FROM chatbot_users LIMIT 5;

SELECT 'Sample knowledge base:' AS info;
SELECT category, priority FROM ai_knowledge_base ORDER BY priority DESC;
