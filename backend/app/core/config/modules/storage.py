"""Storage configuration — S3-compatible (RustFS)"""

from pydantic import Field
from app.core.config.base import EnvBaseSettings


class StorageSettings(EnvBaseSettings):
    """S3-compatible storage configuration for RustFS"""

    STORAGE_ENDPOINT: str = Field(
        default="http://localhost:9000",
        description="S3-compatible storage endpoint URL",
    )

    STORAGE_ACCESS_KEY: str = Field(
        default="minioadmin",
        description="Storage access key",
    )

    STORAGE_SECRET_KEY: str = Field(
        default="minioadmin",
        description="Storage secret key",
    )

    STORAGE_REGION: str = Field(
        default="us-east-1",
        description="Storage region identifier",
    )

    STORAGE_BUCKET_NAME: str = Field(
        default="powertrack",
        description="Default bucket name",
    )

    STORAGE_EXERCISE_IMAGES_PREFIX: str = Field(
        default="exercises/images",
        description="Object key prefix for exercise images",
    )

    STORAGE_TEMPLATE_IMAGES_PREFIX: str = Field(
        default="templates/covers",
        description="Object key prefix for template cover images",
    )

    STORAGE_MAX_FILE_SIZE: int = Field(
        default=10_485_760,  # 10 MB
        description="Maximum allowed file size in bytes for uploads",
    )

    STORAGE_ALLOWED_IMAGE_TYPES: str = Field(
        default="image/jpeg,image/png,image/gif,image/webp",
        description="Comma-separated list of allowed image MIME types",
    )

    STORAGE_PRESIGNED_URL_EXPIRY: int = Field(
        default=3600,  # 1 hour
        description="Presigned URL expiry time in seconds",
    )
