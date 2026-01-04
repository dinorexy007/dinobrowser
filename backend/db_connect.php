<?php
/**
 * Database Connection Handler
 * Dino Browser - Backend API
 * 
 * Secure PDO connection with error handling
 * Upload this file to: bilalcode.site/api/db_connect.php
 */

// Prevent direct access - this file should only be included
if (basename($_SERVER['PHP_SELF']) === 'db_connect.php') {
    http_response_code(403);
    exit('Direct access forbidden');
}

// Database configuration
define('DB_HOST', 'localhost');
define('DB_NAME', 'ahmeuesz_dino');
define('DB_USER', 'ahmeuesz_dino_user');
define('DB_PASS', 'doraemonnobita');
define('DB_CHARSET', 'utf8mb4');

/**
 * Get PDO database connection instance
 * Uses singleton pattern to reuse connections
 * 
 * @return PDO Database connection object
 * @throws PDOException If connection fails
 */
function getDBConnection(): PDO {
    static $pdo = null;
    
    if ($pdo === null) {
        $dsn = sprintf(
            'mysql:host=%s;dbname=%s;charset=%s',
            DB_HOST,
            DB_NAME,
            DB_CHARSET
        );
        
        $options = [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
            PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci"
        ];
        
        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
        } catch (PDOException $e) {
            // Log error but don't expose details to client
            error_log('Database Connection Error: ' . $e->getMessage());
            throw new PDOException('Database connection failed');
        }
    }
    
    return $pdo;
}

/**
 * Set CORS headers for mobile app access
 * Call this at the beginning of each API endpoint
 */
function setCORSHeaders(): void {
    // Allow requests from any origin (mobile apps)
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
    header('Access-Control-Max-Age: 86400'); // Cache preflight for 24 hours
    
    // Handle preflight OPTIONS request
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit();
    }
}

/**
 * Send JSON response with proper headers
 * 
 * @param mixed $data Data to encode as JSON
 * @param int $statusCode HTTP status code
 */
function sendJSON($data, int $statusCode = 200): void {
    http_response_code($statusCode);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit();
}

/**
 * Send error response
 * 
 * @param string $message Error message
 * @param int $statusCode HTTP status code
 */
function sendError(string $message, int $statusCode = 400): void {
    sendJSON([
        'success' => false,
        'error' => $message
    ], $statusCode);
}
?>
