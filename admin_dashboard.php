<?php
/**
 * EcoWaste Admin Tracking Dashboard
 * Comprehensive analytics and monitoring interface
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
$adminName = $_SESSION['admin_name'] ?? 'Admin';

// Get analytics data
function getAnalyticsData($mysqli, $date = null) {
    if (!$date) $date = date('Y-m-d');
    
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
    
    return $results;
}

// Get recent activities
function getRecentActivities($mysqli, $limit = 20) {
    $stmt = $mysqli->prepare("
        SELECT 
            al.id, al.activity_type, al.activity_category, al.activity_description,
            al.target_resource, al.created_at, al.execution_time_ms,
            a.username, a.display_name
        FROM admin_activity_log al
        JOIN admins a ON al.admin_id = a.id
        ORDER BY al.created_at DESC
        LIMIT ?
    ");
    $stmt->bind_param('i', $limit);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    $stmt->close();
    return $data;
}

// Get security events
function getSecurityEvents($mysqli, $limit = 10) {
    $stmt = $mysqli->prepare("
        SELECT 
            id, event_type, event_severity, event_description,
            ip_address, is_resolved, created_at
        FROM admin_security_events
        ORDER BY created_at DESC
        LIMIT ?
    ");
    $stmt->bind_param('i', $limit);
    $stmt->execute();
    $result = $stmt->get_result();
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    $stmt->close();
    return $data;
}

// Get admin performance
function getAdminPerformance($mysqli, $date = null) {
    if (!$date) $date = date('Y-m-d');
    
    $stmt = $mysqli->prepare("
        SELECT 
            a.username, a.display_name,
            pm.total_activities, pm.total_login_time, pm.avg_session_duration,
            pm.success_rate, pm.error_count
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
    return $data;
}

$analytics = getAnalyticsData($mysqli);
$recentActivities = getRecentActivities($mysqli);
$securityEvents = getSecurityEvents($mysqli);
$adminPerformance = getAdminPerformance($mysqli);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>EcoWaste Admin Tracking Dashboard</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        :root {
            --primary: #10b981;
            --secondary: #0ea5e9;
            --accent: #f59e0b;
            --danger: #ef4444;
            --warning: #f59e0b;
            --success: #10b981;
        }
        
        * { box-sizing: border-box; }
        
        body { 
            font-family: 'Inter', ui-sans-serif, system-ui;
            background: 
                radial-gradient(1200px 600px at 20% 0%, rgba(16, 185, 129, 0.08) 0%, transparent 60%),
                radial-gradient(1200px 600px at 80% 100%, rgba(14, 165, 233, 0.08) 0%, transparent 60%),
                linear-gradient(135deg, #f8fff9 0%, #f0fdf4 25%, #f0f9ff 75%, #eff6ff 100%);
            min-height: 100vh;
            margin: 0;
            padding: 0;
        }
        
        .glass-card {
            backdrop-filter: blur(20px);
            background: rgba(255, 255, 255, 0.15);
            border: 1px solid rgba(255, 255, 255, 0.2);
            box-shadow: 
                0 8px 32px rgba(0, 0, 0, 0.1),
                inset 0 1px 0 rgba(255, 255, 255, 0.2);
        }
        
        .gradient-text {
            background: linear-gradient(135deg, var(--primary), var(--secondary));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .stat-card {
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 16px;
            padding: 20px;
            backdrop-filter: blur(10px);
            transition: all 0.3s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
        }
        
        .activity-item {
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 12px;
            padding: 16px;
            margin-bottom: 12px;
            backdrop-filter: blur(10px);
            transition: all 0.2s ease;
        }
        
        .activity-item:hover {
            background: rgba(255, 255, 255, 0.15);
            transform: translateX(4px);
        }
        
        .severity-high { color: var(--danger); }
        .severity-medium { color: var(--warning); }
        .severity-low { color: var(--success); }
        .severity-critical { color: #dc2626; font-weight: bold; }
        
        .status-badge {
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .status-active { background: rgba(16, 185, 129, 0.2); color: var(--success); }
        .status-inactive { background: rgba(107, 114, 128, 0.2); color: #6b7280; }
        .status-resolved { background: rgba(16, 185, 129, 0.2); color: var(--success); }
        .status-pending { background: rgba(245, 158, 11, 0.2); color: var(--warning); }
        
        .chart-container {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 12px;
            padding: 20px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .metric-value {
            font-size: 2rem;
            font-weight: 700;
            color: #1f2937;
        }
        
        .metric-label {
            font-size: 0.875rem;
            color: #6b7280;
            font-weight: 500;
        }
        
        .trend-up { color: var(--success); }
        .trend-down { color: var(--danger); }
        .trend-neutral { color: #6b7280; }
    </style>
</head>
<body class="min-h-screen">
    <div class="max-w-7xl mx-auto p-6">
        <!-- Header -->
        <header class="glass-card rounded-3xl p-6 mb-8">
            <div class="flex items-center justify-between">
                <div class="flex items-center gap-4">
                    <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-emerald-500 to-sky-500 flex items-center justify-center text-white text-xl">
                        📊
                    </div>
                    <div>
                        <h1 class="text-3xl font-bold gradient-text">Admin Tracking Dashboard</h1>
                        <p class="text-slate-600 font-medium">Comprehensive analytics and monitoring</p>
                    </div>
                </div>
                <div class="flex items-center gap-4">
                    <div class="text-right">
                        <div class="font-semibold text-slate-800"><?= htmlspecialchars($adminName) ?></div>
                        <div class="text-sm text-slate-500">Administrator</div>
                    </div>
                    <a href="/admin/logout.php" class="px-4 py-2 rounded-lg border border-slate-200 hover:bg-slate-50 transition-colors">
                        Logout
                    </a>
                </div>
            </div>
        </header>

        <!-- Stats Overview -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            <div class="stat-card">
                <div class="flex items-center justify-between">
                    <div>
                        <div class="metric-label">Total Sessions</div>
                        <div class="metric-value"><?= $analytics['total_sessions'] ?></div>
                    </div>
                    <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center text-white">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                            <circle cx="9" cy="7" r="4"/>
                            <path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>
                        </svg>
                    </div>
                </div>
            </div>
            
            <div class="stat-card">
                <div class="flex items-center justify-between">
                    <div>
                        <div class="metric-label">Active Sessions</div>
                        <div class="metric-value"><?= $analytics['active_sessions'] ?></div>
                    </div>
                    <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-green-400 to-green-600 flex items-center justify-center text-white">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <circle cx="12" cy="12" r="10"/>
                            <polyline points="12,6 12,12 16,14"/>
                        </svg>
                    </div>
                </div>
            </div>
            
            <div class="stat-card">
                <div class="flex items-center justify-between">
                    <div>
                        <div class="metric-label">Total Activities</div>
                        <div class="metric-value"><?= $analytics['total_activities'] ?></div>
                    </div>
                    <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-400 to-purple-600 flex items-center justify-center text-white">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                            <polyline points="14,2 14,8 20,8"/>
                            <line x1="16" y1="13" x2="8" y2="13"/>
                            <line x1="16" y1="17" x2="8" y2="17"/>
                            <polyline points="10,9 9,9 8,9"/>
                        </svg>
                    </div>
                </div>
            </div>
            
            <div class="stat-card">
                <div class="flex items-center justify-between">
                    <div>
                        <div class="metric-label">Security Events</div>
                        <div class="metric-value"><?= $analytics['security_events'] ?></div>
                    </div>
                    <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-red-400 to-red-600 flex items-center justify-center text-white">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                        </svg>
                    </div>
                </div>
            </div>
        </div>

        <!-- Main Content Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <!-- Recent Activities -->
            <div class="glass-card rounded-3xl p-6">
                <div class="flex items-center justify-between mb-6">
                    <h2 class="text-xl font-bold gradient-text">Recent Activities</h2>
                    <span class="text-sm text-slate-500">Last 20 actions</span>
                </div>
                <div class="space-y-3">
                    <?php foreach ($recentActivities as $activity): ?>
                    <div class="activity-item">
                        <div class="flex items-start justify-between">
                            <div class="flex-1">
                                <div class="flex items-center gap-2 mb-1">
                                    <span class="font-semibold text-slate-800"><?= htmlspecialchars($activity['display_name'] ?: $activity['username']) ?></span>
                                    <span class="status-badge status-active"><?= htmlspecialchars($activity['activity_type']) ?></span>
                                </div>
                                <div class="text-sm text-slate-600 mb-1"><?= htmlspecialchars($activity['activity_description']) ?></div>
                                <?php if ($activity['target_resource']): ?>
                                <div class="text-xs text-slate-500">Target: <?= htmlspecialchars($activity['target_resource']) ?></div>
                                <?php endif; ?>
                            </div>
                            <div class="text-right text-xs text-slate-500">
                                <div><?= date('H:i', strtotime($activity['created_at'])) ?></div>
                                <?php if ($activity['execution_time_ms']): ?>
                                <div><?= $activity['execution_time_ms'] ?>ms</div>
                                <?php endif; ?>
                            </div>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </div>

            <!-- Security Events -->
            <div class="glass-card rounded-3xl p-6">
                <div class="flex items-center justify-between mb-6">
                    <h2 class="text-xl font-bold gradient-text">Security Events</h2>
                    <span class="text-sm text-slate-500">Recent alerts</span>
                </div>
                <div class="space-y-3">
                    <?php foreach ($securityEvents as $event): ?>
                    <div class="activity-item">
                        <div class="flex items-start justify-between">
                            <div class="flex-1">
                                <div class="flex items-center gap-2 mb-1">
                                    <span class="font-semibold text-slate-800"><?= htmlspecialchars($event['event_type']) ?></span>
                                    <span class="status-badge severity-<?= strtolower($event['event_severity']) ?>"><?= htmlspecialchars($event['event_severity']) ?></span>
                                    <span class="status-badge <?= $event['is_resolved'] ? 'status-resolved' : 'status-pending' ?>">
                                        <?= $event['is_resolved'] ? 'Resolved' : 'Pending' ?>
                                    </span>
                                </div>
                                <div class="text-sm text-slate-600 mb-1"><?= htmlspecialchars($event['event_description']) ?></div>
                                <div class="text-xs text-slate-500">IP: <?= htmlspecialchars($event['ip_address']) ?></div>
                            </div>
                            <div class="text-right text-xs text-slate-500">
                                <div><?= date('M j, H:i', strtotime($event['created_at'])) ?></div>
                            </div>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </div>
        </div>

        <!-- Admin Performance -->
        <div class="glass-card rounded-3xl p-6 mt-8">
            <div class="flex items-center justify-between mb-6">
                <h2 class="text-xl font-bold gradient-text">Admin Performance</h2>
                <span class="text-sm text-slate-500">Today's metrics</span>
            </div>
            <div class="overflow-x-auto">
                <table class="w-full">
                    <thead>
                        <tr class="text-left text-sm text-slate-500 border-b border-slate-200">
                            <th class="pb-3">Admin</th>
                            <th class="pb-3">Activities</th>
                            <th class="pb-3">Login Time</th>
                            <th class="pb-3">Avg Session</th>
                            <th class="pb-3">Success Rate</th>
                            <th class="pb-3">Errors</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($adminPerformance as $perf): ?>
                        <tr class="border-b border-slate-100">
                            <td class="py-3">
                                <div class="font-semibold text-slate-800"><?= htmlspecialchars($perf['display_name'] ?: $perf['username']) ?></div>
                            </td>
                            <td class="py-3">
                                <span class="font-semibold"><?= $perf['total_activities'] ?></span>
                            </td>
                            <td class="py-3">
                                <span class="text-sm text-slate-600"><?= gmdate('H:i:s', $perf['total_login_time']) ?></span>
                            </td>
                            <td class="py-3">
                                <span class="text-sm text-slate-600"><?= gmdate('H:i:s', $perf['avg_session_duration']) ?></span>
                            </td>
                            <td class="py-3">
                                <span class="font-semibold <?= $perf['success_rate'] > 90 ? 'text-green-600' : ($perf['success_rate'] > 70 ? 'text-yellow-600' : 'text-red-600') ?>">
                                    <?= number_format($perf['success_rate'], 1) ?>%
                                </span>
                            </td>
                            <td class="py-3">
                                <span class="text-sm text-slate-600"><?= $perf['error_count'] ?></span>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        // Auto-refresh every 30 seconds
        setInterval(() => {
            location.reload();
        }, 30000);
    </script>
</body>
</html>
