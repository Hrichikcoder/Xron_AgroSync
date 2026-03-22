# app/models/user_crop.py (Example)
from sqlalchemy import Column, Integer, String, UniqueConstraint
from app.db.postgres import Base # Assuming you have a declarative base

class UserTrackedCrop(Base):
    __tablename__ = "user_tracked_crops"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True) # Change to Integer if your user IDs are ints
    crop_name = Column(String, nullable=False)
    
    # Ensure a user can't track the exact same crop twice
    __table_args__ = (UniqueConstraint('user_id', 'crop_name', name='_user_crop_uc'),)