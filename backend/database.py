import ssl as ssl_module
from urllib.parse import urlparse, parse_qs

import asyncpg
from config import DATABASE_URL

pool: asyncpg.Pool | None = None


def _needs_ssl(url: str) -> bool:
    qs = parse_qs(urlparse(url).query)
    return qs.get("sslmode", ["disable"])[0] in ("require", "verify-ca", "verify-full")


def _strip_query(url: str) -> str:
    """asyncpg doesn't understand all PG query params (e.g. channel_binding),
    so strip them and handle ssl separately."""
    p = urlparse(url)
    return p._replace(query="").geturl()


async def init_db():
    global pool

    clean_dsn = _strip_query(DATABASE_URL)
    ssl_ctx = ssl_module.create_default_context() if _needs_ssl(DATABASE_URL) else False

    pool = await asyncpg.create_pool(
        dsn=clean_dsn,
        ssl=ssl_ctx,
        min_size=2,
        max_size=10,
    )

    async with pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                username VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS designs (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                title VARCHAR(255) NOT NULL,
                description TEXT DEFAULT '',
                image_filename VARCHAR(500) NOT NULL,
                tags TEXT DEFAULT '',
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS favorites (
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                design_id INTEGER NOT NULL REFERENCES designs(id) ON DELETE CASCADE,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                PRIMARY KEY (user_id, design_id)
            )
        """)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS saved_designs (
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                design_id INTEGER NOT NULL REFERENCES designs(id) ON DELETE CASCADE,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                PRIMARY KEY (user_id, design_id)
            )
        """)

    print("Database tables initialized")


async def close_db():
    global pool
    if pool:
        await pool.close()
