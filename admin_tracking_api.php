<?php
/**
 * EcoWaste Admin Tracking API
 * Comprehensive tracking of all admin activities, analytics, and monitoring
 */

declare(strict_types=1);
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Admin-Session');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/backend/db.php';

// Get request method and path
$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$pathParts = explode('/', trim($path, '/'));

// Authentication middleware
function authenticateAdmin() {
    global $mysqli;
    
    $sessionToken = $_SERVER['HTTP_X_ADMIN_SESSION'] ?? '';
    if (!$sessionToken) {
        throw new Exception('Admin session token required');
    }
    
    $stmt = $mysqli->prepare("
        SELECT s.id, s.admin_id, s.is_active, a.username, a.display_name 
        FROM admin_sessions s 
        JOIN admins a ON s.admin_id = a.id 
        WHERE s.session_token = ? AND s.is_active = 1
    ");
    $stmt->bind_param('s', $sessionToken);
    $stmt->execute();
    $result = $stmt->get_result();
    $session = $result->fetch_assoc();
    $stmt->close();
    
    if (!$session) {
        throw new Exception('Invalid or expired session');
    }
    
    return $session;
}

// Get client information
function getClientInfo() {
    return [
        'ip_address' => $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown',
        'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown',
        'request_method' => $_SERVER['REQUEST_METHOD'],
        'request_url' => $_SERVER['REQUEST_URI'] ?? '',
    ];
}

// Track admin activity
function trackActivity($adminId, $sessionId, $activityType, $activityCategory, $description, $targetResource = null, $targetId = null, $oldValues = null, $newValues = null, $additionalData = null) {
    global $mysqli;
    
    $clientInfo = getClientInfo();
    $executionTime = microtime(true) - ($_SERVER['REQUEST_TIME_FLOAT'] ?? microtime(true));
    
    $stmt = $mysqli->prepare("CALL TrackAdminActivity(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param(
        'iissssssssssiis',
        $adminId, $sessionId, $activityType, $activityCategory, $description,
        $targetResource, $targetId, 
        $oldValues ? json_encode($oldValues) : null,
        $newValues ? json_encode($newValues) : null,
        $clientInfo['ip_address'], $clientInfo['user_agent'],
        $clientInfo['request_method'], $clientInfo['request_url'],
        200, // Default success status
        intval($executionTime * 1000),
        $additionalData ? json_encode($additionalData) : null
    );
    $stmt->execute();
    $stmt->close();
}

// Route handling
try {
    switch ($method) {
        case 'POST':
            if (isset($pathParts[1]) && $pathParts[1] === 'login') {
                handleAdminLogin();
            } elseif (isset($pathParts[1]) && $pathParts[1] === 'logout') {
                handleAdminLogout();
            } elseif (isset($pathParts[1]) && $pathParts[1] === 'activity') {
                handleActivityTracking();
            } elseif (isset($pathParts[1]) && $pathParts[1] === 'page-visit') {
                handlePageVisit();
            } elseif (isset($pathParts[1]) && $pathParts[1] === 'security-event') {
                handleSecurityEvent();
            } else {
                throw new Exception('Invalid endpoint');
            }
            break;
            
        case 'GET':
            if (isset($pathParts[1]) && $pathParts[1] === 'analytics') {
                handleAnalytics();
            } elseif (isset($pathParts[1]) && $pathParts[1] === 'sessions') {
                handleSessions();
            } elseif (isset($pathParts[1]) && $pathParts[1] === 'activities') {
                handleActivities();
            } elseif (isset($pathParts[1]) && $pathParts[1] === 'security-events') {
                handleSecurityEvents();
            } elseif (isset($pathParts[1]) && $pathParts[1] === 'performance') {
                handlePerformance();
            } else {
                throw new Exception('Invalid endpoint');
            }
            break;
            
        default:
            throw new Exception('Method not allowed');
    }
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
}

/**
 * Handle admin login tracking
 */
function handleAdminLogin() {
    global $mysqli;
    
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input || !isset($input['admin_id'])) {
        throw new Exception('Admin ID required');
    }
    
    $adminId = $input['admin_id'];
    $clientInfo = getClientInfo();
    
    // Track login
    $stmt = $mysqli->prepare("CALL TrackAdminLogin(?, ?, ?)");
    $stmt->bind_param('iss', $adminId, $clientInfo['ip_address'], $clientInfo['user_agent']);
    $stmt->execute();
    $result = $stmt->get_result();
    $sessionData = $result->fetch_assoc();
    $stmt->close();
    
    echo json_encode([
        'success' => true,
        'session_id' => $sessionData['session_id'],
        'session_token' => $sessionData['session_token']
    ]);
}

/**
 * Handle admin logout tracking
 */
function handleAdminLogout() {
    global $mysqli;
    
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input || !isset($input['session_id']) || !isset($input['admin_id'])) {
        throw new Exception('Session ID and Admin ID required');
    }
    
    $sessionId = $input['session_id'];
    $adminId = $input['admin_id'];
    
    $stmt = $mysqli->prepare("CALL TrackAdminLogout(?, ?)");
    $stmt->bind_param('ii', $sessionId, $adminId);
    $stmt->execute();
    $stmt->close();
    
    echo json_encode(['success' => true, 'message' => 'Logout tracked successfully']);
}

/**
 * Handle activity tracking
 */
function handleActivityTracking() {
    $session = authenticateAdmin();
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input || !isset($input['activity_type']) || !isset($input['activity_category']) || !isset($input['description'])) {
        throw new Exception('Activity type, category, and description required');
    }
    
    trackActivity(
        $session['admin_id'],
        $session['id'],
        $input['activity_type'],
        $input['activity_category'],
        $input['description'],
        $input['target_resource'] ?? null,
        $input['target_id'] ?? null,
        $input['old_values'] ?? null,
        $input['new_values'] ?? null,
        $input['additional_data'] ?? null
    );
    
    echo json_encode(['success' => true, 'message' => 'Activity tracked successfully']);
}

/**
 * Handle page visit tracking
 */
function handlePageVisit() {
    $session = authenticateAdmin();
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input || !isset($input['page_name']) || !isset($input['page_url'])) {
        throw new Exception('Page name and URL required');
    }
    
    global $mysqli;
    $clientInfo = getClientInfo();
    
    $stmt = $mysqli->prepare("
        INSERT INTO admin_page_visits 
        (admin_id, session_id, page_name, page_url, visit_duration, referrer_url, ip_address, user_agent, screen_resolution, browser_name, browser_version, os_name, device_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    
    $visitDuration = $input['visit_duration'] ?? 0;
    $referrerUrl = $input['referrer_url'] ?? null;
    $screenResolution = $input['screen_resolution'] ?? null;
    $browserName = $input['browser_name'] ?? null;
    $browserVersion = $input['browser_version'] ?? null;
    $osName = $input['os_name'] ?? null;
    $deviceType = $input['device_type'] ?? null;
    
    $stmt->bind_param(
        'iisissssssss',
        $session['admin_id'], $session['id'], $input['page_name'], $input['page_url'],
        $visitDuration, $referrerUrl, $clientInfo['ip_address'], $clientInfo['user_agent'],
        $screenResolution, $browserName, $browserVersion, $osName, $deviceType
    );
    $stmt->execute();
    $stmt->close();
    
    echo json_encode(['success' => true, 'message' => 'Page visit tracked successfully']);
}

/**
 * Handle security event tracking
 */
function handleSecurityEvent() {
    global $mysqli;
    
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input || !isset($input['event_type']) || !isset($input['event_severity']) || !isset($input['event_description'])) {
        throw new Exception('Event type, severity, and description required');
    }
    
    $clientInfo = getClientInfo();
    $adminId = $input['admin_id'] ?? null;
    
    $stmt = $mysqli->prepare("
        INSERT INTO admin_security_events 
        (admin_id, event_type, event_severity, event_description, ip_address, user_agent, additional_data)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");
    
    $additionalData = $input['additional_data'] ? json_encode($input['additional_data']) : null;
    
    $stmt->bind_param(
        'issssss',
        $adminId, $input['event_type'], $input['event_severity'], $input['event_description'],
        $clientInfo['ip_address'], $clientInfo['user_agent'], $additionalData
    );
    $stmt->execute();
    $stmt->close();
    
    echo json_encode(['success' => true, 'message' => 'Security event tracked successfully']);
}

/**
 * Handle analytics requests
 */
function handleAnalytics() {
    global $mysqli;
    
    $type = $_GET['type'] ?? 'summary';
    $date = $_GET['date'] ?? date('Y-m-d');
    $adminId = $_GET['admin_id'] ?? null;
    
    switch ($type) {
        case 'summary':
            getAnalyticsSummary($date);
            break;
        case 'daily':
            getDailyAnalytics($date);
            break;
        case 'admin':
            getAdminAnalytics($adminId, $date);
            break;
        case 'security':
            getSecurityAnalytics($date);
            break;
        case 'performance':
            getPerformanceAnalytics($date);
            break;
        default:
            throw new Exception('Invalid analytics type');
    }
}

/**
 * Get analytics summary
 */
function getAnalyticsSummary($date) {
    global $mysqli;
    
    $queries = [
        'total_sessions' => "SELECT COUNT(*) as count FROM admin_sessions WHERE DATE(login_time) = ?",
        'active_sessions' => "SELECT COUNT(*) as count FROM admin_sessions WHERE DATE(login_time) = ? AND is_active = 1",
        'total_activities' => "SELECT COUNT(*) as count FROM admin_activity_log WHERE DATE(created_at) = ?",
        'total_page_views' => "SELECT COUNT(*) as count FROM admin_page_visits WHERE DATE(created_at) = ?",
        'security_events' => "SELECT COUNT(*) as count FROM admin_security_events WHERE DATE(created_at) = ?",
        'unique_admins' => "SELECT COUNT(DISTINCT admin_id) as count FROM admin_activity_log WHERE DATE(created_at) = ?"
    ];
    
    $results = [];
    foreach ($queries as $key => $query) {
        $stmt = $mysqli->prepare($query);
        $stmt->bind_param('s', $date);
        $stmt->execute();
        $result = $stmt->get_result();
        $data = $result->fetch_assoc();
        $results[$key] = $data['count'] ?? 0;
        $stmt->close();
    }
    
    echo json_encode(['success' => true, 'analytics' => $results, 'date' => $date]);
}

/**
 * Get daily analytics
 */
function getDailyAnalytics($date) {
    global $mysqli;
    
    $days = $_GET['days'] ?? 7;
    
    $stmt = $mysqli->prepare("
        SELECT 
            DATE(created_at) as date,
            COUNT(*) as total_activities,
            COUNT(DISTINCT admin_id) as unique_admins,
            COUNT(DISTINCT activity_type) as unique_activity_types,
            AVG(execution_time_ms) as avg_execution_time
        FROM admin_activity_log 
        WHERE created_at >= DATE_SUB(?, INTERVAL ? DAY)
        GROUP BY DATE(created_at)
        ORDER BY date DESC
    ");
    $stmt->bind_param('si', $date, $days);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    $stmt->close();
    
    echo json_encode(['success' => true, 'daily_analytics' => $data]);
}

/**
 * Get admin-specific analytics
 */
function getAdminAnalytics($adminId, $date) {
    global $mysqli;
    
    if (!$adminId) {
        throw new Exception('Admin ID required');
    }
    
    $stmt = $mysqli->prepare("
        SELECT 
            a.username,
            a.display_name,
            COUNT(DISTINCT s.id) as total_sessions,
            COUNT(al.id) as total_activities,
            AVG(s.session_duration) as avg_session_duration,
            COUNT(DISTINCT al.activity_type) as unique_activity_types,
            MAX(s.login_time) as last_login
        FROM admins a
        LEFT JOIN admin_sessions s ON a.id = s.admin_id AND DATE(s.login_time) = ?
        LEFT JOIN admin_activity_log al ON a.id = al.admin_id AND DATE(al.created_at) = ?
        WHERE a.id = ?
        GROUP BY a.id, a.username, a.display_name
    ");
    $stmt->bind_param('ssi', $date, $date, $adminId);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = $result->fetch_assoc();
    $stmt->close();
    
    echo json_encode(['success' => true, 'admin_analytics' => $data]);
}

/**
 * Get security analytics
 */
function getSecurityAnalytics($date) {
    global $mysqli;
    
    $stmt = $mysqli->prepare("
        SELECT 
            event_type,
            event_severity,
            COUNT(*) as event_count,
            COUNT(CASE WHEN is_resolved = TRUE THEN 1 END) as resolved_count,
            COUNT(CASE WHEN is_resolved = FALSE THEN 1 END) as pending_count
        FROM admin_security_events 
        WHERE DATE(created_at) = ?
        GROUP BY event_type, event_severity
        ORDER BY event_count DESC
    ");
    $stmt->bind_param('s', $date);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    $stmt->close();
    
    echo json_encode(['success' => true, 'security_analytics' => $data]);
}

/**
 * Get performance analytics
 */
function getPerformanceAnalytics($date) {
    global $mysqli;
    
    $stmt = $mysqli->prepare("
        SELECT 
            a.username,
            a.display_name,
            pm.total_activities,
            pm.total_login_time,
            pm.avg_session_duration,
            pm.success_rate,
            pm.error_count
        FROM admin_performance_metrics pm
        JOIN admins a ON pm.admin_id = a.id
        WHERE pm.date = ?
        ORDER BY pm.total_activities DESC
    ");
    $stmt->bind_param('s', $date);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    $stmt->close();
    
    echo json_encode(['success' => true, 'performance_analytics' => $data]);
}

/**
 * Handle sessions requests
 */
function handleSessions() {
    global $mysqli;
    
    $adminId = $_GET['admin_id'] ?? null;
    $active = $_GET['active'] ?? null;
    $limit = $_GET['limit'] ?? 50;
    
    $whereClause = "1=1";
    $params = [];
    $types = "";
    
    if ($adminId) {
        $whereClause .= " AND s.admin_id = ?";
        $params[] = $adminId;
        $types .= "i";
    }
    
    if ($active !== null) {
        $whereClause .= " AND s.is_active = ?";
        $params[] = $active ? 1 : 0;
        $types .= "i";
    }
    
    $stmt = $mysqli->prepare("
        SELECT 
            s.id, s.admin_id, s.session_token, s.ip_address, s.login_time, s.logout_time,
            s.is_active, s.session_duration, a.username, a.display_name
        FROM admin_sessions s
        JOIN admins a ON s.admin_id = a.id
        WHERE $whereClause
        ORDER BY s.login_time DESC
        LIMIT ?
    ");
    
    $params[] = $limit;
    $types .= "i";
    
    if ($params) {
        $stmt->bind_param($types, ...$params);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    $stmt->close();
    
    echo json_encode(['success' => true, 'sessions' => $data]);
}

/**
 * Handle activities requests
 */
function handleActivities() {
    global $mysqli;
    
    $adminId = $_GET['admin_id'] ?? null;
    $activityType = $_GET['activity_type'] ?? null;
    $limit = $_GET['limit'] ?? 100;
    
    $whereClause = "1=1";
    $params = [];
    $types = "";
    
    if ($adminId) {
        $whereClause .= " AND al.admin_id = ?";
        $params[] = $adminId;
        $types .= "i";
    }
    
    if ($activityType) {
        $whereClause .= " AND al.activity_type = ?";
        $params[] = $activityType;
        $types .= "s";
    }
    
    $stmt = $mysqli->prepare("
        SELECT 
            al.id, al.admin_id, al.activity_type, al.activity_category, al.activity_description,
            al.target_resource, al.target_id, al.ip_address, al.created_at, al.execution_time_ms,
            a.username, a.display_name
        FROM admin_activity_log al
        JOIN admins a ON al.admin_id = a.id
        WHERE $whereClause
        ORDER BY al.created_at DESC
        LIMIT ?
    ");
    
    $params[] = $limit;
    $types .= "i";
    
    if ($params) {
        $stmt->bind_param($types, ...$params);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    $stmt->close();
    
    echo json_encode(['success' => true, 'activities' => $data]);
}

/**
 * Handle security events requests
 */
function handleSecurityEvents() {
    global $mysqli;
    
    $severity = $_GET['severity'] ?? null;
    $resolved = $_GET['resolved'] ?? null;
    $limit = $_GET['limit'] ?? 100;
    
    $whereClause = "1=1";
    $params = [];
    $types = "";
    
    if ($severity) {
        $whereClause .= " AND event_severity = ?";
        $params[] = $severity;
        $types .= "s";
    }
    
    if ($resolved !== null) {
        $whereClause .= " AND is_resolved = ?";
        $params[] = $resolved ? 1 : 0;
        $types .= "i";
    }
    
    $stmt = $mysqli->prepare("
        SELECT 
            id, admin_id, event_type, event_severity, event_description,
            ip_address, is_resolved, created_at, resolved_at
        FROM admin_security_events
        WHERE $whereClause
        ORDER BY created_at DESC
        LIMIT ?
    ");
    
    $params[] = $limit;
    $types .= "i";
    
    if ($params) {
        $stmt->bind_param($types, ...$params);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    $stmt->close();
    
    echo json_encode(['success' => true, 'security_events' => $data]);
}

/**
 * Handle performance requests
 */
function handlePerformance() {
    global $mysqli;
    
    $adminId = $_GET['admin_id'] ?? null;
    $date = $_GET['date'] ?? date('Y-m-d');
    
    $whereClause = "pm.date = ?";
    $params = [$date];
    $types = "s";
    
    if ($adminId) {
        $whereClause .= " AND pm.admin_id = ?";
        $params[] = $adminId;
        $types .= "i";
    }
    
    $stmt = $mysqli->prepare("
        SELECT 
            pm.admin_id, a.username, a.display_name, pm.date,
            pm.total_login_time, pm.total_activities, pm.total_page_views,
            pm.avg_session_duration, pm.success_rate, pm.error_count
        FROM admin_performance_metrics pm
        JOIN admins a ON pm.admin_id = a.id
        WHERE $whereClause
        ORDER BY pm.total_activities DESC
    ");
    
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    $stmt->close();
    
    echo json_encode(['success' => true, 'performance' => $data]);
}
?>
