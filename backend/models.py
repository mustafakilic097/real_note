from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class NoteIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    content: Optional[str] = Field(default="", max_length=10000)

class NoteOut(BaseModel):
    id: str
    userId: str
    title: str
    content: str
    createdAt: str
    updatedAt: str
