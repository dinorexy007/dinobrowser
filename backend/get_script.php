<?php
/**
 * Get Script API Endpoint
 * Dino Browser - Backend API
 * 
 * Returns raw JavaScript code for a specific extension
 * Upload this file to: bilalcode.site/api/get_script.php
 * 
 * Endpoint: GET /api/get_script.php?id=1
 * Required param: id (extension ID)
 */

require_once __DIR__ . '/db_connect.php';

// Set CORS headers for mobile app access
setCORSHeaders();

// Only allow GET requests
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendError('Method not allowed', 405);
}

// Validate extension ID parameter
if (empty($_GET['id']) || !is_numeric($_GET['id'])) {
    sendError('Missing or invalid extension ID', 400);
}

$extensionId = (int)$_GET['id'];

try {
    $pdo = getDBConnection();
    
    // Fetch the JavaScript code for the requested extension
    $sql = "SELECT 
                id,
                name,
                js_code,
                version
            FROM extensions
            WHERE id = :id AND is_active = 1";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':id' => $extensionId]);
    $extension = $stmt->fetch();
    
    if (!$extension) {
        sendError('Extension not found or inactive', 404);
    }
    
    // Increment download counter (fire and forget)
    $updateSql = "UPDATE extensions SET downloads = downloads + 1 WHERE id = :id";
    $pdo->prepare($updateSql)->execute([':id' => $extensionId]);
    
    // Return the script data
    sendJSON([
        'success' => true,
        'extension' => [
            'id' => (int)$extension['id'],
            'name' => $extension['name'],
            'version' => $extension['version'],
            'script' => $extension['js_code']
        ]
    ]);
    
} catch (PDOException $e) {
    error_log('Get Script Error: ' . $e->getMessage());
    sendError('Failed to fetch script', 500);
} catch (Exception $e) {
    error_log('Unexpected Error: ' . $e->getMessage());
    sendError('An unexpected error occurred', 500);
}
?>
