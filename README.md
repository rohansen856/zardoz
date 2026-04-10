# Zardoz — Embroidery Design Sharing & Projection

A Flutter application for artisans to share embroidery designs and project them onto fabric using a connected projector.

## Architecture

```
zardoz/
├── lib/              # Flutter frontend
│   ├── config/       # API config, theme
│   ├── models/       # User, Design data models
│   ├── services/     # API client, auth state
│   ├── screens/      # All app screens
│   └── widgets/      # Reusable UI components
├── backend/          # Python FastAPI REST API server
│   ├── main.py       # Routes & app entry point
│   ├── database.py   # asyncpg pool & table init
│   ├── config.py     # Env var loading
│   ├── .env          # Environment variables
│   └── init.sql      # PostgreSQL schema (optional manual setup)
└── assets/           # Logo and branding images
```

## Prerequisites

- Flutter SDK (>=3.11)
- Python 3.10+
- PostgreSQL (running on localhost:5432)

## Database Setup

1. Install and start PostgreSQL
2. Create the database:

```bash
createdb -U postgres zardoz
```

Tables are auto-created when the backend starts. For manual setup:

```bash
psql -U postgres -d zardoz -f backend/init.sql
```

### Environment Variables

Copy the example and edit as needed:

```bash
cd backend
cp .env.example .env
```

| Variable    | Default     | Description            |
|-------------|-------------|------------------------|
| DB_HOST     | localhost   | PostgreSQL host        |
| DB_PORT     | 5432        | PostgreSQL port        |
| DB_NAME     | zardoz      | Database name          |
| DB_USER     | postgres    | Database user          |
| DB_PASS     | postgres    | Database password      |
| PORT        | 8080        | API server port        |
| UPLOADS_DIR | uploads     | Image upload directory |

## Running the Backend

```bash
cd backend
pip install -r requirements.txt
python3 main.py
```

The API server starts on `http://localhost:8080` with auto-reload enabled.
Interactive docs available at `http://localhost:8080/docs`.

## Running the Flutter App

```bash
flutter pub get
flutter run
```

For Linux desktop (recommended for projector use):

```bash
flutter run -d linux
```

## API Endpoints

| Method | Endpoint                      | Description               |
|--------|-------------------------------|---------------------------|
| POST   | /api/auth/login               | Login / register          |
| GET    | /api/designs                  | List all designs          |
| GET    | /api/designs/:id              | Get design detail         |
| POST   | /api/designs                  | Upload new design         |
| DELETE | /api/designs/:id              | Delete own design         |
| GET    | /api/images/:filename         | Serve design image        |
| POST   | /api/designs/:id/favorite     | Toggle favorite           |
| GET    | /api/favorites                | List favorites            |
| POST   | /api/designs/:id/save         | Toggle saved              |
| GET    | /api/saved                    | List saved designs        |
| GET    | /api/users/:id                | User profile              |
| GET    | /api/users/:id/designs        | User's designs            |
| GET    | /api/search?q=query           | Search designs            |

Authentication is via `X-User-Id` header (set automatically after login).

## Features

- **Share designs** — Upload embroidery designs with title, description, and tags
- **Browse & search** — Discover designs from other artisans
- **Favorites & saved** — Bookmark designs for later
- **Projection mode** — Fullscreen display optimized for projectors with:
  - Pinch-to-zoom and pan
  - Rotation control (continuous + 90° snaps)
  - Opacity adjustment
  - Color inversion (for light-on-dark projection)
  - Horizontal mirror flip
  - Grid overlay with center crosshair
- **Login** — Simple name + username authentication (no password)
