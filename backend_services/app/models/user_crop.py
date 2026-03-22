from sqlalchemy import Column, Integer, String, Boolean, UniqueConstraint
from app.db.postgres import Base

class UserTrackedCrop(Base):
    __tablename__ = "user_tracked_crops"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True) 
    crop_name = Column(String, nullable=False)
    is_starred = Column(Boolean, default=False) # <-- NEW FIELD
    
    __table_args__ = (UniqueConstraint('user_id', 'crop_name', name='_user_crop_uc'),)