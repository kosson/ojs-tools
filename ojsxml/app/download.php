<?php
namespace OJSXml;

require dirname(__DIR__) . '/vendor/autoload.php';
require_once __DIR__ . '/config.php';

use OJSXml\Config;
Config::load(OJSXML_ROOT . "/config.ini");

error_reporting(E_ALL);
ini_set('display_errors', 1);

$outputDir = dirname(__DIR__) . '/docroot/output';
$xmlFile = $outputDir . '/issues_0.xml';

// Check if file parameter is provided and is safe
if (!isset($_GET['file'])) {
    http_response_code(400);
    die('No file specified');
}

$requestedFile = basename($_GET['file']); // Prevent directory traversal
$filePath = $outputDir . '/' . $requestedFile;

// Validate the file exists and is in the output directory
if (!file_exists($filePath) || !is_file($filePath)) {
    http_response_code(404);
    die('File not found');
}

// Ensure the file is within the allowed directory
if (realpath($filePath) !== realpath($filePath)) {
    http_response_code(403);
    die('Access denied');
}

// Set appropriate headers for download
header('Content-Type: application/xml');
header('Content-Disposition: attachment; filename="' . basename($filePath) . '"');
header('Content-Length: ' . filesize($filePath));
header('Cache-Control: no-cache, must-revalidate');
header('Expires: 0');

// Output the file
readfile($filePath);
exit;
?>
