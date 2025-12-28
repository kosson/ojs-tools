<?php
namespace OJSXml;

require dirname(__DIR__) . '/vendor/autoload.php';
require_once __DIR__ . '/config.php';

use OJSXml\Config;
Config::load(OJSXML_ROOT . "/config.ini");

$outputDir = dirname(__DIR__) . '/docroot/output';

// Check for last generated XML filename
$filenameFile = $outputDir . '/.last_xml_filename';
if (file_exists($filenameFile)) {
    $xmlFilename = trim(file_get_contents($filenameFile));
    $xmlFile = $outputDir . '/' . $xmlFilename;
} else {
    // Fallback: find any XML file in output directory
    $xmlFiles = glob($outputDir . '/*.xml');
    if (!empty($xmlFiles)) {
        $xmlFile = $xmlFiles[0]; // Get first XML file
        $xmlFilename = basename($xmlFile);
    } else {
        $xmlFile = null;
        $xmlFilename = null;
    }
}

header('Content-Type: application/json');

if ($xmlFile && file_exists($xmlFile) && is_file($xmlFile)) {
    echo json_encode([
        'exists' => true,
        'file' => $xmlFilename,
        'size' => filesize($xmlFile),
        'modified' => date('Y-m-d H:i:s', filemtime($xmlFile))
    ]);
} else {
    echo json_encode([
        'exists' => false
    ]);
}
?>
