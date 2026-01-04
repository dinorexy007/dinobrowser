<?php
/**
 * Get Extensions API Endpoint
 * Dino Browser - Backend API
 * 
 * Returns JSON list of all available extensions
 * Upload this file to: bilalcode.site/api/get_extensions.php
 * 
 * Endpoint: GET /api/get_extensions.php
 * Optional params: ?category=privacy&active_only=1
 */

require_once __DIR__ . '/db_connect.php';

// Set CORS headers for mobile app access
setCORSHeaders();

// Only allow GET requests
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendError('Method not allowed', 405);
}

try {
    $pdo = getDBConnection();
    
    // Build query with optional filters
    $sql = "SELECT 
                id,
                name,
                description,
                icon_url,
                category,
                downloads,
                version,
                created_at
            FROM extensions
            WHERE 1=1";
    
    $params = [];
    
    // Filter by category if provided
    if (!empty($_GET['category'])) {
        $validCategories = ['productivity', 'privacy', 'appearance', 'social', 'utility'];
        $category = strtolower(trim($_GET['category']));
        
        if (in_array($category, $validCategories)) {
            $sql .= " AND category = :category";
            $params[':category'] = $category;
        }
    }
    
    // Filter by active status (default: only active)
    $activeOnly = isset($_GET['active_only']) ? (bool)$_GET['active_only'] : true;
    if ($activeOnly) {
        $sql .= " AND is_active = 1";
    }
    
    // Order by downloads (popularity) then by name
    $sql .= " ORDER BY downloads DESC, name ASC";
    
    // Optional limit
    if (!empty($_GET['limit']) && is_numeric($_GET['limit'])) {
        $limit = min((int)$_GET['limit'], 100); // Max 100 results
        $sql .= " LIMIT " . $limit;
    }
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $extensions = $stmt->fetchAll();
    
    // Format response
    sendJSON([
        'success' => true,
        'count' => count($extensions),
        'extensions' => $extensions
    ]);
    
} catch (PDOException $e) {
    error_log('Get Extensions Error: ' . $e->getMessage());
    sendError('Failed to fetch extensions', 500);
} catch (Exception $e) {
    error_log('Unexpected Error: ' . $e->getMessage());
    sendError('An unexpected error occurred', 500);
}
?>
