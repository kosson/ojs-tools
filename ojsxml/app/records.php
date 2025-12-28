<?php
namespace OJSXml;

require dirname(__DIR__) . '/vendor/autoload.php';
require_once __DIR__ . '/config.php';

use OJSXml\Config;
Config::load(OJSXML_ROOT . "/config.ini");

error_reporting(E_ALL);
ini_set('display_errors', 1);

$page = 'records';

// Function to generate CSV file
function generateCSVFile($dbPath, $tmpDir) {
    $db = new \PDO('sqlite:' . $dbPath);
    $db->setAttribute(\PDO::ATTR_ERRMODE, \PDO::ERRMODE_EXCEPTION);
    
    // Get all records
    $stmt = $db->query("SELECT * FROM ojs_import_helper");
    $records = $stmt->fetchAll(\PDO::FETCH_ASSOC);
    
    if (empty($records)) {
        return null;
    }
    
    // Create filename with current date
    $filename = 'ojs_import_helper_' . date('Y-m-d') . '.csv';
    $filePath = $tmpDir . '/' . $filename;
    
    // Write CSV file
    $output = fopen($filePath, 'w');
    
    // Add BOM for UTF-8 (helps Excel recognize UTF-8)
    fprintf($output, chr(0xEF).chr(0xBB).chr(0xBF));
    
    // Write column headers
    $columns = array_keys($records[0]);
    fputcsv($output, $columns);
    
    // Write data rows
    foreach ($records as $record) {
        fputcsv($output, $record);
    }
    
    fclose($output);
    
    return $filename;
}

// Setup paths
$dbPath = dirname(__DIR__) . '/mysqlitedb.db';
$tmpDir = dirname(__DIR__) . '/tmp';

// Ensure tmp directory exists
if (!is_dir($tmpDir)) {
    mkdir($tmpDir, 0755, true);
}

$csvFilename = 'ojs_import_helper_' . date('Y-m-d') . '.csv';
$csvFilePath = $tmpDir . '/' . $csvFilename;
$csvExists = false;
$csvGenerationError = null;

// Handle CSV download request
if (isset($_GET['download']) && $_GET['download'] === 'csv') {
    if (file_exists($csvFilePath)) {
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="' . $csvFilename . '"');
        header('Pragma: no-cache');
        header('Expires: 0');
        header('Content-Length: ' . filesize($csvFilePath));
        readfile($csvFilePath);
        exit;
    } else {
        die("CSV file not found. Please refresh the page to regenerate.");
    }
}

// Generate CSV if it doesn't exist or force regeneration requested
if (isset($_GET['generate']) && $_GET['generate'] === 'csv') {
    try {
        if (!file_exists($dbPath)) {
            throw new \Exception("Database file not found");
        }
        
        $result = generateCSVFile($dbPath, $tmpDir);
        
        if ($result) {
            // Redirect back to records page
            header('Location: ?page=records');
            exit;
        } else {
            $csvGenerationError = "No records found in database";
        }
    } catch (\Exception $e) {
        $csvGenerationError = "Error generating CSV: " . $e->getMessage();
    }
}

// Check if CSV exists
if (file_exists($csvFilePath)) {
    $csvExists = true;
} else {
    // Auto-generate CSV on first page load
    try {
        if (file_exists($dbPath)) {
            $result = generateCSVFile($dbPath, $tmpDir);
            if ($result) {
                $csvExists = true;
            }
        }
    } catch (\Exception $e) {
        $csvGenerationError = "Error auto-generating CSV: " . $e->getMessage();
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Database Records - OJS XML</title>
    <link rel="stylesheet" href="../styles.css">
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .main-nav {
            background-color: #2c3e50;
            padding: 0;
            margin: 0 0 20px 0;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        .nav-container {
            max-width: 1200px;
            margin: 0 auto;
            display: flex;
            gap: 0;
        }
        .nav-link {
            color: white;
            text-decoration: none;
            padding: 15px 25px;
            display: inline-block;
            transition: background-color 0.3s;
            border-bottom: 3px solid transparent;
        }
        .nav-link:hover {
            background-color: #34495e;
        }
        .nav-link.active {
            background-color: #3498db;
            border-bottom-color: #2980b9;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            color: #2c3e50;
            margin-bottom: 10px;
        }
        .info-box {
            background-color: #e8f5e9;
            border-left: 4px solid #4caf50;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 4px;
        }
        .records-count {
            font-size: 14px;
            color: #666;
            margin-bottom: 20px;
        }
        .table-container {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .table-wrapper {
            overflow-x: auto;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }
        thead {
            background-color: #34495e;
            color: white;
        }
        th {
            padding: 12px 8px;
            text-align: left;
            font-weight: 600;
            position: sticky;
            top: 0;
            background-color: #34495e;
            z-index: 10;
        }
        td {
            padding: 10px 8px;
            border-bottom: 1px solid #e0e0e0;
        }
        tbody tr:hover {
            background-color: #f5f5f5;
        }
        tbody tr:nth-child(even) {
            background-color: #fafafa;
        }
        .text-truncate {
            max-width: 200px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .text-truncate:hover {
            overflow: visible;
            white-space: normal;
            max-width: none;
        }
        .null-value {
            color: #999;
            font-style: italic;
        }
        .error-message {
            background-color: #ffebee;
            border-left: 4px solid #f44336;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
            color: #c62828;
        }
        .no-records {
            text-align: center;
            padding: 40px;
            color: #666;
        }
        .action-buttons {
            margin-bottom: 20px;
            display: flex;
            gap: 10px;
            align-items: center;
        }
        .btn {
            display: inline-block;
            padding: 10px 20px;
            background-color: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            border: none;
            cursor: pointer;
            font-size: 14px;
            transition: background-color 0.3s;
        }
        .btn:hover {
            background-color: #2980b9;
        }
        .btn-success {
            background-color: #4caf50;
        }
        .btn-success:hover {
            background-color: #45a049;
        }
        .btn:disabled {
            background-color: #95a5a6;
            cursor: not-allowed;
            opacity: 0.6;
        }
        .btn:disabled:hover {
            background-color: #95a5a6;
        }
        .generation-info {
            background-color: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 12px;
            margin-bottom: 15px;
            border-radius: 4px;
            font-size: 14px;
        }
        .csv-info {
            color: #666;
            font-size: 13px;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <nav class="main-nav">
        <div class="nav-container">
            <a href="../index.php" class="nav-link">Home</a>
            <a href="../index.php?page=records" class="nav-link active">Database Records</a>
        </div>
    </nav>
    
    <div class="container">
        <h1>Database Records</h1>
        <div class="info-box">
            <strong>Database:</strong> mysqlitedb.db<br>
            <strong>Table:</strong> ojs_import_helper
        </div>

        <?php
        try {
            // Connect to SQLite database
            $dbPath = dirname(__DIR__) . '/mysqlitedb.db';
            
            if (!file_exists($dbPath)) {
                throw new \Exception("Database file not found: $dbPath");
            }
            
            $db = new \PDO('sqlite:' . $dbPath);
            $db->setAttribute(\PDO::ATTR_ERRMODE, \PDO::ERRMODE_EXCEPTION);
            
            // Get total count
            $countStmt = $db->query("SELECT COUNT(*) as count FROM ojs_import_helper");
            $count = $countStmt->fetch(\PDO::FETCH_ASSOC)['count'];
            
            echo "<div class='records-count'>Total records: <strong>$count</strong></div>";
            
            // Display CSV generation status and download button
            if ($csvGenerationError) {
                echo "<div class='error-message'>$csvGenerationError</div>";
            }
            
            echo "<div class='action-buttons'>";
            
            if ($csvExists) {
                // CSV exists - show download button
                $fileSize = filesize($csvFilePath);
                $fileSizeKB = round($fileSize / 1024, 2);
                echo "<a href='?page=records&download=csv' class='btn btn-success'>📥 Download CSV Export</a>";
                echo "<div class='csv-info'>";
                echo "File: <strong>$csvFilename</strong> ($fileSizeKB KB) - Generated: " . date('Y-m-d H:i:s', filemtime($csvFilePath));
                echo " | <a href='?page=records&generate=csv' style='color: #3498db;'>Regenerate</a>";
                echo "</div>";
            } else {
                // CSV doesn't exist - show generate button
                echo "<a href='?page=records&generate=csv' class='btn btn-success'>🔄 Generate CSV Export</a>";
                echo "<span style='color: #666; font-size: 13px;'>Click to generate CSV file for download</span>";
            }
            
            echo "</div>";
            
            // Get all records
            $stmt = $db->query("SELECT * FROM ojs_import_helper");
            $records = $stmt->fetchAll(\PDO::FETCH_ASSOC);
            
            if (empty($records)) {
                echo "<div class='no-records'>No records found in the database.</div>";
            } else {
                // Get column names from first record
                $columns = array_keys($records[0]);
                
                echo "<div class='table-container'>";
                echo "<div class='table-wrapper'>";
                echo "<table>";
                echo "<thead><tr>";
                
                // Display headers
                foreach ($columns as $column) {
                    echo "<th>" . htmlspecialchars($column) . "</th>";
                }
                
                echo "</tr></thead>";
                echo "<tbody>";
                
                // Display data
                foreach ($records as $record) {
                    echo "<tr>";
                    foreach ($columns as $column) {
                        $value = $record[$column];
                        
                        if ($value === null || $value === '') {
                            echo "<td class='null-value'>NULL</td>";
                        } else {
                            // Truncate long text
                            $displayValue = htmlspecialchars($value);
                            if (strlen($displayValue) > 100) {
                                $shortValue = substr($displayValue, 0, 100) . '...';
                                echo "<td class='text-truncate' title='" . htmlspecialchars($value) . "'>$shortValue</td>";
                            } else {
                                echo "<td>$displayValue</td>";
                            }
                        }
                    }
                    echo "</tr>";
                }
                
                echo "</tbody>";
                echo "</table>";
                echo "</div>";
                echo "</div>";
            }
            
        } catch (\Exception $e) {
            echo "<div class='error-message'>";
            echo "<strong>Error:</strong> " . htmlspecialchars($e->getMessage());
            echo "</div>";
        }
        ?>
    </div>
</body>
</html>
