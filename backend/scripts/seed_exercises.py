"""
种子脚本：批量导入训练动作数据。

用法：
    cd backend
    uv run python scripts/seed_exercises.py

    或指定数据库 URL：
    DATABASE_URL=postgresql://... uv run python scripts/seed_exercises.py
"""

import asyncio
import json
import os
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.models.exercise import Exercise, ExerciseSecondaryMuscle
from app.models.user import (
    User,
)  # noqa: F401 — 确保 users 表对 SQLAlchemy 可见以解析 FK

# ---------------------------------------------------------------------------
# 数据
# ---------------------------------------------------------------------------

EXERCISES_JSON = """\
[
    {
        "name": "杠铃深蹲",
        "name_en": "Barbell Squat",
        "equipment_id": 1,
        "muscle_ids": [17, 19, 28]
    },
    {
        "name": "杠铃卧推",
        "name_en": "Barbell Bench Press",
        "equipment_id": 1,
        "muscle_ids": [1, 14, 9]
    },
    {
        "name": "杠铃硬拉",
        "name_en": "Barbell Deadlift",
        "equipment_id": 1,
        "muscle_ids": [19, 18, 7, 17]
    },
    {
        "name": "杠铃过头推举",
        "name_en": "Barbell Overhead Press",
        "equipment_id": 1,
        "muscle_ids": [8, 14, 12]
    },
    {
        "name": "杠铃划船",
        "name_en": "Barbell Row",
        "equipment_id": 1,
        "muscle_ids": [4, 13, 11]
    },
    {
        "name": "杠铃弯举",
        "name_en": "Barbell Curl",
        "equipment_id": 1,
        "muscle_ids": [13]
    },
    {
        "name": "杠铃耸肩",
        "name_en": "Barbell Shrug",
        "equipment_id": 1,
        "muscle_ids": [12]
    },
    {
        "name": "窄距杠铃卧推",
        "name_en": "Close-Grip Barbell Bench Press",
        "equipment_id": 1,
        "muscle_ids": [1, 14]
    },
    {
        "name": "上斜杠铃卧推",
        "name_en": "Incline Barbell Bench Press",
        "equipment_id": 1,
        "muscle_ids": [2, 9]
    },
    {
        "name": "杠铃臀桥",
        "name_en": "Barbell Hip Thrust",
        "equipment_id": 1,
        "muscle_ids": [19]
    },
    {
        "name": "杠铃箭步蹲",
        "name_en": "Barbell Lunge",
        "equipment_id": 1,
        "muscle_ids": [17, 19]
    },
    {
        "name": "杠铃早安式",
        "name_en": "Barbell Good Morning",
        "equipment_id": 1,
        "muscle_ids": [18, 7, 28]
    },
    {
        "name": "地板卧推",
        "name_en": "Floor Press",
        "equipment_id": 1,
        "muscle_ids": [1, 14]
    },
    {
        "name": "杠铃拖拽弯举",
        "name_en": "Barbell Drag Curl",
        "equipment_id": 1,
        "muscle_ids": [13]
    },
    {
        "name": "泽奇深蹲",
        "name_en": "Zercher Squat",
        "equipment_id": 1,
        "muscle_ids": [17, 19, 28]
    },
    {
        "name": "哑铃卧推",
        "name_en": "Dumbbell Bench Press",
        "equipment_id": 2,
        "muscle_ids": [1, 14, 9]
    },
    {
        "name": "上斜哑铃卧推",
        "name_en": "Incline Dumbbell Bench Press",
        "equipment_id": 2,
        "muscle_ids": [2, 9, 14]
    },
    {
        "name": "下斜哑铃卧推",
        "name_en": "Decline Dumbbell Bench Press",
        "equipment_id": 2,
        "muscle_ids": [3, 14]
    },
    {
        "name": "哑铃飞鸟",
        "name_en": "Dumbbell Flye",
        "equipment_id": 2,
        "muscle_ids": [1]
    },
    {
        "name": "上斜哑铃飞鸟",
        "name_en": "Incline Dumbbell Flye",
        "equipment_id": 2,
        "muscle_ids": [2]
    },
    {
        "name": "哑铃推举",
        "name_en": "Dumbbell Shoulder Press",
        "equipment_id": 2,
        "muscle_ids": [8, 14]
    },
    {
        "name": "哑铃侧平举",
        "name_en": "Dumbbell Lateral Raise",
        "equipment_id": 2,
        "muscle_ids": [10]
    },
    {
        "name": "哑铃前平举",
        "name_en": "Dumbbell Front Raise",
        "equipment_id": 2,
        "muscle_ids": [9]
    },
    {
        "name": "俯身哑铃侧平举",
        "name_en": "Bent-Over Dumbbell Lateral Raise",
        "equipment_id": 2,
        "muscle_ids": [11]
    },
    {
        "name": "哑铃划船",
        "name_en": "Dumbbell Row",
        "equipment_id": 2,
        "muscle_ids": [4, 5, 13, 11]
    },
    {
        "name": "单臂哑铃划船",
        "name_en": "Single-Arm Dumbbell Row",
        "equipment_id": 2,
        "muscle_ids": [4, 5, 13]
    },
    {
        "name": "哑铃弯举",
        "name_en": "Dumbbell Curl",
        "equipment_id": 2,
        "muscle_ids": [13]
    },
    {
        "name": "锤式弯举",
        "name_en": "Hammer Curl",
        "equipment_id": 2,
        "muscle_ids": [13, 15]
    },
    {
        "name": "哑铃臂屈伸",
        "name_en": "Dumbbell Tricep Extension",
        "equipment_id": 2,
        "muscle_ids": [14]
    },
    {
        "name": "俯身哑铃臂屈伸",
        "name_en": "Bent-Over Dumbbell Tricep Extension",
        "equipment_id": 2,
        "muscle_ids": [14]
    },
    {
        "name": "哑铃深蹲",
        "name_en": "Dumbbell Squat",
        "equipment_id": 2,
        "muscle_ids": [17, 19]
    },
    {
        "name": "哑铃箭步蹲",
        "name_en": "Dumbbell Lunge",
        "equipment_id": 2,
        "muscle_ids": [17, 19]
    },
    {
        "name": "哑铃罗马尼亚硬拉",
        "name_en": "Dumbbell Romanian Deadlift",
        "equipment_id": 2,
        "muscle_ids": [18, 19]
    },
    {
        "name": "哑铃耸肩",
        "name_en": "Dumbbell Shrug",
        "equipment_id": 2,
        "muscle_ids": [12]
    },
    {
        "name": "阿诺德推举",
        "name_en": "Arnold Press",
        "equipment_id": 2,
        "muscle_ids": [8, 9]
    },
    {
        "name": "哑铃仰卧臂屈伸",
        "name_en": "Lying Dumbbell Tricep Extension",
        "equipment_id": 2,
        "muscle_ids": [14]
    },
    {
        "name": "单臂哑铃抓举",
        "name_en": "Single-Arm Dumbbell Snatch",
        "equipment_id": 2,
        "muscle_ids": [8, 19, 17]
    },
    {
        "name": "哑铃摇摆",
        "name_en": "Dumbbell Swing",
        "equipment_id": 2,
        "muscle_ids": [19, 18, 7]
    },
    {
        "name": "壶铃摇摆",
        "name_en": "Kettlebell Swing",
        "equipment_id": 3,
        "muscle_ids": [19, 18, 7]
    },
    {
        "name": "壶铃高脚杯深蹲",
        "name_en": "Kettlebell Goblet Squat",
        "equipment_id": 3,
        "muscle_ids": [17, 19]
    },
    {
        "name": "壶铃推举",
        "name_en": "Kettlebell Press",
        "equipment_id": 3,
        "muscle_ids": [8, 14]
    },
    {
        "name": "壶铃划船",
        "name_en": "Kettlebell Row",
        "equipment_id": 3,
        "muscle_ids": [4, 5, 13]
    },
    {
        "name": "壶铃相扑硬拉",
        "name_en": "Kettlebell Sumo Deadlift",
        "equipment_id": 3,
        "muscle_ids": [19, 22, 17]
    },
    {
        "name": "壶铃土耳其起立",
        "name_en": "Turkish Get-Up",
        "equipment_id": 3,
        "muscle_ids": [8, 19, 29]
    },
    {
        "name": "壶铃风车",
        "name_en": "Kettlebell Windmill",
        "equipment_id": 3,
        "muscle_ids": [19, 26, 10]
    },
    {
        "name": "壶铃抓举",
        "name_en": "Kettlebell Snatch",
        "equipment_id": 3,
        "muscle_ids": [8, 19, 17]
    },
    {
        "name": "壶铃挺举",
        "name_en": "Kettlebell Clean and Press",
        "equipment_id": 3,
        "muscle_ids": [8, 19, 17]
    },
    {
        "name": "壶铃弯举",
        "name_en": "Kettlebell Curl",
        "equipment_id": 3,
        "muscle_ids": [13]
    },
    {
        "name": "壶铃臀桥",
        "name_en": "Kettlebell Hip Thrust",
        "equipment_id": 3,
        "muscle_ids": [19]
    },
    {
        "name": "壶铃前架深蹲",
        "name_en": "Kettlebell Front Rack Squat",
        "equipment_id": 3,
        "muscle_ids": [17, 19]
    },
    {
        "name": "史密斯机深蹲",
        "name_en": "Smith Machine Squat",
        "equipment_id": 4,
        "muscle_ids": [17, 19]
    },
    {
        "name": "史密斯机卧推",
        "name_en": "Smith Machine Bench Press",
        "equipment_id": 4,
        "muscle_ids": [1, 14]
    },
    {
        "name": "史密斯机上斜卧推",
        "name_en": "Smith Machine Incline Bench Press",
        "equipment_id": 4,
        "muscle_ids": [2, 9, 14]
    },
    {
        "name": "史密斯机推举",
        "name_en": "Smith Machine Shoulder Press",
        "equipment_id": 4,
        "muscle_ids": [8, 14]
    },
    {
        "name": "史密斯机划船",
        "name_en": "Smith Machine Row",
        "equipment_id": 4,
        "muscle_ids": [4, 13]
    },
    {
        "name": "史密斯机耸肩",
        "name_en": "Smith Machine Shrug",
        "equipment_id": 4,
        "muscle_ids": [12]
    },
    {
        "name": "史密斯机早安式",
        "name_en": "Smith Machine Good Morning",
        "equipment_id": 4,
        "muscle_ids": [18, 7, 28]
    },
    {
        "name": "史密斯机箭步蹲",
        "name_en": "Smith Machine Lunge",
        "equipment_id": 4,
        "muscle_ids": [17, 19]
    },
    {
        "name": "史密斯机臀推",
        "name_en": "Smith Machine Hip Thrust",
        "equipment_id": 4,
        "muscle_ids": [19]
    },
    {
        "name": "史密斯机提踵",
        "name_en": "Smith Machine Calf Raise",
        "equipment_id": 4,
        "muscle_ids": [20]
    },
    {
        "name": "深蹲架深蹲",
        "name_en": "Squat Rack Squat",
        "equipment_id": 5,
        "muscle_ids": [17, 19, 28]
    },
    {
        "name": "深蹲架上斜推举",
        "name_en": "Squat Rack Incline Press",
        "equipment_id": 5,
        "muscle_ids": [2, 14]
    },
    {
        "name": "卧推凳标准卧推",
        "name_en": "Bench Press",
        "equipment_id": 6,
        "muscle_ids": [1, 14, 9]
    },
    {
        "name": "卧推凳窄距卧推",
        "name_en": "Close-Grip Bench Press",
        "equipment_id": 6,
        "muscle_ids": [1, 14]
    },
    {
        "name": "卧推凳宽距卧推",
        "name_en": "Wide-Grip Bench Press",
        "equipment_id": 6,
        "muscle_ids": [1, 9]
    },
    {
        "name": "上斜凳上斜卧推",
        "name_en": "Incline Bench Press",
        "equipment_id": 7,
        "muscle_ids": [2, 9, 14]
    },
    {
        "name": "上斜凳上斜飞鸟",
        "name_en": "Incline Flye",
        "equipment_id": 7,
        "muscle_ids": [2]
    },
    {
        "name": "上斜凳哑铃推举",
        "name_en": "Incline Dumbbell Press",
        "equipment_id": 7,
        "muscle_ids": [2, 9, 14]
    },
    {
        "name": "上斜凳弯举",
        "name_en": "Incline Curl",
        "equipment_id": 7,
        "muscle_ids": [13]
    },
    {
        "name": "龙门架飞鸟",
        "name_en": "Cable Flye",
        "equipment_id": 8,
        "muscle_ids": [1]
    },
    {
        "name": "龙门架上斜飞鸟",
        "name_en": "Incline Cable Flye",
        "equipment_id": 8,
        "muscle_ids": [2]
    },
    {
        "name": "龙门架低位飞鸟",
        "name_en": "Low Cable Flye",
        "equipment_id": 8,
        "muscle_ids": [3]
    },
    {
        "name": "龙门架交叉飞鸟",
        "name_en": "Cable Crossover",
        "equipment_id": 8,
        "muscle_ids": [1]
    },
    {
        "name": "龙门架弯举",
        "name_en": "Cable Curl",
        "equipment_id": 8,
        "muscle_ids": [13]
    },
    {
        "name": "龙门架臂屈伸",
        "name_en": "Cable Tricep Extension",
        "equipment_id": 8,
        "muscle_ids": [14]
    },
    {
        "name": "龙门架三头下压",
        "name_en": "Cable Tricep Pushdown",
        "equipment_id": 8,
        "muscle_ids": [14]
    },
    {
        "name": "龙门架侧平举",
        "name_en": "Cable Lateral Raise",
        "equipment_id": 8,
        "muscle_ids": [10]
    },
    {
        "name": "龙门架前平举",
        "name_en": "Cable Front Raise",
        "equipment_id": 8,
        "muscle_ids": [9]
    },
    {
        "name": "龙门架俯身侧平举",
        "name_en": "Cable Rear Delt Flye",
        "equipment_id": 8,
        "muscle_ids": [11]
    },
    {
        "name": "龙门架划船",
        "name_en": "Cable Row",
        "equipment_id": 8,
        "muscle_ids": [4, 5, 13]
    },
    {
        "name": "龙门架单臂划船",
        "name_en": "Single-Arm Cable Row",
        "equipment_id": 8,
        "muscle_ids": [4, 5, 13]
    },
    {
        "name": "龙门架面拉",
        "name_en": "Cable Face Pull",
        "equipment_id": 8,
        "muscle_ids": [11, 6, 12]
    },
    {
        "name": "龙门架悬垂卷腹",
        "name_en": "Cable Crunch",
        "equipment_id": 8,
        "muscle_ids": [25, 26]
    },
    {
        "name": "龙门架髋外展",
        "name_en": "Cable Hip Abduction",
        "equipment_id": 8,
        "muscle_ids": [23]
    },
    {
        "name": "龙门架髋内收",
        "name_en": "Cable Hip Adduction",
        "equipment_id": 8,
        "muscle_ids": [22]
    },
    {
        "name": "龙门架单腿深蹲",
        "name_en": "Cable Single-Leg Squat",
        "equipment_id": 8,
        "muscle_ids": [17, 19]
    },
    {
        "name": "高位下拉",
        "name_en": "Lat Pulldown",
        "equipment_id": 9,
        "muscle_ids": [5, 13, 6]
    },
    {
        "name": "对握高位下拉",
        "name_en": "Neutral-Grip Lat Pulldown",
        "equipment_id": 9,
        "muscle_ids": [5, 13]
    },
    {
        "name": "反握高位下拉",
        "name_en": "Reverse-Grip Lat Pulldown",
        "equipment_id": 9,
        "muscle_ids": [5, 13]
    },
    {
        "name": "颈后高位下拉",
        "name_en": "Behind-the-Neck Lat Pulldown",
        "equipment_id": 9,
        "muscle_ids": [5, 6]
    },
    {
        "name": "坐姿划船",
        "name_en": "Seated Row",
        "equipment_id": 10,
        "muscle_ids": [4, 5, 13]
    },
    {
        "name": "对握坐姿划船",
        "name_en": "Neutral-Grip Seated Row",
        "equipment_id": 10,
        "muscle_ids": [4, 13]
    },
    {
        "name": "窄距坐姿划船",
        "name_en": "Close-Grip Seated Row",
        "equipment_id": 10,
        "muscle_ids": [4, 5, 13]
    },
    {
        "name": "腿举机腿举",
        "name_en": "Leg Press",
        "equipment_id": 11,
        "muscle_ids": [17, 19, 18]
    },
    {
        "name": "窄距腿举",
        "name_en": "Close-Stance Leg Press",
        "equipment_id": 11,
        "muscle_ids": [17]
    },
    {
        "name": "宽距腿举",
        "name_en": "Wide-Stance Leg Press",
        "equipment_id": 11,
        "muscle_ids": [19, 22]
    },
    {
        "name": "单腿腿举",
        "name_en": "Single-Leg Leg Press",
        "equipment_id": 11,
        "muscle_ids": [17, 19]
    },
    {
        "name": "腿屈伸",
        "name_en": "Leg Extension",
        "equipment_id": 12,
        "muscle_ids": [17]
    },
    {
        "name": "单腿腿屈伸",
        "name_en": "Single-Leg Leg Extension",
        "equipment_id": 12,
        "muscle_ids": [17]
    },
    {
        "name": "腿弯举",
        "name_en": "Leg Curl",
        "equipment_id": 13,
        "muscle_ids": [18]
    },
    {
        "name": "单腿腿弯举",
        "name_en": "Single-Leg Leg Curl",
        "equipment_id": 13,
        "muscle_ids": [18]
    },
    {
        "name": "哈克深蹲",
        "name_en": "Hack Squat",
        "equipment_id": 14,
        "muscle_ids": [17, 19]
    },
    {
        "name": "哈克深蹲提踵",
        "name_en": "Hack Squat Calf Raise",
        "equipment_id": 14,
        "muscle_ids": [20]
    },
    {
        "name": "牧师凳弯举",
        "name_en": "Preacher Curl",
        "equipment_id": 15,
        "muscle_ids": [13]
    },
    {
        "name": "单臂牧师凳弯举",
        "name_en": "Single-Arm Preacher Curl",
        "equipment_id": 15,
        "muscle_ids": [13]
    },
    {
        "name": "双杠臂屈伸",
        "name_en": "Dip",
        "equipment_id": 16,
        "muscle_ids": [1, 14, 9]
    },
    {
        "name": "双杠抬腿",
        "name_en": "Leg Raise on Dip Bars",
        "equipment_id": 16,
        "muscle_ids": [25, 21]
    },
    {
        "name": "双杠悬垂举腿",
        "name_en": "Hanging Leg Raise",
        "equipment_id": 16,
        "muscle_ids": [25, 21]
    },
    {
        "name": "引体向上",
        "name_en": "Pull-Up",
        "equipment_id": 17,
        "muscle_ids": [5, 13, 6]
    },
    {
        "name": "宽握引体向上",
        "name_en": "Wide-Grip Pull-Up",
        "equipment_id": 17,
        "muscle_ids": [5, 6]
    },
    {
        "name": "对握引体向上",
        "name_en": "Neutral-Grip Pull-Up",
        "equipment_id": 17,
        "muscle_ids": [5, 13]
    },
    {
        "name": "反握引体向上",
        "name_en": "Chin-Up",
        "equipment_id": 17,
        "muscle_ids": [5, 13]
    },
    {
        "name": "弹力带深蹲",
        "name_en": "Band Squat",
        "equipment_id": 18,
        "muscle_ids": [17, 19]
    },
    {
        "name": "弹力带臀桥",
        "name_en": "Band Hip Thrust",
        "equipment_id": 18,
        "muscle_ids": [19]
    },
    {
        "name": "弹力带侧平举",
        "name_en": "Band Lateral Raise",
        "equipment_id": 18,
        "muscle_ids": [10]
    },
    {
        "name": "弹力带划船",
        "name_en": "Band Row",
        "equipment_id": 18,
        "muscle_ids": [4, 5]
    },
    {
        "name": "弹力带弯举",
        "name_en": "Band Curl",
        "equipment_id": 18,
        "muscle_ids": [13]
    },
    {
        "name": "弹力带臂屈伸",
        "name_en": "Band Tricep Extension",
        "equipment_id": 18,
        "muscle_ids": [14]
    },
    {
        "name": "弹力带飞鸟",
        "name_en": "Band Flye",
        "equipment_id": 18,
        "muscle_ids": [1]
    },
    {
        "name": "弹力带面拉",
        "name_en": "Band Face Pull",
        "equipment_id": 18,
        "muscle_ids": [11, 6]
    },
    {
        "name": "弹力带劈砍",
        "name_en": "Band Chop",
        "equipment_id": 18,
        "muscle_ids": [26, 27]
    },
    {
        "name": "弹力带提踵",
        "name_en": "Band Calf Raise",
        "equipment_id": 18,
        "muscle_ids": [20]
    },
    {
        "name": "TRX深蹲",
        "name_en": "TRX Squat",
        "equipment_id": 19,
        "muscle_ids": [17, 19]
    },
    {
        "name": "TRX箭步蹲",
        "name_en": "TRX Lunge",
        "equipment_id": 19,
        "muscle_ids": [17, 19]
    },
    {
        "name": "TRX划船",
        "name_en": "TRX Row",
        "equipment_id": 19,
        "muscle_ids": [4, 5, 13]
    },
    {
        "name": "TRX胸推",
        "name_en": "TRX Chest Press",
        "equipment_id": 19,
        "muscle_ids": [1, 14]
    },
    {
        "name": "TRX肱三头肌伸展",
        "name_en": "TRX Tricep Extension",
        "equipment_id": 19,
        "muscle_ids": [14]
    },
    {
        "name": "TRX二头肌弯举",
        "name_en": "TRX Bicep Curl",
        "equipment_id": 19,
        "muscle_ids": [13]
    },
    {
        "name": "TRX平板支撑",
        "name_en": "TRX Plank",
        "equipment_id": 19,
        "muscle_ids": [25, 27, 28]
    },
    {
        "name": "TRX登山跑",
        "name_en": "TRX Mountain Climber",
        "equipment_id": 19,
        "muscle_ids": [21, 25, 29]
    },
    {
        "name": "TRX反向卷腹",
        "name_en": "TRX Reverse Crunch",
        "equipment_id": 19,
        "muscle_ids": [25, 21]
    },
    {
        "name": "TRX髋部伸展",
        "name_en": "TRX Hip Extension",
        "equipment_id": 19,
        "muscle_ids": [19, 18]
    },
    {
        "name": "罗马椅背伸展",
        "name_en": "Back Extension",
        "equipment_id": 20,
        "muscle_ids": [7, 28, 19]
    },
    {
        "name": "罗马椅侧向背伸展",
        "name_en": "Side Back Extension",
        "equipment_id": 20,
        "muscle_ids": [26, 7]
    },
    {
        "name": "罗马椅负重背伸展",
        "name_en": "Weighted Back Extension",
        "equipment_id": 20,
        "muscle_ids": [7, 28, 19]
    },
    {
        "name": "臀推机臀推",
        "name_en": "Hip Thrust",
        "equipment_id": 21,
        "muscle_ids": [19]
    },
    {
        "name": "单腿臀推",
        "name_en": "Single-Leg Hip Thrust",
        "equipment_id": 21,
        "muscle_ids": [19]
    },
    {
        "name": "负重臀推",
        "name_en": "Weighted Hip Thrust",
        "equipment_id": 21,
        "muscle_ids": [19]
    },
    {
        "name": "瑜伽垫平板支撑",
        "name_en": "Plank",
        "equipment_id": 22,
        "muscle_ids": [25, 27, 28]
    },
    {
        "name": "瑜伽垫仰卧起坐",
        "name_en": "Sit-Up",
        "equipment_id": 22,
        "muscle_ids": [25, 21]
    },
    {
        "name": "瑜伽垫卷腹",
        "name_en": "Crunch",
        "equipment_id": 22,
        "muscle_ids": [25]
    },
    {
        "name": "瑜伽垫空中蹬车",
        "name_en": "Bicycle Crunch",
        "equipment_id": 22,
        "muscle_ids": [25, 26, 21]
    },
    {
        "name": "瑜伽垫俄式转体",
        "name_en": "Russian Twist",
        "equipment_id": 22,
        "muscle_ids": [26, 25]
    },
    {
        "name": "瑜伽垫抬腿",
        "name_en": "Leg Raise",
        "equipment_id": 22,
        "muscle_ids": [25, 21]
    },
    {
        "name": "瑜伽垫臀桥",
        "name_en": "Glute Bridge",
        "equipment_id": 22,
        "muscle_ids": [19]
    },
    {
        "name": "瑜伽垫鸟狗式",
        "name_en": "Bird-Dog",
        "equipment_id": 22,
        "muscle_ids": [28, 19, 7]
    },
    {
        "name": "瑜伽垫死虫式",
        "name_en": "Dead Bug",
        "equipment_id": 22,
        "muscle_ids": [25, 27, 28]
    },
    {
        "name": "瑜伽垫反向卷腹",
        "name_en": "Reverse Crunch",
        "equipment_id": 22,
        "muscle_ids": [25, 21]
    },
    {
        "name": "俯卧撑",
        "name_en": "Push-Up",
        "equipment_id": 23,
        "muscle_ids": [1, 14, 9]
    },
    {
        "name": "宽距俯卧撑",
        "name_en": "Wide Push-Up",
        "equipment_id": 23,
        "muscle_ids": [1, 9]
    },
    {
        "name": "窄距俯卧撑",
        "name_en": "Close Push-Up",
        "equipment_id": 23,
        "muscle_ids": [1, 14]
    },
    {
        "name": "上斜俯卧撑",
        "name_en": "Incline Push-Up",
        "equipment_id": 23,
        "muscle_ids": [3, 14]
    },
    {
        "name": "下斜俯卧撑",
        "name_en": "Decline Push-Up",
        "equipment_id": 23,
        "muscle_ids": [2, 9, 14]
    },
    {
        "name": "钻石俯卧撑",
        "name_en": "Diamond Push-Up",
        "equipment_id": 23,
        "muscle_ids": [1, 14]
    },
    {
        "name": "击掌俯卧撑",
        "name_en": "Clap Push-Up",
        "equipment_id": 23,
        "muscle_ids": [1, 14, 9]
    },
    {
        "name": "蜘蛛侠俯卧撑",
        "name_en": "Spider-Man Push-Up",
        "equipment_id": 23,
        "muscle_ids": [1, 21, 26]
    },
    {
        "name": "深蹲",
        "name_en": "Squat",
        "equipment_id": 23,
        "muscle_ids": [17, 19]
    },
    {
        "name": "跳蹲",
        "name_en": "Jump Squat",
        "equipment_id": 23,
        "muscle_ids": [17, 19]
    },
    {
        "name": "箭步蹲",
        "name_en": "Lunge",
        "equipment_id": 23,
        "muscle_ids": [17, 19]
    },
    {
        "name": "行走箭步蹲",
        "name_en": "Walking Lunge",
        "equipment_id": 23,
        "muscle_ids": [17, 19]
    },
    {
        "name": "侧弓步",
        "name_en": "Side Lunge",
        "equipment_id": 23,
        "muscle_ids": [17, 22, 19]
    },
    {
        "name": "保加利亚分腿蹲",
        "name_en": "Bulgarian Split Squat",
        "equipment_id": 23,
        "muscle_ids": [17, 19]
    },
    {
        "name": "单腿深蹲",
        "name_en": "Pistol Squat",
        "equipment_id": 23,
        "muscle_ids": [17, 19]
    },
    {
        "name": "登阶",
        "name_en": "Step-Up",
        "equipment_id": 23,
        "muscle_ids": [17, 19]
    },
    {
        "name": "髋外展",
        "name_en": "Hip Abduction",
        "equipment_id": 23,
        "muscle_ids": [23]
    },
    {
        "name": "髋内收",
        "name_en": "Hip Adduction",
        "equipment_id": 23,
        "muscle_ids": [22]
    },
    {
        "name": "登山跑",
        "name_en": "Mountain Climber",
        "equipment_id": 23,
        "muscle_ids": [21, 25, 29]
    },
    {
        "name": "波比跳",
        "name_en": "Burpee",
        "equipment_id": 23,
        "muscle_ids": [17, 1, 29, 19]
    },
    {
        "name": "开合跳",
        "name_en": "Jumping Jack",
        "equipment_id": 23,
        "muscle_ids": [10, 22, 23]
    },
    {
        "name": "深蹲跳",
        "name_en": "Squat Jump",
        "equipment_id": 23,
        "muscle_ids": [17, 19]
    },
    {
        "name": "弓步跳",
        "name_en": "Lunge Jump",
        "equipment_id": 23,
        "muscle_ids": [17, 19]
    },
    {
        "name": "熊爬",
        "name_en": "Bear Crawl",
        "equipment_id": 23,
        "muscle_ids": [8, 4, 29, 17]
    },
    {
        "name": "蟹行",
        "name_en": "Crab Walk",
        "equipment_id": 23,
        "muscle_ids": [14, 11, 29]
    },
    {
        "name": "超人式",
        "name_en": "Superman",
        "equipment_id": 23,
        "muscle_ids": [7, 28, 19]
    },
    {
        "name": "侧卧抬腿",
        "name_en": "Side-Lying Leg Raise",
        "equipment_id": 23,
        "muscle_ids": [23]
    },
    {
        "name": "蚌式开合",
        "name_en": "Clamshell",
        "equipment_id": 23,
        "muscle_ids": [23]
    }
]
"""


def load_exercises() -> list[dict]:
    """解析 JSON，返回 exercise 列表。"""
    return json.loads(EXERCISES_JSON)


def get_database_url() -> str:
    """获取数据库 URL，优先读环境变量，其次 .env.development，最后 .env.production。"""
    url = os.getenv("DATABASE_URL")
    if not url:
        # 先尝试 .env.development（本地开发），再 .env.production（Docker 部署）
        secret_dir = os.path.join(os.path.dirname(__file__), "..", "secret")
        for env_name in (".env.development", ".env.production"):
            env_file = os.path.join(secret_dir, env_name)
            if os.path.exists(env_file):
                with open(env_file) as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("#") or "=" not in line:
                            continue
                        k, v = line.split("=", 1)
                        if k == "DATABASE_URL":
                            url = v.strip().strip('"').strip("'")
                            break
            if url:
                break
    if not url:
        url = "postgresql://user:password@localhost:5432/backend_dev"

    # 确保使用 asyncpg 驱动
    if "asyncpg" not in url:
        url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
        url = url.replace("postgresql+psycopg2://", "postgresql+asyncpg://", 1)
    return url


async def main():
    db_url = get_database_url()
    print(f"连接数据库: {db_url[: db_url.index('@')] if '@' in db_url else '...'}")

    engine = create_async_engine(db_url, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    exercises_data = load_exercises()
    print(f"共 {len(exercises_data)} 个动作待导入")

    async with async_session() as session:
        created = 0
        skipped = 0

        for item in exercises_data:
            muscle_ids = item["muscle_ids"]
            if not muscle_ids:
                print(f"  跳过（无肌群）: {item['name']}")
                skipped += 1
                continue

            # muscle_ids[0] → 主肌群，其余 → 辅助肌群
            primary_id = muscle_ids[0]
            secondary_ids = muscle_ids[1:]

            # 自动判断动作类型：多肌群 → compound，单肌群 → isolation
            exercise_type = "compound" if len(muscle_ids) >= 2 else "isolation"

            exercise = Exercise(
                name=item["name"],
                name_en=item["name_en"],
                exercise_type=exercise_type,
                primary_muscle_group_id=primary_id,
                equipment_id=item.get("equipment_id"),
                is_custom=False,
            )

            session.add(exercise)
            await session.flush()  # 获取 exercise.id

            for mg_id in secondary_ids:
                session.add(
                    ExerciseSecondaryMuscle(
                        exercise_id=exercise.id, muscle_group_id=mg_id
                    )
                )

            created += 1
            print(
                f"  ✓ {item['name']} ({item['name_en']}) "
                f"[{exercise_type}] primary={primary_id} secondary={secondary_ids}"
            )

        await session.commit()
        print(f"\n完成：导入 {created} 个动作，跳过 {skipped} 个")


if __name__ == "__main__":
    asyncio.run(main())
