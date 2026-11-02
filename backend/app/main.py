"""FastAPI application main entry point"""

import os
import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.openapi.utils import get_openapi
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config.settings import settings
from app.core.logger import logger_manager
from app.core.database import db_manager
from app.core.redis import redis_manager
from app.core.utc_z_json import UtcZJsonMiddleware

from app.routers.v1 import (
    auth_router,
    coach_router,
    equipment_router,
    exercise_router,
    feed_router,
    muscle_group_router,
    performance_router,
    program_router,
    session_router,
    share_router,
    template_router,
    user_router,
)

# Create LoggerManager instance
logger_manager.setup()

# Create Logger instance
logger = logger_manager.get_logger(__name__)


# Create lifespan
async def lifespan(_app: FastAPI):
    """Application lifespan management"""
    logger.info("🚩 Starting the application...")
    logger.info(f"🚧 You are working in {os.getenv('ENV', 'development')} environment")

    try:
        # Initialize database connection
        await db_manager.initialize()
        logger.info("🎉 Database connections initialized successfully")
        await db_manager.test_connections()
        logger.info("🎉 Database connections test successfully")
    except Exception as e:
        logger.error(f"❌ Database connection failed: {e}")
        logger.warning("⚠️ Application will start without database connections")

    try:
        # Initialize Redis connection
        await redis_manager.initialize_async()
        logger.info("🎉 Redis connections initialized successfully")
        await redis_manager.async_test_connection()
        logger.info("🎉 Redis connections test successfully")
    except Exception as e:
        logger.error(f"❌ Redis connection failed: {e}")
        logger.warning("⚠️ Application will start without Redis connections")

    yield

    # Close database connection
    try:
        await db_manager.close()
        logger.info("🎉 Database connections closed successfully")
    except Exception as e:
        logger.error(f"❌ Database connection closed failed: {e}")
        logger.warning("⚠️ Database connection closed failed")

    # Close Redis connections
    try:
        await redis_manager.close()
        logger.info("🎉 Redis connections closed successfully")
    except Exception as e:
        logger.error(f"❌ Redis connection closed failed: {e}")
        logger.warning("⚠️ Redis connection closed failed")


# Create FastAPI instance
app = FastAPI(
    lifespan=lifespan,
    title="PowerTrack 力量训练 API",
    version=settings.app.APP_VERSION,
    description=(
        "## PowerTrack 后端接口文档\n\n"
        "力量训练记录 App 的 REST API，涵盖注册登录、动作库、训练记录、模板、数据统计全链路。\n\n"
        "### 通用约定\n\n"
        "- 基地址：`/api/v1`（健康检查为 `GET /health`）\n"
        "- 认证方式：除注册/登录/邮箱验证/密码重置外，其余接口均需请求头 "
        "`Authorization: Bearer <access_token>`\n"
        "- 时间格式：ISO 8601，UTC 并以 `Z` 结尾，如 `2026-01-01T08:00:00Z`\n"
        "- 请求体同时兼容 `camelCase` 与 `snake_case`（训练、模板、档案三个模块）；"
        "响应一律为 `snake_case`\n"
        '- 分页列表统一返回 `{"items": [...], "total": 数量}`\n'
        '- 错误统一返回 `{"status": 状态码, "error": "错误信息"}`\n'
    ),
    openapi_tags=[
        {
            "name": "Authentication",
            "description": "注册、登录、令牌刷新、登出、邮箱验证、密码重置/修改、登录设备管理。",
        },
        {
            "name": "Users",
            "description": "当前用户信息维护、健身档案（引导页一次性提交）、管理员用户管理。",
        },
        {
            "name": "Exercises",
            "description": "动作库：分页查询/详情公开可查，创建/更新/删除仅管理员。",
        },
        {
            "name": "Equipment",
            "description": "器械字典：列表公开可查，增删改仅管理员。被动作引用时删除返回 409。",
        },
        {
            "name": "Muscle Groups",
            "description": "肌群字典：列表公开可查，增删改仅管理员。category 仅取 upper/lower/core。",
        },
        {
            "name": "Training Sessions",
            "description": "训练会话：开始时轻量创建（幂等），结束时批量上传全部组；历史列表/详情/删除。",
        },
        {
            "name": "Training Performance",
            "description": "训练表现与数据分析：上次表现、动作图表、1RM、周容量、总览、肌群恢复、RPE 建议。",
        },
        {
            "name": "Feed",
            "description": "社交动态：分享已完成训练为卡片（PR/肌群高亮快照），关注流、评论（可针对某一组）、点赞。",
        },
        {
            "name": "Workout Templates",
            "description": "训练模板：可见范围=自己的私密+全部公开；创建/更新用表单传 JSON+封面图。",
        },
        {
            "name": "Coach",
            "description": "今日课表教练：对话只产出提案，确认后由客户端走现有会话接口开练。",
        },
        {"name": "Health", "description": "服务健康检查，无需认证。"},
    ],
)


# Global exception handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(_request: Request, exc: HTTPException):
    """HTTP exception handler"""
    logger.error(f"HTTPException: {exc}")
    error_detail = exc.detail

    if isinstance(error_detail, dict):
        error_message = error_detail.get("error", str(error_detail))
    else:
        error_message = str(error_detail)

    return JSONResponse(
        status_code=exc.status_code,
        content={"status": exc.status_code, "error": error_message},
    )


@app.exception_handler(Exception)
async def general_exception_handler(_request: Request, exc: Exception):
    """General exception handler"""
    logger.exception("Unhandled exception")
    return JSONResponse(
        status_code=500,
        content={"status": 500, "error": "Internal server error"},
    )


# CORS middleware
allow_origins = [
    x.strip() for x in settings.cors.CORS_ALLOWED_ORIGINS.split(",") if x.strip()
]
allow_methods = [
    x.strip() for x in settings.cors.CORS_ALLOW_METHODS.split(",") if x.strip()
]
allow_headers = [
    x.strip() for x in settings.cors.CORS_ALLOW_HEADERS.split(",") if x.strip()
]
allow_credentials = settings.cors.CORS_ALLOW_CREDENTIALS
expose_headers = [
    x.strip() for x in settings.cors.CORS_EXPOSE_HEADERS.split(",") if x.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_methods=allow_methods,
    allow_headers=allow_headers,
    allow_credentials=allow_credentials,
    expose_headers=expose_headers,
)
# 在 CORS 之后添加：naive UTC datetime JSON 补 Z，避免客户端当成本地时间。
app.add_middleware(UtcZJsonMiddleware)


# Static files
static_dir = os.path.join(os.path.dirname(__file__), "..", "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")


# Include routers
app.include_router(auth_router, prefix="/api/v1")
app.include_router(equipment_router, prefix="/api/v1")
app.include_router(muscle_group_router, prefix="/api/v1")
app.include_router(performance_router, prefix="/api/v1")
app.include_router(exercise_router, prefix="/api/v1")
app.include_router(feed_router, prefix="/api/v1")
app.include_router(session_router, prefix="/api/v1")
app.include_router(share_router, prefix="/api/v1")
app.include_router(program_router, prefix="/api/v1")
app.include_router(template_router, prefix="/api/v1")
app.include_router(user_router, prefix="/api/v1")
app.include_router(coach_router, prefix="/api/v1")


# Health check endpoint
@app.get(
    "/health",
    tags=["Health"],
    summary="健康检查",
    description='检查服务是否存活，无需认证。\n\n返回格式：`{"status": "healthy"}`。',
    response_description="服务正常，返回 status=healthy。",
)
async def health_check():
    """健康检查接口"""
    return {"status": "healthy"}


# OpenAPI documentation
def custom_openapi():
    """Custom OpenAPI documentation"""
    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title="PowerTrack 力量训练 API",
        version=settings.app.APP_VERSION,
        description=app.description,
        routes=app.routes,
        tags=app.openapi_tags,
    )

    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi


# Start application
if __name__ == "__main__":
    if os.getenv("ENV") == "development":
        logger.info("🚩 Starting the application in development mode...")
        uvicorn.run(
            app="app.main:app",
            host="127.0.0.1",
            port=8000,
            reload=True,
        )
