#!/bin/bash
set -eu
S=/opt/cbox-bench
APP="/opt/cbox-bench/lv-app"
echo "=== Bygger ægte Laravel-fixture ==="
rm -rf "$APP"; mkdir -p "$APP"
docker run --rm -v "$APP:/var/www/html" -w /var/www/html ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1 sh -c '
  set -e
  composer create-project laravel/laravel . --no-interaction --prefer-dist --quiet 2>&1 | tail -2
  # Benchmark-route: web-middleware (realistisk) + sqlite-query + transform
  cat > routes/web.php <<PHP
<?php
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
Route::get("/", fn() => response()->json(["ok" => true]));
Route::get("/items", function () {
    \$items = DB::table("items")->orderBy("id")->limit(50)->get();
    return response()->json([
        "count" => \$items->count(),
        "total" => \$items->sum("price"),
        "items" => \$items->map(fn(\$i) => [
            "id" => \$i->id, "name" => strtoupper(\$i->name),
            "price" => number_format(\$i->price, 2),
        ]),
    ]);
});
PHP
  # Prod-env: sqlite, array-drivere (ingen session-IO-stoej), debug off
  sed -i "s/^APP_ENV=.*/APP_ENV=production/; s/^APP_DEBUG=.*/APP_DEBUG=false/; s/^SESSION_DRIVER=.*/SESSION_DRIVER=array/; s/^CACHE_STORE=.*/CACHE_STORE=array/; s/^LOG_LEVEL=.*/LOG_LEVEL=error/" .env
  touch database/database.sqlite
  php artisan migrate --force --quiet 2>&1 | tail -1
  php -r "
    \$pdo = new PDO(\"sqlite:database/database.sqlite\");
    \$pdo->exec(\"CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, name TEXT, price REAL, created_at TEXT)\");
    \$st = \$pdo->prepare(\"INSERT INTO items (name, price, created_at) VALUES (?, ?, datetime())\");
    for (\$i = 1; \$i <= 200; \$i++) \$st->execute([\"item-\$i\", \$i * 1.37]);
    echo \"seeded: \" . \$pdo->query(\"SELECT COUNT(*) FROM items\")->fetchColumn() . \" rows\n\";
  "
  php artisan route:cache --quiet # config:cache deliberately NOT run: it bakes build-time env
  chmod -R 777 storage bootstrap/cache database
  echo "fixture-check: $(php artisan --version)"
'
du -sh "$APP"
echo "LARAVEL-FIXTURE-KLAR"
