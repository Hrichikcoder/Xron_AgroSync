from sqlalchemy import Column, Integer, String, Numeric, DateTime, Boolean
from app.db.postgres import Base
from datetime import datetime

class CrowdsourcedPrice(Base):
    __tablename__ = "crowdsourced_prices"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True)
    crop_name = Column(String, index=True)
    market_name = Column(String, index=True)
    selling_price = Column(Numeric(10, 2))
    lat = Column(Numeric(10, 6), nullable=True)
    lon = Column(Numeric(10, 6), nullable=True)
    reported_at = Column(DateTime, default=datetime.utcnow)
    is_trained = Column(Boolean, default=False) # <-- Added tracking flag