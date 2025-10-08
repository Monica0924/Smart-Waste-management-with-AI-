<?php
/**
 * EcoWaste Admin Analytics Reports
 * Generate comprehensive reports and analytics
 */

declare(strict_types=1);
session_start();
require_once __DIR__ . '/backend/db.php';

// Check if admin is logged in
if (!isset($_SESSION['admin_id'])) {
    header('Location: /admin/login.php');
    exit;
}

$adminId = $_SESSION['admin_id'];
$reportType = $_GET['type'] ?? 'overview';
$dateRange = $_GET['range'] ?? '7d';
$format = $_GET['format'] ?? 'html';

// Parse date range
function parseDateRange($range) {
    $endDate = date('Y-m-d');
    switch ($range) {
        case '1d':
            $startDate = date('Y-m-d', strtotime('-1 day'));
            break;
        case '7d':
            $startDate = date('Y-m-d', strtotime('-7 days'));
            break;
        case '30d':
            $startDate = date('Y-m-d', strtotime('-30 days'));
            break;
        case '90d':
            $startDate = date('Y-m-d', strtotime('-90 days'));
            break;
        case '1y':
            $startDate = date('Y-m-d', strtotime('-1 year'));
            break;
        default:
            $startDate = date('Y-m-d', strtotime('-7 days'));
    }
    return [$startDate, $endDate];
}

[$startDate, $endDate] = parseDateRange($dateRange);

// Generate report data
function generateReport($mysqli, $reportType, $startDate, $endDate) {
    switch ($reportType) {
        case 'overview':
            return generateOverviewReport($mysqli, $startDate, $endDate);
        case 'admin_activity':
            return generateAdminActivityReport($mysqli, $startDate, $endDate);
        case 'security':
            return generateSecurityReport($mysqli, $startDate, $endDate);
        case 'performance':
            return generatePerformanceReport($mysqli, $startDate, $endDate);
        case 'feature_usage':
            return generateFeatureUsageReport($mysqli, $startDate, $endDate);
        case 'system_health':
            return generateSystemHealthReport($mysqli, $startDate, $endDate);
        default:
            throw new Exception('Invalid report type');
    }
}

function generateOverviewReport($mysqli, $startDate, $endDate) {
    $queries = [
        'total_sessions' => "SELECT COUNT(*) as count FROM admin_sessions WHERE DATE(login_time) BETWEEN ? AND ?",
        'unique_admins' => "SELECT COUNT(DISTINCT admin_id) as count FROM admin_sessions WHERE DATE(login_time) BETWEEN ? AND ?",
        'total_activities' => "SELECT COUNT(*) as count FROM admin_activity_log WHERE DATE(created_at) BETWEEN ? AND ?",
        'total_page_views' => "SELECT COUNT(*) as count FROM admin_page_visits WHERE DATE(created_at) BETWEEN ? AND ?",
        'security_events' => "SELECT COUNT(*) as count FROM admin_security_events WHERE DATE(created_at) BETWEEN ? AND ?",
        'avg_session_duration' => "SELECT AVG(session_duration) as avg_duration FROM admin_sessions WHERE DATE(login_time) BETWEEN ? AND ? AND session_duration > 0",
        'most_active_admin' => "SELECT a.username, COUNT(al.id) as activity_count FROM admin_activity_log al JOIN admins a ON al.admin_id = a.id WHERE DATE(al.created_at) BETWEEN ? AND ? GROUP BY al.admin_id, a.username ORDER BY activity_count DESC LIMIT 1",
        'most_used_feature' => "SELECT feature_name, SUM(usage_count) as total_usage FROM feature_usage_tracking WHERE DATE(last_used_at) BETWEEN ? AND ? GROUP BY feature_name ORDER BY total_usage DESC LIMIT 1"
    ];
    
    $results = [];
    foreach ($queries as $key => $query) {
        $stmt = $mysqli->prepare($query);
        $stmt->bind_param('ss', $startDate, $endDate);
        $stmt->execute();
        $result = $stmt->get_result();
        $data = $result->fetch_assoc();
        $results[$key] = $data;
        $stmt->close();
    }
    
    return $results;
}

function generateAdminActivityReport($mysqli, $startDate, $endDate) {
    // Daily activity trends
    $stmt = $mysqli->prepare("
        SELECT 
            DATE(created_at) as date,
            COUNT(*) as total_activities,
            COUNT(DISTINCT admin_id) as unique_admins,
            COUNT(DISTINCT activity_type) as unique_activity_types,
            AVG(execution_time_ms) as avg_execution_time
        FROM admin_activity_log 
        WHERE DATE(created_at) BETWEEN ? AND ?
        GROUP BY DATE(created_at)
        ORDER BY date ASC
    ");
    $stmt->bind_param('ss', $startDate, $endDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $dailyTrends = [];
    while ($row = $result->fetch_assoc()) {
        $dailyTrends[] = $row;
    }
    $stmt->close();
    
    // Activity type breakdown
    $stmt = $mysqli->prepare("
        SELECT 
            activity_type,
            activity_category,
            COUNT(*) as count,
            AVG(execution_time_ms) as avg_execution_time
        FROM admin_activity_log 
        WHERE DATE(created_at) BETWEEN ? AND ?
        GROUP BY activity_type, activity_category
        ORDER BY count DESC
    ");
    $stmt->bind_param('ss', $startDate, $endDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $activityBreakdown = [];
    while ($row = $result->fetch_assoc()) {
        $activityBreakdown[] = $row;
    }
    $stmt->close();
    
    // Admin activity summary
    $stmt = $mysqli->prepare("
        SELECT 
            a.username,
            a.display_name,
            COUNT(al.id) as total_activities,
            COUNT(DISTINCT DATE(al.created_at)) as active_days,
            AVG(al.execution_time_ms) as avg_execution_time,
            COUNT(CASE WHEN al.response_status >= 200 AND al.response_status < 300 THEN 1 END) as success_count,
            COUNT(CASE WHEN al.response_status >= 400 THEN 1 END) as error_count
        FROM admin_activity_log al
        JOIN admins a ON al.admin_id = a.id
        WHERE DATE(al.created_at) BETWEEN ? AND ?
        GROUP BY al.admin_id, a.username, a.display_name
        ORDER BY total_activities DESC
    ");
    $stmt->bind_param('ss', $startDate, $endDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $adminSummary = [];
    while ($row = $result->fetch_assoc()) {
        $row['success_rate'] = $row['total_activities'] > 0 ? 
            round(($row['success_count'] / $row['total_activities']) * 100, 2) : 0;
        $adminSummary[] = $row;
    }
    $stmt->close();
    
    return [
        'daily_trends' => $dailyTrends,
        'activity_breakdown' => $activityBreakdown,
        'admin_summary' => $adminSummary
    ];
}

function generateSecurityReport($mysqli, $startDate, $endDate) {
    // Security events by type and severity
    $stmt = $mysqli->prepare("
        SELECT 
            event_type,
            event_severity,
            COUNT(*) as event_count,
            COUNT(CASE WHEN is_resolved = TRUE THEN 1 END) as resolved_count,
            COUNT(CASE WHEN is_resolved = FALSE THEN 1 END) as pending_count
        FROM admin_security_events 
        WHERE DATE(created_at) BETWEEN ? AND ?
        GROUP BY event_type, event_severity
        ORDER BY event_count DESC
    ");
    $stmt->bind_param('ss', $startDate, $endDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $securityEvents = [];
    while ($row = $result->fetch_assoc()) {
        $securityEvents[] = $row;
    }
    $stmt->close();
    
    // Recent security events
    $stmt = $mysqli->prepare("
        SELECT 
            id, event_type, event_severity, event_description,
            ip_address, is_resolved, created_at, resolved_at
        FROM admin_security_events 
        WHERE DATE(created_at) BETWEEN ? AND ?
        ORDER BY created_at DESC
        LIMIT 50
    ");
    $stmt->bind_param('ss', $startDate, $endDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $recentEvents = [];
    while ($row = $result->fetch_assoc()) {
        $recentEvents[] = $row;
    }
    $stmt->close();
    
    // Security trends by day
    $stmt = $mysqli->prepare("
        SELECT 
            DATE(created_at) as date,
            COUNT(*) as total_events,
            COUNT(CASE WHEN event_severity = 'CRITICAL' THEN 1 END) as critical_events,
            COUNT(CASE WHEN event_severity = 'HIGH' THEN 1 END) as high_events,
            COUNT(CASE WHEN is_resolved = TRUE THEN 1 END) as resolved_events
        FROM admin_security_events 
        WHERE DATE(created_at) BETWEEN ? AND ?
        GROUP BY DATE(created_at)
        ORDER BY date ASC
    ");
    $stmt->bind_param('ss', $startDate, $endDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $securityTrends = [];
    while ($row = $result->fetch_assoc()) {
        $securityTrends[] = $row;
    }
    $stmt->close();
    
    return [
        'security_events' => $securityEvents,
        'recent_events' => $recentEvents,
        'security_trends' => $securityTrends
    ];
}

function generatePerformanceReport($mysqli, $startDate, $endDate) {
    // Admin performance metrics
    $stmt = $mysqli->prepare("
        SELECT 
            a.username,
            a.display_name,
            AVG(pm.total_activities) as avg_activities,
            AVG(pm.total_login_time) as avg_login_time,
            AVG(pm.avg_session_duration) as avg_session_duration,
            AVG(pm.success_rate) as avg_success_rate,
            AVG(pm.error_count) as avg_error_count,
            COUNT(DISTINCT pm.date) as active_days
        FROM admin_performance_metrics pm
        JOIN admins a ON pm.admin_id = a.id
        WHERE pm.date BETWEEN ? AND ?
        GROUP BY pm.admin_id, a.username, a.display_name
        ORDER BY avg_activities DESC
    ");
    $stmt->bind_param('ss', $startDate, $endDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $performance = [];
    while ($row = $result->fetch_assoc()) {
        $performance[] = $row;
    }
    $stmt->close();
    
    // System performance trends
    $stmt = $mysqli->prepare("
        SELECT 
            date,
            total_admin_logins,
            total_activities,
            total_page_views,
            avg_response_time_ms,
            error_rate
        FROM system_usage_stats 
        WHERE date BETWEEN ? AND ?
        ORDER BY date ASC
    ");
    $stmt->bind_param('ss', $startDate, $endDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $systemTrends = [];
    while ($row = $result->fetch_assoc()) {
        $systemTrends[] = $row;
    }
    $stmt->close();
    
    return [
        'admin_performance' => $performance,
        'system_trends' => $systemTrends
    ];
}

function generateFeatureUsageReport($mysqli, $startDate, $endDate) {
    // Feature usage statistics
    $stmt = $mysqli->prepare("
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
        WHERE DATE(last_used_at) BETWEEN ? AND ?
        GROUP BY feature_name, feature_category
        ORDER BY total_usage DESC
    ");
    $stmt->bind_param('ss', $startDate, $endDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $featureUsage = [];
    while ($row = $result->fetch_assoc()) {
        $featureUsage[] = $row;
    }
    $stmt->close();
    
    // Feature usage trends by day
    $stmt = $mysqli->prepare("
        SELECT 
            DATE(last_used_at) as date,
            feature_name,
            SUM(usage_count) as daily_usage
        FROM feature_usage_tracking 
        WHERE DATE(last_used_at) BETWEEN ? AND ?
        GROUP BY DATE(last_used_at), feature_name
        ORDER BY date ASC, daily_usage DESC
    ");
    $stmt->bind_param('ss', $startDate, $endDate);
    $stmt->execute();
    $result = $stmt->get_result();
    $featureTrends = [];
    while ($row = $result->fetch_assoc()) {
        $featureTrends[] = $row;
    }
    $stmt->close();
    
    return [
        'feature_usage' => $featureUsage,
        'feature_trends' => $featureTrends
    ];
}

function generateSystemHealthReport($mysqli, $startDate, $endDate) {
    // System health metrics
    $queries = [
        'avg_response_time' => "SELECT AVG(execution_time_ms) as avg_time FROM admin_activity_log WHERE DATE(created_at) BETWEEN ? AND ?",
        'error_rate' => "SELECT (COUNT(CASE WHEN response_status >= 400 THEN 1 END) / COUNT(*)) * 100 as error_rate FROM admin_activity_log WHERE DATE(created_at) BETWEEN ? AND ?",
        'peak_concurrent_users' => "SELECT MAX(concurrent_users) as peak FROM (SELECT DATE(login_time) as date, COUNT(*) as concurrent_users FROM admin_sessions WHERE DATE(login_time) BETWEEN ? AND ? GROUP BY DATE(login_time)) as daily_users",
        'total_uptime' => "SELECT COUNT(DISTINCT DATE(created_at)) as uptime_days FROM admin_activity_log WHERE DATE(created_at) BETWEEN ? AND ?"
    ];
    
    $healthMetrics = [];
    foreach ($queries as $key => $query) {
        $stmt = $mysqli->prepare($query);
        $stmt->bind_param('ss', $startDate, $endDate);
        $stmt->execute();
        $result = $stmt->get_result();
        $data = $result->fetch_assoc();
        $healthMetrics[$key] = $data;
        $stmt->close();
    }
    
    return $healthMetrics;
}

// Generate the report
$reportData = generateReport($mysqli, $reportType, $startDate, $endDate);

// Export to CSV if requested
if ($format === 'csv') {
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment; filename="admin_analytics_' . $reportType . '_' . $dateRange . '.csv"');
    
    $output = fopen('php://output', 'w');
    
    switch ($reportType) {
        case 'overview':
            fputcsv($output, ['Metric', 'Value']);
            foreach ($reportData as $key => $value) {
                fputcsv($output, [$key, is_array($value) ? json_encode($value) : $value]);
            }
            break;
            
        case 'admin_activity':
            if (isset($reportData['admin_summary'])) {
                fputcsv($output, array_keys($reportData['admin_summary'][0]));
                foreach ($reportData['admin_summary'] as $row) {
                    fputcsv($output, $row);
                }
            }
            break;
            
        case 'security':
            if (isset($reportData['security_events'])) {
                fputcsv($output, array_keys($reportData['security_events'][0]));
                foreach ($reportData['security_events'] as $row) {
                    fputcsv($output, $row);
                }
            }
            break;
    }
    
    fclose($output);
    exit;
}

// Export to JSON if requested
if ($format === 'json') {
    header('Content-Type: application/json');
    header('Content-Disposition: attachment; filename="admin_analytics_' . $reportType . '_' . $dateRange . '.json"');
    echo json_encode($reportData, JSON_PRETTY_PRINT);
    exit;
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin Analytics Reports - EcoWaste</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        :root {
            --primary: #10b981;
            --secondary: #0ea5e9;
            --accent: #f59e0b;
        }
        
        body { 
            font-family: 'Inter', ui-sans-serif, system-ui;
            background: linear-gradient(135deg, #f8fff9 0%, #f0fdf4 25%, #f0f9ff 75%, #eff6ff 100%);
        }
        
        .glass-card {
            backdrop-filter: blur(20px);
            background: rgba(255, 255, 255, 0.15);
            border: 1px solid rgba(255, 255, 255, 0.2);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        
        .gradient-text {
            background: linear-gradient(135deg, var(--primary), var(--secondary));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
    </style>
</head>
<body class="min-h-screen">
    <div class="max-w-7xl mx-auto p-6">
        <!-- Header -->
        <header class="glass-card rounded-3xl p-6 mb-8">
            <div class="flex items-center justify-between">
                <div>
                    <h1 class="text-3xl font-bold gradient-text">Analytics Reports</h1>
                    <p class="text-slate-600 font-medium">Comprehensive admin tracking and analytics</p>
                </div>
                <div class="flex items-center gap-4">
                    <a href="/admin/dashboard.php" class="px-4 py-2 rounded-lg border border-slate-200 hover:bg-slate-50 transition-colors">
                        Back to Dashboard
                    </a>
                </div>
            </div>
        </header>

        <!-- Report Controls -->
        <div class="glass-card rounded-3xl p-6 mb-8">
            <div class="flex items-center gap-4 flex-wrap">
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-2">Report Type</label>
                    <select id="reportType" class="px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500">
                        <option value="overview" <?= $reportType === 'overview' ? 'selected' : '' ?>>Overview</option>
                        <option value="admin_activity" <?= $reportType === 'admin_activity' ? 'selected' : '' ?>>Admin Activity</option>
                        <option value="security" <?= $reportType === 'security' ? 'selected' : '' ?>>Security</option>
                        <option value="performance" <?= $reportType === 'performance' ? 'selected' : '' ?>>Performance</option>
                        <option value="feature_usage" <?= $reportType === 'feature_usage' ? 'selected' : '' ?>>Feature Usage</option>
                        <option value="system_health" <?= $reportType === 'system_health' ? 'selected' : '' ?>>System Health</option>
                    </select>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-2">Date Range</label>
                    <select id="dateRange" class="px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500">
                        <option value="1d" <?= $dateRange === '1d' ? 'selected' : '' ?>>Last 24 Hours</option>
                        <option value="7d" <?= $dateRange === '7d' ? 'selected' : '' ?>>Last 7 Days</option>
                        <option value="30d" <?= $dateRange === '30d' ? 'selected' : '' ?>>Last 30 Days</option>
                        <option value="90d" <?= $dateRange === '90d' ? 'selected' : '' ?>>Last 90 Days</option>
                        <option value="1y" <?= $dateRange === '1y' ? 'selected' : '' ?>>Last Year</option>
                    </select>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-2">Export Format</label>
                    <div class="flex gap-2">
                        <button onclick="exportReport('csv')" class="px-4 py-2 bg-emerald-500 text-white rounded-lg hover:bg-emerald-600 transition-colors">
                            Export CSV
                        </button>
                        <button onclick="exportReport('json')" class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors">
                            Export JSON
                        </button>
                    </div>
                </div>
                <div>
                    <button onclick="refreshReport()" class="px-4 py-2 bg-slate-500 text-white rounded-lg hover:bg-slate-600 transition-colors">
                        Refresh
                    </button>
                </div>
            </div>
        </div>

        <!-- Report Content -->
        <div class="glass-card rounded-3xl p-6">
            <?php if ($reportType === 'overview'): ?>
                <?php include 'reports/overview_report.php'; ?>
            <?php elseif ($reportType === 'admin_activity'): ?>
                <?php include 'reports/admin_activity_report.php'; ?>
            <?php elseif ($reportType === 'security'): ?>
                <?php include 'reports/security_report.php'; ?>
            <?php elseif ($reportType === 'performance'): ?>
                <?php include 'reports/performance_report.php'; ?>
            <?php elseif ($reportType === 'feature_usage'): ?>
                <?php include 'reports/feature_usage_report.php'; ?>
            <?php elseif ($reportType === 'system_health'): ?>
                <?php include 'reports/system_health_report.php'; ?>
            <?php endif; ?>
        </div>
    </div>

    <script>
        function refreshReport() {
            const reportType = document.getElementById('reportType').value;
            const dateRange = document.getElementById('dateRange').value;
            window.location.href = `?type=${reportType}&range=${dateRange}`;
        }

        function exportReport(format) {
            const reportType = document.getElementById('reportType').value;
            const dateRange = document.getElementById('dateRange').value;
            window.location.href = `?type=${reportType}&range=${dateRange}&format=${format}`;
        }

        // Auto-refresh every 5 minutes
        setInterval(refreshReport, 300000);
    </script>
</body>
</html>
