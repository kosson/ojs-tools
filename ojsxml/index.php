<?php
namespace OJSXml;

require 'vendor/autoload.php';

// csvToXmlConverter.php
require_once __DIR__ . '/app/config.php'; // Include config.php first

// require_once OJSXML_ROOT . "/app/bootstrap.php";

use OJSXml\Config;
Config::load(OJSXML_ROOT . "/config.ini"); // Absolute path for config.ini

require_once __DIR__ . '/src/helpers/helpers.php';

error_reporting(E_ALL);
ini_set('display_errors', 1);

// Simple routing
$page = isset($_GET['page']) ? $_GET['page'] : 'home';

// Handle records page
if ($page === 'records') {
    include __DIR__ . '/app/records.php';
    exit;
}

// Otherwise, show home page
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
        .status-message.info {
            background-color: #d1ecf1;
            border: 1px solid #bee5eb;
            color: #0c5460;
            display: block;
        }
        .error-list {
            margin: 10px 0;
            padding: 10px;
            background-color: #fff;
            border: 1px solid #ddd;
            border-radius: 3px;
            max-height: 300px;
            overflow-y: auto;
        }
        .error-list pre {
            margin: 0;
            white-space: pre-wrap;
            word-wrap: break-word;
            font-size: 0.9em;
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
    <nav class="main-nav">
        <div class="nav-container">
            <a href="index.php" class="nav-link <?php echo $page === 'home' ? 'active' : ''; ?>">Home</a>
            <a href="index.php?page=records" class="nav-link <?php echo $page === 'records' ? 'active' : ''; ?>">Database Records</a>
        </div>
    </nav>
    
    <h1>OJS XML Issue Creator</h1>
    
    <div class="upload-section">
        <h2>Upload ZIP Archive</h2>
        
        <div style="margin: 20px 0;">
            <p>Upload a ZIP file containing a CSV file and a folder with PDF files. The system will automatically process the files and validate the generated XML.</p>
            <form action="app/upload_handler.php" method="post" enctype="multipart/form-data" id="uploadForm">
                <label for="zipFile">Select ZIP file:</label>
                <input type="file" name="zipFile" id="zipFile" accept=".zip" required>
                <br><br>
                <input type="submit" value="Upload and Process ZIP" name="submit">
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
        <a href="#" class="download-link" id="downloadLink" download>Download XML</a>
        <p style="margin-top: 10px; font-size: 0.9em; color: #666;">File location: <code id="fileLocation">./docroot/output/</code></p>
    </div>

    <script>
        // Display message with optional HTML content
        function showMessage(text, type, htmlContent = null) {
            const messageDiv = document.getElementById('statusMessage');
            if (htmlContent) {
                messageDiv.innerHTML = text + htmlContent;
            } else {
                messageDiv.textContent = text;
            }
            messageDiv.className = 'status-message ' + type;
        }

        // Handle form submission with AJAX
        document.getElementById('uploadForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            const loadingDiv = document.getElementById('loading');
            const statusDiv = document.getElementById('statusMessage');
            const downloadDiv = document.getElementById('downloadSection');
            
            // Show loading, hide previous messages
            loadingDiv.style.display = 'block';
            statusDiv.className = 'status-message';
            statusDiv.style.display = 'none';
            downloadDiv.classList.remove('visible');
            
            fetch('app/upload_handler.php', {
                method: 'POST',
                body: formData
            })
            .then(response => {
                // Get the response text regardless of status code
                return response.text().then(text => ({
                    ok: response.ok,
                    status: response.status,
                    text: text
                }));
            })
            .then(result => {
                loadingDiv.style.display = 'none';
                
                console.log('Response status:', result.status);
                console.log('Response text:', result.text);
                
                // Check if SUCCESS marker is in output
                if (result.text.includes('=== SUCCESS ===')) {
                    showMessage('✓ XML file created and validated successfully!', 'success');
                    // Refresh the download section with the new file
                    updateDownloadSection();
                } else if (result.text.includes('=== ERROR ===')) {
                    // Extract error information
                    let errorHtml = '<div class="error-list"><pre>' + 
                                   escapeHtml(result.text) + 
                                   '</pre></div>';
                    showMessage('✗ Processing failed. Details:', 'error', errorHtml);
                } else {
                    // Show the actual response for debugging
                    let errorHtml = '<div class="error-list"><pre>' + 
                                   escapeHtml(result.text) + 
                                   '</pre></div>';
                    showMessage('✗ Unexpected response (check console for details):', 'error', errorHtml);
                }
            })
            .catch(error => {
                loadingDiv.style.display = 'none';
                console.error('Fetch error:', error);
                showMessage('✗ Network error: ' + error.message, 'error');
            });
        });
        
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        // Update download section with file info
        function updateDownloadSection() {
            fetch('app/check_xml.php')
                .then(response => response.json())
                .then(data => {
                    if (data.exists) {
                        const downloadLink = document.getElementById('downloadLink');
                        const fileLocation = document.getElementById('fileLocation');
                        
                        downloadLink.href = 'app/download.php?file=' + encodeURIComponent(data.file);
                        downloadLink.textContent = 'Download ' + data.file;
                        fileLocation.textContent = './docroot/output/' + data.file;
                        
                        document.getElementById('downloadSection').classList.add('visible');
                    }
                })
                .catch(e => console.log('Check failed:', e));
        }

        // Check if XML exists on page load
        window.addEventListener('load', function() {
            updateDownloadSection();
                
            // Also check for validation status
            fetch('app/get_validation_status.php')
                .then(response => response.json())
                .then(status => {
                    if (status && status.timestamp && (Date.now() / 1000 - status.timestamp) < 300) {
                        // Show recent validation status (within 5 minutes)
                        if (status.success) {
                            showMessage('✓ ' + status.message, 'success');
                        } else if (status.errors) {
                            let errorHtml = '<div class="error-list"><pre>';
                            status.errors.forEach(err => {
                                errorHtml += escapeHtml(err) + '\n';
                            });
                            errorHtml += '</pre></div>';
                            showMessage('✗ ' + status.message, 'error', errorHtml);
                        } else {
                            showMessage('ℹ ' + status.message, 'info');
                        }
                    }
                })
                .catch(e => console.log('Validation status check failed:', e));
        });
    </script>
</body>
</html>   