<?php
/**
 * The PHP limits a web request actually runs with.
 *
 * These are pinned by the FPM pool as php_admin_value, so reading them from
 * the CLI (docker exec php -r ...) proves nothing about a request. They have
 * to be read through nginx and PHP-FPM, which is what this file is for.
 */

header('Content-Type: text/plain');

foreach (['memory_limit', 'upload_max_filesize', 'post_max_size', 'max_file_uploads', 'max_execution_time', 'max_input_time'] as $directive) {
    echo $directive, '=', ini_get($directive), "\n";
}
