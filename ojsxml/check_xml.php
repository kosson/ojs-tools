<?php
namespace OJSXml;

require 'vendor/autoload.php';
require_once __DIR__ . '/config.php';

use OJSXml\Config;
Config::load(OJSXML_ROOT . "/config.ini");

$outputDir = __DIR__ . '/docroot/output';
$xmlFile = $outputDir . '/issues_0.xml';

header('Content-Type: application/json');

if (file_exists($xmlFile) && is_file($xmlFile)) {
    echo json_encode([
        'exists' => true,
        'file' => 'issues_0.xml',
        'size' => filesize($xmlFile),
        'modified' => date('Y-m-d H:i:s', filemtime($xmlFile))
    ]);
} else {
    echo json_encode([
        'exists' => false
    ]);
}
?>
