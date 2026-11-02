"""User CRUD operations (async)"""

from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_password_hash, verify_password
from app.models.feed import FeedComment, FeedLike, FeedPost, Follow
from app.models.one_rm import UserExercise1RM
from app.models.profile import UserFitnessProfile, WeightLog
from app.models.recovery import UserRecoveryFactor
from app.models.template import (
    WorkoutTemplate,
    WorkoutTemplateExercise,
    WorkoutTemplateSet,
)
from app.models.user import User
from app.models.workout import WorkoutSession, WorkoutSet
from app.schemas.user import UserCreate, UserUpdate


class UserCRUD:
    """User CRUD operations class - Complete JWT Auth (async)"""

    @staticmethod
    async def get_by_id(db: AsyncSession, user_id: int) -> Optional[User]:
        """Get user by ID"""
        result = await db.get(User, user_id)
        return result

    @staticmethod
    async def get_by_username(db: AsyncSession, username: str) -> Optional[User]:
        """Get user by username"""
        statement = select(User).where(User.username == username)
        result = await db.execute(statement)
        return result.scalar_one_or_none()

    @staticmethod
    async def get_by_email(db: AsyncSession, email: str) -> Optional[User]:
        """Get user by email"""
        statement = select(User).where(User.email == email)
        result = await db.execute(statement)
        return result.scalar_one_or_none()

    @staticmethod
    async def get_all(db: AsyncSession, skip: int = 0, limit: int = 100) -> List[User]:
        """Getalluser"""
        statement = select(User).offset(skip).limit(limit)
        result = await db.execute(statement)
        return list(result.scalars().all())

    @staticmethod
    async def create(db: AsyncSession, user_create: UserCreate) -> User:
        """Createnewuser"""
        hashed_password = get_password_hash(user_create.password)

        db_user = User(
            username=user_create.username,
            email=user_create.email,
            hashed_password=hashed_password,
            is_verified=False,  # needEmailValidate
        )

        db.add(db_user)
        await db.commit()
        await db.refresh(db_user)
        return db_user

    @staticmethod
    async def update(
        db: AsyncSession, user_id: int, user_update: UserUpdate
    ) -> Optional[User]:
        """updateuserinformation"""
        db_user = await UserCRUD.get_by_id(db, user_id)
        if not db_user:
            return None

        update_data = user_update.model_dump(exclude_unset=True)

        # ifupdatePassword，needhash
        if "password" in update_data:
            update_data["hashed_password"] = get_password_hash(
                update_data.pop("password")
            )

        for field, value in update_data.items():
            setattr(db_user, field, value)

        db_user.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.add(db_user)
        await db.commit()
        await db.refresh(db_user)
        return db_user

    @staticmethod
    async def delete(db: AsyncSession, user_id: int) -> bool:
        """Deleteuser + all dependent rows.

        外键没有 ON DELETE CASCADE，裸删会让有训练/档案/社交数据的用户
        触发 FK 违例（500）。
        这里按 子表 → 父表 顺序手动级联，`DELETE /users/me` 与管理员删除共用此路径。
        """
        db_user = await UserCRUD.get_by_id(db, user_id)
        if not db_user:
            return False

        session_ids = select(WorkoutSession.id).where(WorkoutSession.user_id == user_id)
        template_ids = select(WorkoutTemplate.id).where(
            WorkoutTemplate.user_id == user_id
        )
        template_exercise_ids = select(WorkoutTemplateExercise.id).where(
            WorkoutTemplateExercise.template_id.in_(template_ids)
        )
        post_ids = select(FeedPost.id).where(FeedPost.user_id == user_id)

        # 社交：自己发过的动态（含他人在其下的评论/点赞）、自己的评论/点赞、
        # 两个方向的关注
        await db.execute(
            delete(FeedComment).where(
                or_(FeedComment.user_id == user_id, FeedComment.post_id.in_(post_ids))
            )
        )
        await db.execute(
            delete(FeedLike).where(
                or_(FeedLike.user_id == user_id, FeedLike.post_id.in_(post_ids))
            )
        )
        await db.execute(delete(FeedPost).where(FeedPost.user_id == user_id))
        await db.execute(
            delete(Follow).where(
                or_(Follow.follower_id == user_id, Follow.followee_id == user_id)
            )
        )
        # 训练：模板（组 → 动作 → 模板）、会话（组 → 会话）
        await db.execute(
            delete(WorkoutTemplateSet).where(
                WorkoutTemplateSet.template_exercise_id.in_(template_exercise_ids)
            )
        )
        await db.execute(
            delete(WorkoutTemplateExercise).where(
                WorkoutTemplateExercise.template_id.in_(template_ids)
            )
        )
        await db.execute(
            delete(WorkoutTemplate).where(WorkoutTemplate.user_id == user_id)
        )
        await db.execute(
            delete(WorkoutSet).where(WorkoutSet.session_id.in_(session_ids))
        )
        await db.execute(
            delete(WorkoutSession).where(WorkoutSession.user_id == user_id)
        )
        # 档案与个性化数据
        await db.execute(
            delete(UserExercise1RM).where(UserExercise1RM.user_id == user_id)
        )
        await db.execute(
            delete(UserRecoveryFactor).where(UserRecoveryFactor.user_id == user_id)
        )
        await db.execute(delete(WeightLog).where(WeightLog.user_id == user_id))
        await db.execute(
            delete(UserFitnessProfile).where(UserFitnessProfile.user_id == user_id)
        )

        await db.delete(db_user)
        await db.commit()
        return True

    @staticmethod
    async def authenticate(
        db: AsyncSession, username: str, password: str
    ) -> Optional[User]:
        """Authenticate user credentials"""
        # Try username login
        user = await UserCRUD.get_by_username(db, username)

        # If username doesn't exist, try email login
        if not user:
            user = await UserCRUD.get_by_email(db, username)

        if not user:
            return None

        if not verify_password(password, user.hashed_password):
            return None

        # Update last login time
        user.last_login_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.add(user)
        await db.commit()

        return user

    @staticmethod
    async def verify_email(db: AsyncSession, user_id: int) -> Optional[User]:
        """ValidateuserEmail"""
        db_user = await UserCRUD.get_by_id(db, user_id)
        if not db_user:
            return None

        db_user.is_verified = True
        db.add(db_user)
        await db.commit()
        await db.refresh(db_user)
        return db_user

    @staticmethod
    async def change_password(
        db: AsyncSession, user_id: int, new_password: str
    ) -> Optional[User]:
        """modifyuserPassword"""
        db_user = await UserCRUD.get_by_id(db, user_id)
        if not db_user:
            return None

        db_user.hashed_password = get_password_hash(new_password)
        db_user.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.add(db_user)
        await db.commit()
        await db.refresh(db_user)
        return db_user


# Createglobalinstance
user_crud = UserCRUD()
