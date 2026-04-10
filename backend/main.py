from __future__ import annotations

import asyncio
import base64
import re
import uuid
from contextlib import asynccontextmanager

import cloudinary
import cloudinary.uploader
from fastapi import FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from config import (
    CLOUDINARY_API_KEY,
    CLOUDINARY_API_SECRET,
    CLOUDINARY_CLOUD_NAME,
    PORT,
)
import database
from database import close_db, init_db


# ---------------------------------------------------------------------------
# Cloudinary helpers
# ---------------------------------------------------------------------------

def _configure_cloudinary():
    cloudinary.config(
        cloud_name=CLOUDINARY_CLOUD_NAME,
        api_key=CLOUDINARY_API_KEY,
        api_secret=CLOUDINARY_API_SECRET,
        secure=True,
    )


async def _upload_image(image_b64: str) -> tuple[str, str]:
    """Upload base64 image to Cloudinary. Returns (secure_url, public_id)."""
    public_id = f"zardoz/{uuid.uuid4()}"
    result = await asyncio.to_thread(
        cloudinary.uploader.upload,
        f"data:image/png;base64,{image_b64}",
        public_id=public_id,
        overwrite=True,
    )
    return result["secure_url"], result["public_id"]


async def _delete_image(image_url: str):
    """Extract public_id from Cloudinary URL and delete the asset."""
    m = re.search(r"/upload/v\d+/(.+)\.\w+$", image_url)
    if not m:
        return
    public_id = m.group(1)
    try:
        await asyncio.to_thread(cloudinary.uploader.destroy, public_id)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Lifespan
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(_app: FastAPI):
    _configure_cloudinary()
    await init_db()
    yield
    await close_db()


app = FastAPI(title="Zardoz API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------

class LoginBody(BaseModel):
    name: str
    username: str


class CreateDesignBody(BaseModel):
    title: str
    description: str = ""
    image: str  # base64-encoded
    tags: str = ""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _uid(x_user_id: str | None) -> int | None:
    if x_user_id is None:
        return None
    try:
        return int(x_user_id)
    except ValueError:
        return None


def _require_uid(x_user_id: str | None) -> int:
    uid = _uid(x_user_id)
    if uid is None:
        raise HTTPException(401, "Authentication required")
    return uid


DESIGN_SELECT = """
    SELECT d.id, d.user_id, d.title, d.description, d.image_filename, d.tags,
           d.created_at, u.name AS author_name, u.username AS author_username,
           EXISTS(SELECT 1 FROM favorites f WHERE f.design_id = d.id AND f.user_id = $1) AS is_favorited,
           EXISTS(SELECT 1 FROM saved_designs s WHERE s.design_id = d.id AND s.user_id = $1) AS is_saved
    FROM designs d JOIN users u ON d.user_id = u.id
"""


def _design_row(r) -> dict:
    return {
        "id": r["id"],
        "user_id": r["user_id"],
        "title": r["title"],
        "description": r["description"],
        "image_url": r["image_filename"],
        "tags": r["tags"],
        "created_at": str(r["created_at"]),
        "author_name": r["author_name"],
        "author_username": r["author_username"],
        "is_favorited": r["is_favorited"],
        "is_saved": r["is_saved"],
    }


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

@app.post("/api/auth/login")
async def login(body: LoginBody):
    name = body.name.strip()
    username = body.username.strip().lower()
    if not name or not username:
        raise HTTPException(400, "Name and username are required")

    async with database.pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, name, username, created_at FROM users WHERE username = $1",
            username,
        )
        if row:
            return {
                "id": row["id"],
                "name": row["name"],
                "username": row["username"],
                "created_at": str(row["created_at"]),
            }

        row = await conn.fetchrow(
            "INSERT INTO users (name, username) VALUES ($1, $2) "
            "RETURNING id, name, username, created_at",
            name, username,
        )
        return JSONResponse(
            status_code=201,
            content={
                "id": row["id"],
                "name": row["name"],
                "username": row["username"],
                "created_at": str(row["created_at"]),
            },
        )


# ---------------------------------------------------------------------------
# Designs CRUD
# ---------------------------------------------------------------------------

@app.get("/api/designs")
async def get_designs(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    x_user_id: str | None = Header(None),
):
    uid = _uid(x_user_id) or 0
    offset = (page - 1) * limit
    async with database.pool.acquire() as conn:
        rows = await conn.fetch(
            DESIGN_SELECT + " ORDER BY d.created_at DESC LIMIT $2 OFFSET $3",
            uid, limit, offset,
        )
    return [_design_row(r) for r in rows]


@app.get("/api/designs/{design_id}")
async def get_design(design_id: int, x_user_id: str | None = Header(None)):
    uid = _uid(x_user_id) or 0
    async with database.pool.acquire() as conn:
        row = await conn.fetchrow(
            DESIGN_SELECT + " WHERE d.id = $2", uid, design_id,
        )
    if not row:
        raise HTTPException(404, "Design not found")
    return _design_row(row)


@app.post("/api/designs", status_code=201)
async def create_design(body: CreateDesignBody, x_user_id: str | None = Header(None)):
    uid = _require_uid(x_user_id)
    title = body.title.strip()
    if not title or not body.image:
        raise HTTPException(400, "Title and image are required")

    secure_url, _ = await _upload_image(body.image)

    async with database.pool.acquire() as conn:
        row = await conn.fetchrow(
            "INSERT INTO designs (user_id, title, description, image_filename, tags) "
            "VALUES ($1, $2, $3, $4, $5) RETURNING id, created_at",
            uid, title, body.description.strip(), secure_url, body.tags.strip(),
        )
    return {
        "id": row["id"],
        "title": title,
        "image_url": secure_url,
        "created_at": str(row["created_at"]),
    }


@app.delete("/api/designs/{design_id}")
async def delete_design(design_id: int, x_user_id: str | None = Header(None)):
    uid = _require_uid(x_user_id)
    async with database.pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT image_filename FROM designs WHERE id = $1 AND user_id = $2",
            design_id, uid,
        )
        if not row:
            raise HTTPException(404, "Design not found or not authorized")

        await _delete_image(row["image_filename"])
        await conn.execute("DELETE FROM designs WHERE id = $1", design_id)

    return {"deleted": True}


# ---------------------------------------------------------------------------
# Favorites
# ---------------------------------------------------------------------------

@app.post("/api/designs/{design_id}/favorite")
async def toggle_favorite(design_id: int, x_user_id: str | None = Header(None)):
    uid = _require_uid(x_user_id)
    async with database.pool.acquire() as conn:
        existing = await conn.fetchrow(
            "SELECT 1 FROM favorites WHERE user_id = $1 AND design_id = $2",
            uid, design_id,
        )
        if existing:
            await conn.execute(
                "DELETE FROM favorites WHERE user_id = $1 AND design_id = $2",
                uid, design_id,
            )
            return {"favorited": False}

        await conn.execute(
            "INSERT INTO favorites (user_id, design_id) VALUES ($1, $2)",
            uid, design_id,
        )
        return {"favorited": True}


@app.get("/api/favorites")
async def get_favorites(x_user_id: str | None = Header(None)):
    uid = _require_uid(x_user_id)
    async with database.pool.acquire() as conn:
        rows = await conn.fetch(
            DESIGN_SELECT
            + " JOIN favorites fv ON fv.design_id = d.id"
            " WHERE fv.user_id = $1 ORDER BY fv.created_at DESC",
            uid,
        )
    return [_design_row(r) for r in rows]


# ---------------------------------------------------------------------------
# Saved
# ---------------------------------------------------------------------------

@app.post("/api/designs/{design_id}/save")
async def toggle_save(design_id: int, x_user_id: str | None = Header(None)):
    uid = _require_uid(x_user_id)
    async with database.pool.acquire() as conn:
        existing = await conn.fetchrow(
            "SELECT 1 FROM saved_designs WHERE user_id = $1 AND design_id = $2",
            uid, design_id,
        )
        if existing:
            await conn.execute(
                "DELETE FROM saved_designs WHERE user_id = $1 AND design_id = $2",
                uid, design_id,
            )
            return {"saved": False}

        await conn.execute(
            "INSERT INTO saved_designs (user_id, design_id) VALUES ($1, $2)",
            uid, design_id,
        )
        return {"saved": True}


@app.get("/api/saved")
async def get_saved(x_user_id: str | None = Header(None)):
    uid = _require_uid(x_user_id)
    async with database.pool.acquire() as conn:
        rows = await conn.fetch(
            DESIGN_SELECT
            + " JOIN saved_designs sv ON sv.design_id = d.id"
            " WHERE sv.user_id = $1 ORDER BY sv.created_at DESC",
            uid,
        )
    return [_design_row(r) for r in rows]


# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------

@app.get("/api/users/{user_id}")
async def get_user(user_id: int):
    async with database.pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, name, username, created_at FROM users WHERE id = $1",
            user_id,
        )
        if not row:
            raise HTTPException(404, "User not found")
        cnt = await conn.fetchval(
            "SELECT COUNT(*) FROM designs WHERE user_id = $1", user_id,
        )
    return {
        "id": row["id"],
        "name": row["name"],
        "username": row["username"],
        "created_at": str(row["created_at"]),
        "design_count": cnt,
    }


@app.get("/api/users/{user_id}/designs")
async def get_user_designs(user_id: int, x_user_id: str | None = Header(None)):
    uid = _uid(x_user_id) or 0
    async with database.pool.acquire() as conn:
        rows = await conn.fetch(
            DESIGN_SELECT + " WHERE d.user_id = $2 ORDER BY d.created_at DESC",
            uid, user_id,
        )
    return [_design_row(r) for r in rows]


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------

@app.get("/api/search")
async def search(q: str = Query(""), x_user_id: str | None = Header(None)):
    q = q.strip()
    if not q:
        return []
    uid = _uid(x_user_id) or 0
    pattern = f"%{q}%"
    async with database.pool.acquire() as conn:
        rows = await conn.fetch(
            DESIGN_SELECT
            + " WHERE d.title ILIKE $2 OR d.description ILIKE $2"
            " OR d.tags ILIKE $2 OR u.name ILIKE $2"
            " ORDER BY d.created_at DESC LIMIT 50",
            uid, pattern,
        )
    return [_design_row(r) for r in rows]


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, reload=True, loop="asyncio")
