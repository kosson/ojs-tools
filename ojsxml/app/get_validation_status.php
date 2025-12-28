<?php
/**
 * Get the last validation status from upload processing
 */

header('Content-Type: application/json');

$statusFile = dirname(__DIR__) . '/tmp/last_validation.json';

if (!file_exists($statusFile)) {
    echo json_encode([
        'success' => false,
        'message' => 'No validation status available',
        'timestamp' => null
    ]);
    exit;
}

$status = json_decode(file_get_contents($statusFile), true);

if ($status === null) {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to read validation status',
        'timestamp' => null
    ]);
    exit;
}

echo json_encode($status);
exit;
?>
