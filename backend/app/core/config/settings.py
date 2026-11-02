"""globalconfigurationmanagement"""

from functools import cached_property

from app.core.config.modules.app import AppSettings
from app.core.config.modules.celery import CelerySettings
from app.core.config.modules.cors import CORSSettings
from app.core.config.modules.database import DatabaseSettings
from app.core.config.modules.email import EmailSettings
from app.core.config.modules.jwt import JWTSettings
from app.core.config.modules.llm import LLMSettings
from app.core.config.modules.logger import LoggingSettings
from app.core.config.modules.redis import RedisSettings
from app.core.config.modules.storage import StorageSettings


class Settings:
    """Global configuration class

    Use cached_property for lazy loading configuration, improves performance
    """

    @cached_property
    def app(self) -> AppSettings:
        return AppSettings()

    @cached_property
    def logging(self) -> LoggingSettings:
        return LoggingSettings()

    @cached_property
    def database(self) -> DatabaseSettings:
        return DatabaseSettings()

    @cached_property
    def jwt(self) -> JWTSettings:
        return JWTSettings()

    @cached_property
    def email(self) -> EmailSettings:
        return EmailSettings()

    @cached_property
    def cors(self) -> CORSSettings:
        return CORSSettings()

    @cached_property
    def redis(self) -> RedisSettings:
        return RedisSettings()

    @cached_property
    def celery(self) -> CelerySettings:
        return CelerySettings()

    @cached_property
    def storage(self) -> StorageSettings:
        return StorageSettings()

    @cached_property
    def llm(self) -> LLMSettings:
        return LLMSettings()


# Create a global settings instance
settings = Settings()
