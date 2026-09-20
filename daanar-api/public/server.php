<?php

// Uses __DIR__ instead of getcwd() so the path is always correct
// regardless of where PHP was launched from.
$publicPath = __DIR__;

$uri = urldecode(
    parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? ''
);

// Serve static files (css, js, images, fonts) directly
if ($uri !== '/' && file_exists($publicPath . $uri)) {
    return false;
}

require_once $publicPath . '/index.php';
