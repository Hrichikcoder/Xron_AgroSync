# app/models/user.py
from sqlalchemy import Column, Integer, String, LargeBinary, ForeignKey
from sqlalchemy.orm import relationship
from app.db.postgres import Base

class UserProfile(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    phone = Column(String)
    profile_pic = Column(LargeBinary, nullable=True) # Stores image byte data
    
    # Establish relationship (One user has many fields)
    fields = relationship("FarmField", back_populates="owner", cascade="all, delete-orphan")

class FarmField(Base):
    __tablename__ = "farm_fields"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True) # Removed unique=True so different users can use the same field names
    area = Column(String)
    
    # Link strictly to the specific user
    user_id = Column(Integer, ForeignKey("users.id"))
    
    # Establish relationship back to user
    owner = relationship("UserProfile", back_populates="fields")