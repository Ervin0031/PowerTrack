"""Seed muscle_groups and equipment tables with comprehensive data.
Run from backend/ directory:
    uv run python scripts/seed_exercise_data.py
"""

import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlmodel import select
from app.models.exercise import MuscleGroup, Equipment
from app.core.config.settings import settings

MUSCLE_GROUPS = [
    # upper
    ("胸部", "Chest", "upper"),
    ("上胸部", "Upper Chest", "upper"),
    ("下胸部", "Lower Chest", "upper"),
    ("背部", "Back", "upper"),
    ("背阔肌", "Lats", "upper"),
    ("上背部", "Upper Back", "upper"),
    ("下背部", "Lower Back", "upper"),
    ("肩部", "Shoulders", "upper"),
    ("三角肌前束", "Front Delts", "upper"),
    ("三角肌中束", "Side Delts", "upper"),
    ("三角肌后束", "Rear Delts", "upper"),
    ("斜方肌", "Traps", "upper"),
    ("肱二头肌", "Biceps", "upper"),
    ("肱三头肌", "Triceps", "upper"),
    ("前臂", "Forearms", "upper"),
    ("腹肌", "Abs", "upper"),
    # lower
    ("股四头肌", "Quadriceps", "lower"),
    ("腘绳肌", "Hamstrings", "lower"),
    ("臀部", "Glutes", "lower"),
    ("小腿", "Calves", "lower"),
    ("髋屈肌", "Hip Flexors", "lower"),
    ("内收肌", "Adductors", "lower"),
    ("外展肌", "Abductors", "lower"),
    ("胫骨前肌", "Tibialis Anterior", "lower"),
    # core
    ("腹直肌", "Rectus Abdominis", "core"),
    ("腹斜肌", "Obliques", "core"),
    ("腹横肌", "Transverse Abdominis", "core"),
    ("竖脊肌", "Erector Spinae", "core"),
    ("核心整体", "Core", "core"),
]

EQUIPMENT = [
    ("杠铃", "Barbell"),
    ("哑铃", "Dumbbell"),
    ("壶铃", "Kettlebell"),
    ("史密斯机", "Smith Machine"),
    ("深蹲架", "Squat Rack"),
    ("卧推凳", "Bench"),
    ("上斜板", "Incline Bench"),
    ("龙门架", "Cable Machine"),
    ("高位下拉机", "Lat Pulldown Machine"),
    ("坐姿划船机", "Seated Row Machine"),
    ("腿举机", "Leg Press Machine"),
    ("腿屈伸机", "Leg Extension Machine"),
    ("腿弯举机", "Leg Curl Machine"),
    ("哈克深蹲机", "Hack Squat Machine"),
    ("牧师凳", "Preacher Curl Bench"),
    ("双杠", "Dip Bars"),
    ("引体向上杆", "Pull-up Bar"),
    ("弹力带", "Resistance Band"),
    ("TRX悬挂带", "TRX"),
    ("罗马椅", "Roman Chair"),
    ("臀推机", "Hip Thrust Machine"),
    ("瑜伽垫", "Yoga Mat"),
    ("自重", "Bodyweight"),
]


async def main():
    engine = create_async_engine(settings.database.DATABASE_URL, echo=False)
    session_factory = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    async with session_factory() as db:
        # ---- Muscle Groups ----
        added_mg = 0
        for name, name_en, category in MUSCLE_GROUPS:
            result = await db.execute(
                select(MuscleGroup).where(MuscleGroup.name == name)
            )
            if result.scalar_one_or_none():
                continue
            db.add(MuscleGroup(name=name, name_en=name_en, category=category))
            added_mg += 1

        # ---- Equipment ----
        added_eq = 0
        for name, name_en in EQUIPMENT:
            result = await db.execute(select(Equipment).where(Equipment.name == name))
            if result.scalar_one_or_none():
                continue
            db.add(Equipment(name=name, name_en=name_en))
            added_eq += 1

        await db.commit()

        # ---- Summary ----
        mg_count = (await db.execute(select(MuscleGroup))).scalars().all()
        eq_count = (await db.execute(select(Equipment))).scalars().all()

        print(f"Muscle Groups: 新增 {added_mg}，共 {len(mg_count)} 条")
        print(f"Equipment:     新增 {added_eq}，共 {len(eq_count)} 条")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
