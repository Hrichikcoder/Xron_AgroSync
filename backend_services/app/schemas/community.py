from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class ReplyCreate(BaseModel):
    content: str  # Removed user_id and author_name

class ReplyResponse(BaseModel):
    id: int
    post_id: int
    user_id: str
    author_name: str
    content: str
    created_at: datetime

    class Config:
        from_attributes = True

class PostCreate(BaseModel):
    title: str    # Removed user_id and author_name
    content: str

class PostResponse(BaseModel):
    id: int
    user_id: str
    author_name: str
    title: str
    content: str
    created_at: datetime
    replies: List[ReplyResponse] = []

    class Config:
        from_attributes = True

class GovSchemeResponse(BaseModel):
    id: int
    title: str
    description: str
    link: Optional[str] = None
    state: Optional[str] = None

    class Config:
        from_attributes = True