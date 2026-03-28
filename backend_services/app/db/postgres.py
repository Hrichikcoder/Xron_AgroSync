"""
# app/db/postgres.py
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# Create database engine
engine = create_engine(settings.POSTGRES_URL)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()

# Dependency to get DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()"""

# app/db/postgres.py
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# 1. SQLAlchemy requires 'postgresql://', but sometimes older tools provide 'postgres://'.
# This ensures the URL is always perfectly formatted.
db_url = settings.POSTGRES_URL
if db_url and db_url.startswith("postgres://"):
    db_url = db_url.replace("postgres://", "postgresql://", 1)

# 2. Configure the engine for cloud resilience
engine = create_engine(
    db_url,
    pool_pre_ping=True,  # Crucial: Tests the connection before sending queries (prevents drop-outs)
    pool_size=10,        # Number of connections to keep open
    max_overflow=20,     # Allow up to 20 extra connections during traffic spikes
)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()

# Dependency to get DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()