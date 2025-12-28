<?php
/**
 * Consolidated Issue Processing Script (Windows & Unix compatible)
 * Replaces: extract_cover.sh and process-issue.sh
 * 
 * Usage: php process_issue.php <pdf_directory> [cover_image_file] [base_path] [username]
 * 
 * Example:
 *   php process_issue.php "/path/to/pdfs" "cover.jpg" "/home/user/docs/PLATFORMA.EDITORIALA/DATE" "master"
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

// Get command-line arguments
$pdfDirectory = $argc > 1 ? $argv[1] : null;
$coverImageFile = $argc > 2 ? $argv[2] : null;
$basePath = $argc > 3 ? $argv[3] : null;
$username = $argc > 4 ? $argv[4] : 'master';

// Load .env file if it exists
$env = [];
$envFile = dirname(__DIR__) . '/.env';
if (file_exists($envFile)) {
    $env = parse_env_file($envFile);
    if (isset($env['BASE_PATH'])) {
        $basePath = $basePath ?? $env['BASE_PATH'];
    }
    if (isset($env['USERNAME'])) {
        $username = $username ?? $env['USERNAME'];
    }
}

// Parse CLI overrides for schema validation and verbosity
$noValidate = false;
$cliSchemaPath = null;
$verbose = false;
$quiet = false;

for ($i = 1; $i < $argc; $i++) {
    $arg = $argv[$i];
    if (strpos($arg, '--schema=') === 0) {
        $cliSchemaPath = substr($arg, strlen('--schema='));
    } elseif (strpos($arg, '--log-file=') === 0) {
        $cliLogPath = substr($arg, strlen('--log-file='));
    } elseif ($arg === '--no-validate' || $arg === '--no-validate=true') {
        $noValidate = true;
    } elseif ($arg === '--no-validate=false') {
        $noValidate = false;
    } elseif ($arg === '--verbose' || $arg === '--verbose=true') {
        $verbose = true;
    } elseif ($arg === '--quiet' || $arg === '--quiet=true') {
        $quiet = true;
    } elseif ($arg === '--quiet=false') {
        $quiet = false;
    }
}

// Open log file if requested via CLI
$logHandle = null;
if (!empty($cliLogPath)) {
    $dir = dirname($cliLogPath);
    if (!is_dir($dir)) {
        // try to create directory
        @mkdir($dir, 0755, true);
    }
    $logHandle = @fopen($cliLogPath, 'a');
    if ($logHandle === false) {
        fwrite(STDERR, "Error: Could not open log file for writing: $cliLogPath\n");
        exit(1);
    }
}

// Handle help flag early
if (in_array('--help', $argv) || in_array('-h', $argv)) {
    echo "process_issue.php - Process an unzipped issue folder and generate OJS issues XML\n";
    echo "\nUsage:\n";
    echo "  php process_issue.php <pdf_directory> [cover_image_file] [base_path] [username] [--schema=/path/to/schema.xsd] [--no-validate]\n";
    echo "\nArguments:\n";
    echo "  <pdf_directory>    Path to the folder containing PDFs and a CSV (required).\n";
    echo "  [cover_image_file] Optional cover image filename (e.g. cover.jpg).\n";
    echo "  [base_path]        Base path to the ojsxml installation (default from .env or project default).\n";
    echo "  [username]         Username for processing (default: master).\n";
    echo "\nFlags:\n";
    echo "  --schema=PATH      Override schema XSD path (absolute or relative).\n";
    echo "  --no-validate      Skip XSD validation (not recommended for production).\n";
    echo "  --verbose          Show extra debug output.\n";
    echo "  --quiet            Suppress non-error output.\n";
    echo "  -h, --help         Show this help message.\n";
    echo "\nExamples:\n";
    echo "  php process_issue.php \"./tmp/myissue\" cover.jpg --schema=./schema/schema_3_5.xsd\n";
    echo "  php process_issue.php \"./tmp/myissue\" --no-validate\n";
    exit(0);
}

// Set defaults
$basePath = $basePath ?? '/home/nicolaie/Documents/PLATFORMA.EDITORIALA/DATE';
$username = $username ?? 'master';

// Validate inputs
if (!$pdfDirectory) {
    die("Error: PDF directory argument is required.\n");
}

if (!is_dir($pdfDirectory)) {
    die("Error: Directory '$pdfDirectory' not found.\n");
}

// Set up output directories
$jpgOutputDirectory = $basePath . '/ojsxml/docroot/csv/abstracts/issue_cover_images';
$pdfOutputDirectory = $basePath . '/ojsxml/docroot/csv/abstracts/article_galleys';
$csvOutputDirectory = $basePath . '/ojsxml/docroot/csv/abstracts';
$outputDirectory = $basePath . '/ojsxml/docroot/output';

// Create output directories
foreach ([$jpgOutputDirectory, $pdfOutputDirectory, $csvOutputDirectory, $outputDirectory] as $dir) {
    if (!is_dir($dir)) {
        if (!mkdir($dir, 0755, true)) {
            die("Error: Failed to create directory '$dir'.\n");
        }
    }
}

// Clear output directories (except .gitkeep)
clear_directory($jpgOutputDirectory);
clear_directory($pdfOutputDirectory);
clear_directory($csvOutputDirectory);

// Output helpers (honor --quiet and --verbose)

// If log file handle is present, ensure helpers also write into it
function log_write($msg) {
    global $logHandle;
    if (!empty($logHandle) && is_resource($logHandle)) {
        fwrite($logHandle, $msg);
    }
}

// wrap existing output functions to also write to log file when provided
$orig_out = null; // no-op placeholder
function out($msg) {
    global $quiet, $logHandle;
    if (empty($quiet)) {
        echo $msg;
    }
    if (!empty($logHandle) && is_resource($logHandle)) {
        fwrite($logHandle, $msg);
    }
}

function dbg($msg) {
    global $verbose, $quiet, $logHandle;
    if (!empty($verbose) && empty($quiet)) {
        echo $msg;
    }
    if (!empty($logHandle) && is_resource($logHandle)) {
        fwrite($logHandle, $msg);
    }
}

function err($msg) {
    global $logHandle;
    fwrite(STDERR, $msg);
    if (!empty($logHandle) && is_resource($logHandle)) {
        fwrite($logHandle, $msg);
    }
}

out("=== Processing Issue ===\n");
out("PDF Directory: $pdfDirectory\n");
out("Base Path: $basePath\n");
out("Username: $username\n\n");

// Step 1: Extract first page of PDFs as JPEGs
$out_msg = "Step 1: Extracting first page of PDFs...\n";
out($out_msg);
$pdfFiles = glob($pdfDirectory . '/*.pdf');

if (empty($pdfFiles)) {
    die("Error: No PDF files found in '$pdfDirectory'.\n");
}

foreach ($pdfFiles as $pdfFile) {
    $filename = basename($pdfFile, '.pdf');
    $outputJpg = $jpgOutputDirectory . '/' . $filename . '.jpg';
    
    // Try pdftocairo first (preferred), fall back to ImageMagick convert
    $success = false;
    
    if (command_exists('pdftocairo')) {
        $cmd = build_command([
            'pdftocairo',
            '-jpeg',
            '-singlefile',
            '-f', '1',
            '-l', '1',
            '-scale-to-x', '600',
            '-scale-to-y', '-1',
            $pdfFile,
            $jpgOutputDirectory . '/' . $filename
        ]);
        
        $output = [];
        $returnCode = null;
        exec($cmd, $output, $returnCode);
        
        if ($returnCode === 0) {
            out("  Processed: $pdfFile -> $outputJpg\n");
            $success = true;
        }
    }
    
    if (!$success && command_exists('convert')) {
        $cmd = build_command([
            'convert',
            '-density', '300',
            '-quality', '100',
            $pdfFile . '[0]',
            $outputJpg
        ]);
        
        $output = [];
        $returnCode = null;
        exec($cmd, $output, $returnCode);
        
        if ($returnCode === 0) {
            out("  Processed (ImageMagick): $pdfFile -> $outputJpg\n");
            $success = true;
        }
    }
    
    if (!$success) {
        out("  Warning: Could not process $pdfFile (pdftocairo or convert not available).\n");
        continue;
    }

    // Copy PDF to output directory
    if (!copy($pdfFile, $pdfOutputDirectory . '/' . basename($pdfFile))) {
        err("  Error: Could not copy $pdfFile to output directory.\n");
    }
}

out("\nStep 2: Finding and copying CSV file...\n");

// Step 2: Find and copy CSV file
$csvFile = find_file($pdfDirectory, '*.csv');

if (!$csvFile) {
    err("Error: No CSV file found in '$pdfDirectory'.\n");
    exit(1);
}

out("  Found CSV file: $csvFile\n");

if (!copy($csvFile, $csvOutputDirectory . '/' . basename($csvFile))) {
    err("Error: Failed to copy CSV file.\n");
    exit(1);
}

out("  Copied to: $csvOutputDirectory\n");

// Step 3: Find and copy cover image (if specified)
out("\nStep 3: Finding and copying cover image...\n");
// Try to detect the cover image in multiple ways:
// 1. If user provided a name, try that exact file and basename variants
// 2. Prefer a file called 'cover.jpg'
// 3. Prefer a jpg with the same base name as any PDF
// 4. Fallback to any jpg/jpeg in the directory

$detectedCover = null;
// Build candidate list
$candidates = [];
if ($coverImageFile) {
    // exact path provided
    $candidates[] = $pdfDirectory . '/' . $coverImageFile;
    // basename with jpg extension
    $candidates[] = $pdfDirectory . '/' . pathinfo($coverImageFile, PATHINFO_FILENAME) . '.jpg';
    $candidates[] = $pdfDirectory . '/' . pathinfo($coverImageFile, PATHINFO_FILENAME) . '.jpeg';
}

// prefer cover.jpg
$candidates[] = $pdfDirectory . '/cover.jpg';
$candidates[] = $pdfDirectory . '/cover.jpeg';

// prefer jpg with same basename as PDFs
foreach (glob($pdfDirectory . '/*.pdf') as $pdfFile) {
    $base = basename($pdfFile, '.pdf');
    $candidates[] = $pdfDirectory . '/' . $base . '.jpg';
    $candidates[] = $pdfDirectory . '/' . $base . '.jpeg';
}

// finally any jpg/jpeg in directory
$jpgs = glob($pdfDirectory . '/*.{jpg,jpeg,JPG,JPEG}', GLOB_BRACE);
if (!empty($jpgs)) {
    foreach ($jpgs as $j) {
        $candidates[] = $j;
    }
}

// find first existing candidate
foreach ($candidates as $cand) {
    if ($cand && file_exists($cand) && is_file($cand)) {
        $detectedCover = $cand;
        break;
    }
}

if ($detectedCover) {
    out("  Found cover image: $detectedCover\n");
    if (!copy($detectedCover, $csvOutputDirectory . '/' . basename($detectedCover))) {
        out("  Warning: Failed to copy cover image.\n");
    } else {
        out("  Copied to: $csvOutputDirectory\n");
    }
} else {
    out("  No cover image found in '$pdfDirectory'.\n");
}

// Duplicate the detected cover to the expected '<csvbasename>-cover.jpg' name
// so the CSV-to-XML converter (and IssuesXmlBuilder) finds the canonical cover filename.
if (!empty($detectedCover) && !empty($csvFile)) {
    $csvBase = pathinfo($csvFile, PATHINFO_FILENAME);
    $expectedCoverPath = $csvOutputDirectory . '/' . $csvBase . '-cover.jpg';

    if (!file_exists($expectedCoverPath)) {
        if (copy($detectedCover, $expectedCoverPath)) {
            out("  Also copied detected cover to expected name: $expectedCoverPath\n");
        } else {
            out("  Warning: Failed to copy detected cover to expected name: $expectedCoverPath\n");
        }
    } else {
        out("  Expected cover already exists: $expectedCoverPath\n");
    }
}

// Step 4: Run PHP CSV to XML converter
out("\nStep 4: Converting CSV to XML...\n");

$csvConverterScript = $basePath . '/ojsxml/app/csvToXmlConverter.php';

if (!file_exists($csvConverterScript)) {
    die("Error: CSV converter script not found at '$csvConverterScript'.\n");
}

$rootDirectory = $basePath . '/ojsxml/docroot/csv/abstracts';

// Build command to run the CSV converter
$phpCmd = build_command([
    'php',
    $csvConverterScript,
    'issues',
    $username,
    $rootDirectory,
    $outputDirectory
]);

out("  Running: $phpCmd\n");

$output = [];
$returnCode = null;
exec($phpCmd, $output, $returnCode);

if ($returnCode !== 0) {
    err("  Error: PHP converter returned code $returnCode.\n");
    if (!empty($output)) {
        err("  Output: " . implode("\n", $output) . "\n");
    }
    exit(1);
}

out("  CSV converter completed successfully.\n");

// Check if output XML was created (check for any XML file or the .last_xml_filename marker)
$filenameFile = $outputDirectory . '/.last_xml_filename';
$xmlOutputFile = null;

if (file_exists($filenameFile)) {
    $xmlFilename = trim(file_get_contents($filenameFile));
    $xmlOutputFile = $outputDirectory . '/' . $xmlFilename;
} else {
    // Fallback: find any XML file in output directory
    $xmlFiles = glob($outputDirectory . '/*.xml');
    if (!empty($xmlFiles)) {
        $xmlOutputFile = $xmlFiles[0];
    }
}

if ($xmlOutputFile && file_exists($xmlOutputFile)) {
    echo "\n✓ Success! XML file created: $xmlOutputFile\n";

    // PHP-based XSD validation using DOMDocument::schemaValidate (mandatory)
    echo "\nStep 5: Validating XML against XSD (PHP DOM) - mandatory...\n";

    // Resolve schema path: prefer CLI --schema, then SCHEMA_PATH from .env, otherwise fallback to output/schema_3_5.xsd
    $schemaPath = $cliSchemaPath ?? ($env['SCHEMA_PATH'] ?? null);

    if ($noValidate) {
        echo "  Validation skipped by CLI (--no-validate).\n";
    } else {
    $resolvedXsd = null;
    if (!empty($schemaPath)) {
        // try provided path as-is
        if (file_exists($schemaPath) && is_file($schemaPath)) {
            $resolvedXsd = $schemaPath;
        }
        // try relative to basePath
        if (!$resolvedXsd && file_exists($basePath . '/' . $schemaPath) && is_file($basePath . '/' . $schemaPath)) {
            $resolvedXsd = $basePath . '/' . $schemaPath;
        }
        // try relative to script dir
        if (!$resolvedXsd && file_exists(__DIR__ . '/' . $schemaPath) && is_file(__DIR__ . '/' . $schemaPath)) {
            $resolvedXsd = __DIR__ . '/' . $schemaPath;
        }
    }

    // fallback to default schema in output directory
    if (!$resolvedXsd && file_exists($outputDirectory . '/schema_3_5.xsd') && is_file($outputDirectory . '/schema_3_5.xsd')) {
        $resolvedXsd = $outputDirectory . '/schema_3_5.xsd';
    }

            if (!$resolvedXsd) {
                err("  Error: No XSD schema found. Set SCHEMA_PATH in .env or place schema_3_5.xsd in '$outputDirectory'.\n");
                exit(1);
            }

            if (!class_exists('DOMDocument') || !method_exists('DOMDocument', 'schemaValidate')) {
                err("  Error: PHP DOMDocument::schemaValidate not available in this PHP build. Cannot validate XML.\n");
                exit(1);
            }

    libxml_use_internal_errors(true);
    $dom = new DOMDocument();
    $loaded = $dom->load($xmlOutputFile);
    if (!$loaded) {
        echo "  Error: Failed to load XML for validation.\n";
        $errors = libxml_get_errors();
        foreach ($errors as $err) {
            echo "    ", trim($err->message), " on line ", $err->line, "\n";
        }
        libxml_clear_errors();
        exit(1);
    }

    $isValid = @$dom->schemaValidate($resolvedXsd);
        if ($isValid) {
            out("  XML is valid according to schema: $resolvedXsd\n");
        } else {
            err("  XML FAILED validation against schema: $resolvedXsd\n");
            $errors = libxml_get_errors();
            if (!empty($errors)) {
                foreach ($errors as $err) {
                    err("    [" . $err->level . "] " . trim($err->message) . " on line " . $err->line . "\n");
                }
            } else {
                err("    (no libxml errors available)\n");
            }
            libxml_clear_errors();
            exit(1);
        }
        libxml_clear_errors();
    }

} else {
    echo "\n✗ Warning: XML file was not created at $xmlOutputFile\n";
    exit(1);
}

echo "\n=== SUCCESS ===\n";
echo "=== Processing Complete ===\n";

exit(0);

/**
 * Parse a simple .env file
 */
function parse_env_file($filePath) {
    $env = [];
    if (!file_exists($filePath)) {
        return $env;
    }
    
    $lines = file($filePath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        // Skip comments
        if (strpos(trim($line), '#') === 0) {
            continue;
        }
        
        if (strpos($line, '=') === false) {
            continue;
        }
        
        list($key, $value) = explode('=', $line, 2);
        $key = trim($key);
        $value = trim($value);
        
        // Remove quotes if present
        if ((substr($value, 0, 1) === '"' && substr($value, -1) === '"') ||
            (substr($value, 0, 1) === "'" && substr($value, -1) === "'")) {
            $value = substr($value, 1, -1);
        }
        
        $env[$key] = $value;
    }
    
    return $env;
}

/**
 * Find a file matching a pattern in a directory
 */
function find_file($directory, $pattern) {
    $files = glob($directory . '/' . $pattern);
    
    if (empty($files)) {
        return null;
    }
    
    // Return the first file found
    foreach ($files as $file) {
        if (is_file($file)) {
            return $file;
        }
    }
    
    return null;
}

/**
 * Clear a directory (except .gitkeep)
 */
function clear_directory($directory) {
    if (!is_dir($directory)) {
        return;
    }
    // Recursively remove files and directories, but keep any .gitkeep files
    $it = new RecursiveDirectoryIterator($directory, RecursiveDirectoryIterator::SKIP_DOTS);
    $files = new RecursiveIteratorIterator($it, RecursiveIteratorIterator::CHILD_FIRST);
    foreach ($files as $fileinfo) {
        $path = $fileinfo->getPathname();
        if ($fileinfo->isFile()) {
            if (basename($path) === '.gitkeep') {
                continue;
            }
            @unlink($path);
        } elseif ($fileinfo->isDir()) {
            // attempt to remove directory if empty after file removals
            @rmdir($path);
        }
    }
}

/**
 * Check if a command exists in the system
 */
function command_exists($cmd) {
    if (PHP_OS_FAMILY === 'Windows') {
        $output = [];
        $returnCode = null;
        exec('where ' . escapeshellarg($cmd), $output, $returnCode);
        return $returnCode === 0;
    } else {
        $output = [];
        $returnCode = null;
        exec('which ' . escapeshellarg($cmd), $output, $returnCode);
        return $returnCode === 0;
    }
}

/**
 * Build a shell command with proper escaping
 */
function build_command($args) {
    if (PHP_OS_FAMILY === 'Windows') {
        // Windows command line
        return implode(' ', array_map('escapeshellarg', $args));
    } else {
        // Unix-like
        return implode(' ', array_map('escapeshellarg', $args));
    }
}
?>
