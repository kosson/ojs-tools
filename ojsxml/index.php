<?php
namespace OJSXml;

require 'vendor/autoload.php';

// csvToXmlConverter.php
require_once __DIR__ . '/config.php'; // Include config.php first

// require_once OJSXML_ROOT . "/app/bootstrap.php";

use OJSXml\Config;
Config::load(OJSXML_ROOT . "/config.ini"); // Absolute path for config.ini

require_once __DIR__ . '/src/helpers/helpers.php';

error_reporting(E_ALL);
ini_set('display_errors', 1);

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OJS XML</title>
    <link rel="stylesheet" href="styles.css">
    <style>
        .upload-section {
            margin: 20px 0;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .download-section {
            margin: 20px 0;
            padding: 20px;
            background-color: #e8f5e9;
            border: 1px solid #4caf50;
            border-radius: 5px;
            display: none;
        }
        .download-section.visible {
            display: block;
        }
        .download-link {
            display: inline-block;
            padding: 10px 20px;
            background-color: #4caf50;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            margin: 10px 0;
        }
        .download-link:hover {
            background-color: #45a049;
        }
        .status-message {
            padding: 10px;
            margin: 10px 0;
            border-radius: 4px;
            display: none;
        }
        .status-message.success {
            background-color: #d4edda;
            border: 1px solid #c3e6cb;
            color: #155724;
            display: block;
        }
        .status-message.error {
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
            display: block;
        }
        .loading {
            display: none;
            text-align: center;
            margin: 20px 0;
        }
        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <h1>OJS XML Issue Creator</h1>
    
    <div class="upload-section">
        <h2>Upload Options</h2>
        
        <div style="margin: 20px 0;">
            <h3>Option 1: ZIP Archive (CSV + PDFs)</h3>
            <p>Upload a ZIP file containing a CSV file and a folder with PDF files.</p>
            <form action="upload_handler.php" method="post" enctype="multipart/form-data">
                <label for="zipFile">Select ZIP file:</label>
                <input type="file" name="zipFile" id="zipFile" accept=".zip" required>
                <br><br>
                <input type="submit" value="Upload and Extract ZIP" name="submit">
            </form>
        </div>

        <div style="margin: 20px 0; border-top: 1px solid #ccc; padding-top: 20px;">
            <h3>Option 2: CSV Only</h3>
            <p>Upload a CSV file to process (legacy method).</p>
            <form action="process.php" method="post" enctype="multipart/form-data">
                <label for="csvFile">Select CSV file to upload:</label>
                <input type="file" name="csvFile" id="csvFile" accept=".csv">
                <br><br>
                <input type="submit" value="Upload and Process CSV" name="submit">
            </form>
        </div>
    </div>

    <div class="loading" id="loading">
        <p>Processing your files...</p>
        <div class="spinner"></div>
    </div>

    <div class="status-message" id="statusMessage"></div>

    <div class="download-section" id="downloadSection">
        <h2>✓ Processing Complete!</h2>
        <p>Your XML file has been successfully generated:</p>
        <a href="download.php?file=issues_0.xml" class="download-link" download>Download issues_0.xml</a>
        <p style="margin-top: 10px; font-size: 0.9em; color: #666;">File location: <code>./docroot/output/issues_0.xml</code></p>
    </div>

    <script>
        // Simple message display
        function showMessage(text, type) {
            const messageDiv = document.getElementById('statusMessage');
            messageDiv.textContent = text;
            messageDiv.className = 'status-message ' + type;
        }

        // Check if issues_0.xml exists on page load
        window.addEventListener('load', function() {
            fetch('check_xml.php')
                .then(response => response.json())
                .then(data => {
                    if (data.exists) {
                        document.getElementById('downloadSection').classList.add('visible');
                    }
                })
                .catch(e => console.log('Check failed:', e));
        });
    </script>
</body>
</html>   