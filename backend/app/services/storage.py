"""S3-compatible storage service for RustFS — upload, delete, read, presigned URLs"""

import asyncio
import io
import uuid
from functools import lru_cache

import boto3
from botocore.config import Config as BotoConfig
from botocore.exceptions import ClientError
from fastapi import HTTPException, UploadFile, status
from PIL import Image, ImageOps

from app.core.config import settings


class StorageService:
    """Lazy-singleton storage service backed by S3-compatible RustFS.

    ponytail: sync boto3 client — 10MB uploads on localhost/LAN are fast enough.
    Image reads go through [fetch], which offloads to a thread so request
    handlers stay non-blocking.
    """

    @staticmethod
    @lru_cache(maxsize=1)
    def _client():
        """Shared boto3 S3 client. boto3 clients are thread-safe and pool
        connections internally; image reads made a fresh client per call
        (TLS handshake each time) too expensive."""
        cfg = settings.storage
        return boto3.client(
            "s3",
            endpoint_url=cfg.STORAGE_ENDPOINT,
            aws_access_key_id=cfg.STORAGE_ACCESS_KEY,
            aws_secret_access_key=cfg.STORAGE_SECRET_KEY,
            region_name=cfg.STORAGE_REGION,
            config=BotoConfig(signature_version="s3v4"),
        )

    @staticmethod
    def _ensure_bucket(client, bucket_name: str) -> None:
        """Create bucket if it doesn't already exist (idempotent)."""
        try:
            client.head_bucket(Bucket=bucket_name)
        except Exception:
            client.create_bucket(Bucket=bucket_name)

    @staticmethod
    def _validate(file: UploadFile) -> bytes:
        """Validate file type and size, return file bytes."""
        cfg = settings.storage
        allowed = [t.strip() for t in cfg.STORAGE_ALLOWED_IMAGE_TYPES.split(",")]
        if file.content_type not in allowed:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"不支持的文件类型 '{file.content_type}'，允许: {allowed}",
            )

        # ponytail: single read for both validation and upload
        contents = file.file.read()
        if len(contents) > cfg.STORAGE_MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"文件过大，最大允许 {cfg.STORAGE_MAX_FILE_SIZE} bytes",
            )
        return contents

    @staticmethod
    def _ext_of(file: UploadFile) -> str:
        """Extension from the original filename, falling back to png."""
        if file.filename and "." in file.filename:
            return file.filename.rsplit(".", 1)[-1].lower() or "png"
        return "png"

    @staticmethod
    def upload(file: UploadFile, prefix: str | None = None) -> str:
        """Upload an image to RustFS. Returns the object key."""
        contents = StorageService._validate(file)
        return StorageService.upload_bytes(
            contents, StorageService._ext_of(file), file.content_type, prefix
        )

    @staticmethod
    def upload_bytes(
        contents: bytes, ext: str, content_type: str, prefix: str | None = None
    ) -> str:
        """Upload raw bytes to RustFS. Returns the object key."""
        cfg = settings.storage
        key_prefix = prefix or cfg.STORAGE_EXERCISE_IMAGES_PREFIX
        key = f"{key_prefix}/{uuid.uuid4()}.{ext}"

        client = StorageService._client()
        StorageService._ensure_bucket(client, cfg.STORAGE_BUCKET_NAME)
        client.put_object(
            Bucket=cfg.STORAGE_BUCKET_NAME,
            Key=key,
            Body=contents,
            ContentType=content_type,
        )
        return key

    @staticmethod
    def upload_with_thumbnail(
        file: UploadFile, prefix: str | None = None
    ) -> tuple[str, str | None]:
        """Upload an image plus its generated list thumbnail.

        Returns (image_key, thumb_key); thumb_key is None when thumbnail
        generation fails — the original upload still succeeds.
        """
        contents = StorageService._validate(file)
        key = StorageService.upload_bytes(
            contents, StorageService._ext_of(file), file.content_type, prefix
        )
        try:
            thumb_key: str | None = StorageService.create_thumbnail(contents, prefix)
        except Exception:  # noqa: BLE001 — 缩略图失败只降级,不影响原图上传
            thumb_key = None
        return key, thumb_key

    @staticmethod
    def create_thumbnail(contents: bytes, prefix: str | None = None) -> str:
        """Generate + upload a downscaled JPEG thumbnail. Returns the object key."""
        thumb = StorageService.generate_thumbnail(contents)
        return StorageService.upload_bytes(thumb, "jpg", "image/jpeg", prefix)

    @staticmethod
    def generate_thumbnail(contents: bytes, max_side: int = 512) -> bytes:
        """Downscale image bytes to a list-sized JPEG (never upscales)."""
        image = Image.open(io.BytesIO(contents))
        image = ImageOps.exif_transpose(image)  # honor phone-photo rotation
        image = image.convert("RGB")  # JPEG has no alpha channel
        image.thumbnail((max_side, max_side))
        buf = io.BytesIO()
        image.save(buf, format="JPEG", quality=80)
        return buf.getvalue()

    @staticmethod
    def delete(key: str | None) -> None:
        """Delete an object from storage. No-op if key is empty."""
        if not key:
            return
        cfg = settings.storage
        client = StorageService._client()
        client.delete_object(Bucket=cfg.STORAGE_BUCKET_NAME, Key=key)

    @staticmethod
    def presigned_url(key: str | None) -> str | None:
        """Generate a presigned GET URL. Returns None if key is empty."""
        if not key:
            return None
        cfg = settings.storage
        client = StorageService._client()
        return client.generate_presigned_url(
            "get_object",
            Params={"Bucket": cfg.STORAGE_BUCKET_NAME, "Key": key},
            ExpiresIn=cfg.STORAGE_PRESIGNED_URL_EXPIRY,
        )

    @staticmethod
    async def fetch(key: str | None) -> tuple[bytes, str] | None:
        """Read object bytes and content type. None if key is empty/unreadable."""
        if not key:
            return None
        cfg = settings.storage

        def _get() -> tuple[bytes, str]:
            obj = StorageService._client().get_object(
                Bucket=cfg.STORAGE_BUCKET_NAME, Key=key
            )
            # ponytail: whole-object read — 2.6MB max, chunked streaming not worth it.
            # Body.read() is blocking too, so it must stay inside the thread.
            body = obj["Body"].read()
            content_type = obj.get("ContentType") or "application/octet-stream"
            return body, content_type

        try:
            return await asyncio.to_thread(_get)
        except ClientError:
            return None


storage_service = StorageService()
