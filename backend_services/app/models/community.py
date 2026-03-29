from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.db.postgres import Base
from datetime import datetime, timezone

class Post(Base):
    __tablename__ = "community_posts"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True)
    author_name = Column(String)
    title = Column(String)
    content = Column(Text)
    # UPDATED: Now uses timezone-aware UTC fetching
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    
    replies = relationship("Reply", back_populates="post", cascade="all, delete-orphan")

class Reply(Base):
    __tablename__ = "community_replies"
    
    id = Column(Integer, primary_key=True, index=True)
    post_id = Column(Integer, ForeignKey("community_posts.id"))
    user_id = Column(String)
    author_name = Column(String)
    content = Column(Text)
    # UPDATED: Now uses timezone-aware UTC fetching
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    
    post = relationship("Post", back_populates="replies")

class GovScheme(Base):
    __tablename__ = "gov_schemes"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String)
    description = Column(Text)
    link = Column(String, nullable=True)
    state = Column(String, nullable=True)