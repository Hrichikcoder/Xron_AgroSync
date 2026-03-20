# app/models/user.py
from sqlalchemy import Column, Integer, String, LargeBinary
from app.db.postgres import Base

class UserProfile(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    phone = Column(String)
    location = Column(String)
    profile_pic = Column(LargeBinary, nullable=True) # Stores image byte data