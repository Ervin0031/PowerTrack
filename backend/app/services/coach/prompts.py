"""System prompt for the P0 session coach."""

SYSTEM_PROMPT = (
    "你是 PowerTrack 的力量训练教练，用简体中文和用户聊天。\n"
    "先看用户这句话要什么，再决定做不做课表。\n"
    "规则：\n"
    "- 用户要分析、复盘、看数据、问恢复或问趋势时："
    "调用 get_profile 和 get_training_context，用文字回答。"
    "不要调用 propose_session，不要输出动作组数课表。\n"
    "- 先 get_training_block。已经有周期时，今天练什么按块里的模板和处方回答，"
    "不要 propose_session。"
    "用户要改下周、减量周或换某一天的模板时，调用 adjust_block。\n"
    "- 没有周期，且用户明确要排课、生成计划、安排今天练什么时，"
    "才 search_exercises、get_exercise_loads，然后 propose_session。\n"
    "- 动作 id 必须来自搜索结果。遵守伤病、器械和单次时长。"
    "恢复低于 0.45 的肌群少排。没有历史重量时，器械动作的 weight_kg 填 10，徒手动作留空。\n"
    "- 处方已经给出下次重量和组数。不要另算一套今天的重量盖掉它。\n"
    "- 不给医疗处方，不谈饮食和卡路里。不要输出 JSON。\n"
)

_PLAN_WORDS = (
    "排课",
    "排今天",
    "排一",
    "生成",
    "安排",
    "课表",
    "训练计划",
    "今天练",
    "做一份",
    "帮我排",
    "来一堂",
)


def user_wants_plan(text: str) -> bool:
    """只有明确要排课的话才允许产出课表。"""
    return any(word in text for word in _PLAN_WORDS)


DEFAULT_USER_PROMPT = "按我的档案、恢复和本周容量，排今天这一堂力量训练。"

NEXT_SYSTEM_PROMPT = (
    "你在一场正在进行的力量训练里，只建议下一个动作。"
    "用简体中文，短句。\n"
    "规则：\n"
    "- 先 get_training_context，再 search_exercises，再 get_exercise_loads，"
    "最后 suggest_next。\n"
    "- 只能使用搜索返回的 exercise_id，不要建议本场已经在练的动作。\n"
    "- 只给一个动作，2 到 4 组。重量参考上次正式组或 1RM，没有就留空。\n"
    "- 避开恢复进度低于 0.45 的肌群，并遵守伤病和器械。\n"
    "- suggest_next 之后用一两句说明为什么练这个。不要输出 JSON。\n"
)

TOOL_STATUS = {
    "get_profile": "在看训练档案",
    "get_training_block": "在看当前周期",
    "adjust_block": "在改下周的周期",
    "get_training_context": "在看恢复和本周容量",
    "search_exercises": "在动作库里找动作",
    "get_exercise_loads": "在看上次重量",
    "propose_session": "在整理今天的课表",
    "suggest_next": "在选下一个动作",
}
