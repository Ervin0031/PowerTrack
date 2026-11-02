"""训练块请求体。响应保持 snake_case。"""

from datetime import date

from pydantic import Field, model_validator

from app.schemas.workout import CamelModel


class ProgramDayWrite(CamelModel):
    weekday: int = Field(ge=0, le=6)
    template_id: int


class ProgramWrite(CamelModel):
    title: str = Field(min_length=1, max_length=80)
    week_count: int = Field(default=4, ge=1, le=8)
    deload_week: int = Field(default=4, ge=1, le=8)
    started_on: date
    days: list[ProgramDayWrite] = Field(min_length=1, max_length=7)

    @model_validator(mode="after")
    def deload_inside_block(self):
        if not 1 <= self.deload_week <= self.week_count:
            raise ValueError("减量周要落在周期长度里")
        weekdays = [day.weekday for day in self.days]
        if len(weekdays) != len(set(weekdays)):
            raise ValueError("同一天只能排一个模板")
        return self
