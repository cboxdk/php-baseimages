---
title: "Multi-Tenant Setup"
description: "Single codebase serving multiple tenants with database-per-tenant isolation"
weight: 9
---

# Multi-Tenant Setup

SaaS architecture with database-per-tenant isolation using packages like Tenancy for Laravel.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Load Balancer                     │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                   App Server                         │
│            (Tenant Resolution)                       │
└──────────────────────┬──────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
┌───────▼──────┐  ┌────▼────┐  ┌──────▼──────┐
│ Central DB   │  │  Redis  │  │ Tenant DBs  │
│ (Registry)   │  │ (Cache) │  │ (Per-tenant)│
└──────────────┘  └─────────┘  └─────────────┘
```

## Quick Start

```bash
# Start services
docker compose up -d

# Install tenancy package
docker compose exec app composer require stancl/tenancy

# Setup tenancy
docker compose exec app php artisan tenancy:install
docker compose exec app php artisan migrate

# Create a tenant
docker compose exec app php artisan tinker
>>> App\Models\Tenant::create(['id' => 'acme']);
>>> exit
```

## Tenant Resolution

### By Domain

```php
// config/tenancy.php
'identification' => [
    'domain' => [
        'enabled' => true,
    ],
],

// Tenant domains: acme.yourdomain.com, widgets.yourdomain.com
```

### By Subdomain

```php
// routes/tenant.php
Route::domain('{tenant}.yourdomain.com')->group(function () {
    Route::get('/', 'DashboardController@index');
});
```

### By Path

```php
// routes/web.php
Route::prefix('{tenant}')->group(function () {
    Route::get('/dashboard', 'DashboardController@index');
});
```

## Database Strategy

### Database Per Tenant (Recommended)

```php
// Each tenant gets their own database
// Tenant: acme → Database: tenant_acme
// Tenant: widgets → Database: tenant_widgets
```

### Schema Per Tenant (PostgreSQL)

```php
// Shared database, separate schemas
// Tenant: acme → Schema: acme
// Tenant: widgets → Schema: widgets
```

## Common Commands

```bash
# List all tenants
docker compose exec app php artisan tenant:list

# Run migrations for all tenants
docker compose exec app php artisan tenants:migrate

# Run seeder for specific tenant
docker compose exec app php artisan tenants:seed --tenants=acme

# Run artisan command for tenant
docker compose exec app php artisan tenants:artisan "cache:clear" --tenant=acme
```

## Job Queue Isolation

```php
// In your Job class
class ProcessOrder implements ShouldQueue
{
    public $tenantId;

    public function __construct()
    {
        $this->tenantId = tenant('id');
    }

    public function handle()
    {
        tenancy()->initialize($this->tenantId);
        // Process order in tenant context
    }
}
```

## Cache Isolation

```php
// config/tenancy.php
'cache' => [
    'tag_base' => 'tenant_',
],

// Usage - automatically scoped to tenant
Cache::put('key', 'value');
// Actually stored as: tenant_acme:key
```

## Production Considerations

- **Database connections**: Pool connections carefully
- **Migrations**: Test on staging tenant first
- **Backups**: Per-tenant backup strategy
- **Monitoring**: Separate metrics per tenant
- **Rate limiting**: Per-tenant limits
