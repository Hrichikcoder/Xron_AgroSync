import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.services.market_service import update_market_summary_cache
from app.api.routers import sensors, disease, markets, pump, profile, notifications, auth

# 1. Import your database engine and Base
from app.db.postgres import engine, Base
# 2. Import your models so SQLAlchemy knows they exist
from app.models.user import UserProfile, FarmField 
from app.models.market_data import CrowdsourcedPrice
from app.models.user_crop import UserTrackedCrop
# 3. Create the tables in your Neon PostgreSQL database automatically
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Smart Irrigation API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sensors.router)
app.include_router(disease.router)
app.include_router(markets.router)
app.include_router(pump.router)
app.include_router(profile.router)
app.include_router(notifications.router)
app.include_router(auth.router)

@app.on_event("startup")
async def startup_event():
    update_market_summary_cache()

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)