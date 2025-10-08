/**
 * EcoWaste Admin Tracking JavaScript
 * Client-side tracking and analytics integration
 */

class AdminTracking {
    constructor() {
        this.sessionId = null;
        this.sessionToken = null;
        this.adminId = null;
        this.startTime = Date.now();
        this.pageStartTime = Date.now();
        this.activityQueue = [];
        this.isOnline = navigator.onLine;
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.trackPageVisit();
        this.startHeartbeat();
        this.setupOfflineHandling();
    }

    setupEventListeners() {
        // Track page visibility changes
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.trackActivity('PAGE_HIDDEN', 'NAVIGATION', 'Page became hidden');
            } else {
                this.trackActivity('PAGE_VISIBLE', 'NAVIGATION', 'Page became visible');
                this.pageStartTime = Date.now();
            }
        });

        // Track before page unload
        window.addEventListener('beforeunload', () => {
            this.trackPageExit();
            this.flushActivityQueue();
        });

        // Track online/offline status
        window.addEventListener('online', () => {
            this.isOnline = true;
            this.flushActivityQueue();
        });

        window.addEventListener('offline', () => {
            this.isOnline = false;
        });

        // Track clicks on important elements
        document.addEventListener('click', (e) => {
            const target = e.target.closest('[data-track]');
            if (target) {
                const trackingData = target.dataset.track;
                const [action, category] = trackingData.split(':');
                this.trackActivity(action, category, `Clicked on ${target.textContent.trim()}`);
            }
        });

        // Track form submissions
        document.addEventListener('submit', (e) => {
            const form = e.target;
            if (form.tagName === 'FORM') {
                this.trackActivity('FORM_SUBMIT', 'INTERACTION', `Form submitted: ${form.id || form.className}`);
            }
        });

        // Track file uploads
        document.addEventListener('change', (e) => {
            if (e.target.type === 'file' && e.target.files.length > 0) {
                this.trackActivity('FILE_UPLOAD', 'INTERACTION', `File uploaded: ${e.target.files[0].name}`);
            }
        });
    }

    // Set admin session data
    setSessionData(adminId, sessionId, sessionToken) {
        this.adminId = adminId;
        this.sessionId = sessionId;
        this.sessionToken = sessionToken;
        
        // Store in localStorage for persistence
        localStorage.setItem('admin_tracking_session', JSON.stringify({
            adminId,
            sessionId,
            sessionToken,
            timestamp: Date.now()
        }));
    }

    // Get session data from localStorage
    getSessionData() {
        const stored = localStorage.getItem('admin_tracking_session');
        if (stored) {
            const data = JSON.parse(stored);
            // Check if session is not too old (24 hours)
            if (Date.now() - data.timestamp < 24 * 60 * 60 * 1000) {
                return data;
            }
        }
        return null;
    }

    // Track page visit
    trackPageVisit() {
        const pageData = {
            page_name: document.title,
            page_url: window.location.href,
            visit_duration: 0,
            referrer_url: document.referrer,
            screen_resolution: `${screen.width}x${screen.height}`,
            browser_name: this.getBrowserName(),
            browser_version: this.getBrowserVersion(),
            os_name: this.getOSName(),
            device_type: this.getDeviceType()
        };

        this.sendRequest('POST', '/admin_tracking_api.php/page-visit', pageData);
    }

    // Track page exit
    trackPageExit() {
        const visitDuration = Math.floor((Date.now() - this.pageStartTime) / 1000);
        const pageData = {
            page_name: document.title,
            page_url: window.location.href,
            visit_duration: visitDuration
        };

        this.sendRequest('POST', '/admin_tracking_api.php/page-visit', pageData);
    }

    // Track admin activity
    trackActivity(activityType, activityCategory, description, targetResource = null, targetId = null, oldValues = null, newValues = null, additionalData = null) {
        const activity = {
            activity_type: activityType,
            activity_category: activityCategory,
            activity_description: description,
            target_resource: targetResource,
            target_id: targetId,
            old_values: oldValues,
            new_values: newValues,
            additional_data: additionalData
        };

        if (this.isOnline) {
            this.sendRequest('POST', '/admin_tracking_api.php/activity', activity);
        } else {
            // Queue for later when online
            this.activityQueue.push(activity);
        }
    }

    // Track security event
    trackSecurityEvent(eventType, eventSeverity, description, additionalData = null) {
        const event = {
            event_type: eventType,
            event_severity: eventSeverity,
            event_description: description,
            additional_data: additionalData
        };

        this.sendRequest('POST', '/admin_tracking_api.php/security-event', event);
    }

    // Send API request
    async sendRequest(method, endpoint, data = null) {
        try {
            const options = {
                method,
                headers: {
                    'Content-Type': 'application/json',
                    'X-Admin-Session': this.sessionToken || ''
                }
            };

            if (data) {
                options.body = JSON.stringify(data);
            }

            const response = await fetch(endpoint, options);
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Admin tracking error:', error);
            
            // Store failed requests for retry
            if (data) {
                this.storeFailedRequest(method, endpoint, data);
            }
        }
    }

    // Store failed requests for retry
    storeFailedRequest(method, endpoint, data) {
        const failedRequests = JSON.parse(localStorage.getItem('admin_tracking_failed') || '[]');
        failedRequests.push({
            method,
            endpoint,
            data,
            timestamp: Date.now()
        });
        
        // Keep only last 50 failed requests
        if (failedRequests.length > 50) {
            failedRequests.splice(0, failedRequests.length - 50);
        }
        
        localStorage.setItem('admin_tracking_failed', JSON.stringify(failedRequests));
    }

    // Retry failed requests
    async retryFailedRequests() {
        const failedRequests = JSON.parse(localStorage.getItem('admin_tracking_failed') || '[]');
        const successfulRequests = [];

        for (const request of failedRequests) {
            try {
                await this.sendRequest(request.method, request.endpoint, request.data);
                successfulRequests.push(request);
            } catch (error) {
                console.error('Failed to retry request:', error);
            }
        }

        // Remove successful requests
        const remainingRequests = failedRequests.filter(req => 
            !successfulRequests.some(success => 
                success.timestamp === req.timestamp && 
                success.method === req.method && 
                success.endpoint === req.endpoint
            )
        );

        localStorage.setItem('admin_tracking_failed', JSON.stringify(remainingRequests));
    }

    // Flush activity queue
    async flushActivityQueue() {
        if (this.activityQueue.length === 0) return;

        const activities = [...this.activityQueue];
        this.activityQueue = [];

        for (const activity of activities) {
            await this.sendRequest('POST', '/admin_tracking_api.php/activity', activity);
        }
    }

    // Setup offline handling
    setupOfflineHandling() {
        // Retry failed requests when coming back online
        window.addEventListener('online', () => {
            this.retryFailedRequests();
        });
    }

    // Start heartbeat to keep session alive
    startHeartbeat() {
        setInterval(() => {
            if (this.sessionToken) {
                this.trackActivity('HEARTBEAT', 'SYSTEM', 'Session heartbeat');
            }
        }, 300000); // Every 5 minutes
    }

    // Get browser name
    getBrowserName() {
        const userAgent = navigator.userAgent;
        if (userAgent.includes('Chrome')) return 'Chrome';
        if (userAgent.includes('Firefox')) return 'Firefox';
        if (userAgent.includes('Safari')) return 'Safari';
        if (userAgent.includes('Edge')) return 'Edge';
        return 'Unknown';
    }

    // Get browser version
    getBrowserVersion() {
        const userAgent = navigator.userAgent;
        const match = userAgent.match(/(Chrome|Firefox|Safari|Edge)\/(\d+)/);
        return match ? match[2] : 'Unknown';
    }

    // Get OS name
    getOSName() {
        const userAgent = navigator.userAgent;
        if (userAgent.includes('Windows')) return 'Windows';
        if (userAgent.includes('Mac')) return 'macOS';
        if (userAgent.includes('Linux')) return 'Linux';
        if (userAgent.includes('Android')) return 'Android';
        if (userAgent.includes('iOS')) return 'iOS';
        return 'Unknown';
    }

    // Get device type
    getDeviceType() {
        const width = screen.width;
        if (width < 768) return 'mobile';
        if (width < 1024) return 'tablet';
        return 'desktop';
    }

    // Track data changes
    trackDataChange(tableName, recordId, operationType, fieldName = null, oldValue = null, newValue = null, changeReason = null) {
        this.trackActivity(
            'DATA_CHANGE',
            'DATA_MANAGEMENT',
            `${operationType} operation on ${tableName}`,
            tableName,
            recordId,
            oldValue ? { [fieldName]: oldValue } : null,
            newValue ? { [fieldName]: newValue } : null,
            { change_reason: changeReason }
        );
    }

    // Track feature usage
    trackFeatureUsage(featureName, featureCategory, success = true, executionTime = 0) {
        this.trackActivity(
            'FEATURE_USAGE',
            featureCategory,
            `Used feature: ${featureName}`,
            featureName,
            null,
            null,
            null,
            { success, execution_time: executionTime }
        );
    }

    // Track error
    trackError(errorType, errorMessage, errorStack = null, context = null) {
        this.trackSecurityEvent(
            'ERROR',
            'MEDIUM',
            `${errorType}: ${errorMessage}`,
            { error_stack: errorStack, context }
        );
    }

    // Track suspicious activity
    trackSuspiciousActivity(activityType, description, severity = 'HIGH') {
        this.trackSecurityEvent(
            'SUSPICIOUS_ACTIVITY',
            severity,
            description,
            { activity_type: activityType }
        );
    }
}

// Global admin tracking instance
window.adminTracking = new AdminTracking();

// Helper functions for easy tracking
window.trackAdminActivity = (type, category, description, target = null) => {
    window.adminTracking.trackActivity(type, category, description, target);
};

window.trackDataChange = (table, id, operation, field = null, oldVal = null, newVal = null) => {
    window.adminTracking.trackDataChange(table, id, operation, field, oldVal, newVal);
};

window.trackFeatureUsage = (feature, category, success = true, time = 0) => {
    window.adminTracking.trackFeatureUsage(feature, category, success, time);
};

window.trackError = (type, message, stack = null, context = null) => {
    window.adminTracking.trackError(type, message, stack, context);
};

// Auto-track common admin actions
document.addEventListener('DOMContentLoaded', () => {
    // Track page load
    window.adminTracking.trackActivity('PAGE_LOAD', 'NAVIGATION', `Loaded page: ${document.title}`);
    
    // Track form interactions
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
        form.addEventListener('submit', (e) => {
            const formName = form.id || form.className || 'unnamed_form';
            window.adminTracking.trackActivity('FORM_SUBMIT', 'INTERACTION', `Submitted form: ${formName}`);
        });
    });
    
    // Track button clicks with data-track attribute
    const trackableButtons = document.querySelectorAll('[data-track]');
    trackableButtons.forEach(button => {
        button.addEventListener('click', (e) => {
            const trackingData = button.dataset.track;
            const [action, category] = trackingData.split(':');
            window.adminTracking.trackActivity(action, category, `Clicked: ${button.textContent.trim()}`);
        });
    });
});

// Error tracking
window.addEventListener('error', (e) => {
    window.adminTracking.trackError('JAVASCRIPT_ERROR', e.message, e.error?.stack, {
        filename: e.filename,
        lineno: e.lineno,
        colno: e.colno
    });
});

window.addEventListener('unhandledrejection', (e) => {
    window.adminTracking.trackError('PROMISE_REJECTION', e.reason?.message || 'Unhandled promise rejection', e.reason?.stack);
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = AdminTracking;
}
