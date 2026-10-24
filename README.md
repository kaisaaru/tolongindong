# TolonginDong

TolonginDong is an on-demand daily task marketplace application connecting clients with verified local helpers for immediate, hourly, or daily assistance.

## Supported Services

The platform supports 3 primary service categories:
- **Delivery**: Fast courier and item or document transport within the city.
- **Personal**: Daily personal assistance and administrative tasks.
- **Household**: Home maintenance, domestic chores, and cleaning support.

## Repository Structure

This repository is organized as a monorepo:

```text
tolongindong/
├── apps/
│   ├── api/       # Backend API engine (Laravel 11, PHP 8.4, PostgreSQL)
│   └── mobile/    # Mobile client application (Flutter)
└── docs/          # Project requirements and design artifacts
```

## Technology Stack

### Backend (`apps/api`)
- **Framework**: Laravel 11 (PHP 8.4+)
- **Database**: PostgreSQL with strict integrity constraints
- **Authentication**: Laravel Sanctum (Bearer Token)
- **Object Storage**: Cloudflare R2 (S3-compatible)
- **Architecture**: Controller-Repository-Service pattern with atomic escrow transactions

### Mobile (`apps/mobile`)
- **Framework**: Flutter (Dart)
- **Target Platforms**: Android & iOS
- **Features**: Dual-role experience (Client & Helper Mode), chat messaging, and wallet integration

## Local Development Setup

### Backend Setup

```bash
cd apps/api
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

### Mobile Setup

```bash
cd apps/mobile
flutter pub get
flutter run
```

## Running Tests

To run the backend automated feature test suite:

```bash
cd apps/api
php artisan test
```
