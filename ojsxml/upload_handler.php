<?php
// Simple upload handler - save the ZIP file to ./tmp with diagnostics on failure

$tmpDir = __DIR__ . '/tmp';

// Create tmp directory if it doesn't exist
if (!is_dir($tmpDir)) {
    mkdir($tmpDir, 0755, true);
}

// Check if file was uploaded
if (!isset($_FILES['zipFile'])) {
    http_response_code(400);
    echo "No file uploaded. Make sure the form field is named 'zipFile' and the form uses enctype='multipart/form-data'.";
    exit;
}

$file = $_FILES['zipFile'];

// Basic info
$fileName = basename($file['name']);
$tmpFilePath = $tmpDir . '/' . $fileName;

// If PHP reported an upload error, show it
if ($file['error'] !== UPLOAD_ERR_OK) {
    $err = $file['error'];
    $messages = [
        UPLOAD_ERR_INI_SIZE => 'The uploaded file exceeds the upload_max_filesize directive in php.ini.',
        UPLOAD_ERR_FORM_SIZE => 'The uploaded file exceeds the MAX_FILE_SIZE directive specified in the HTML form.',
        UPLOAD_ERR_PARTIAL => 'The uploaded file was only partially uploaded.',
        UPLOAD_ERR_NO_FILE => 'No file was uploaded.',
        UPLOAD_ERR_NO_TMP_DIR => 'Missing a temporary folder.',
        UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk.',
        UPLOAD_ERR_EXTENSION => 'A PHP extension stopped the file upload.'
    ];
    $msg = isset($messages[$err]) ? $messages[$err] : 'Unknown upload error code: ' . $err;
    http_response_code(400);
    echo "Upload error: " . $msg;
    exit;
}

// Try to move the uploaded file
if (!move_uploaded_file($file['tmp_name'], $tmpFilePath)) {
    // If we reach here, move_uploaded_file failed. Output diagnostics to help debug.
    http_response_code(500);
    $diagnostics = [];
    $diagnostics['filename'] = $fileName;
    $diagnostics['tmp_name'] = $file['tmp_name'];
    $diagnostics['is_uploaded_file'] = is_uploaded_file($file['tmp_name']) ? 'yes' : 'no';
    $diagnostics['tmp_exists'] = file_exists($file['tmp_name']) ? 'yes' : 'no';
    $diagnostics['tmp_dir'] = sys_get_temp_dir();
    $diagnostics['upload_max_filesize'] = ini_get('upload_max_filesize');
    $diagnostics['post_max_size'] = ini_get('post_max_size');
    $diagnostics['max_file_uploads'] = ini_get('max_file_uploads');
    $diagnostics['php_sapi'] = php_sapi_name();
    $diagnostics['target_dir_writable'] = is_writable($tmpDir) ? 'yes' : 'no';
    $perms = fileperms($tmpDir);
    if ($perms !== false) {
        $diagnostics['target_dir_perms'] = substr(sprintf('%o', $perms), -4);
    }
    $diagnostics['last_error'] = error_get_last();

    echo "Failed to move uploaded file. Diagnostics:\n";
    echo "---------------------------------\n";
    foreach ($diagnostics as $k => $v) {
        echo "$k: ";
        if (is_array($v)) {
            echo json_encode($v);
        } else {
            echo $v;
        }
        echo "\n";
    }

    exit;
}

// At this point the zip is saved into tmp, proceed to extract it
$extractDirName = uniqid('upload_') . '_' . time();
$extractDir = $tmpDir . '/' . $extractDirName;
if (!mkdir($extractDir, 0755, true)) {
    http_response_code(500);
    echo "Uploaded but failed to create extraction directory: " . $extractDir;
    exit;
}

$zip = new \ZipArchive();
$openRes = $zip->open($tmpFilePath);
if ($openRes !== true) {
    http_response_code(500);
    echo "Uploaded to: " . $tmpFilePath . "\n";
    echo "Failed to open ZIP archive. ZipArchive::open returned: " . $openRes . "\n";
    echo "You can inspect the uploaded file at: " . $tmpFilePath . "\n";
    exit;
}

if (!$zip->extractTo($extractDir)) {
    http_response_code(500);
    echo "Uploaded to: " . $tmpFilePath . "\n";
    echo "Failed to extract ZIP archive to: " . $extractDir . "\n";
    $zip->close();
    exit;
}

$zip->close();

// Success
echo "File uploaded successfully to: " . $tmpFilePath . "\n";
echo "Extracted to: " . $extractDir . "\n";
exit;
?>
