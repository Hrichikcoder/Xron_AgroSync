import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.services.market_service import update_market_summary_cache
# Import all routers
from app.api.routers import sensors, disease, markets, pump

app = FastAPI(title="Smart Irrigation API", version="1.0.0")

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register Routers
app.include_router(sensors.router)
app.include_router(disease.router)
app.include_router(markets.router)
app.include_router(pump.router)


@app.on_event("startup")
async def startup_event():
    # Pre-populate Redis cache so the frontend gets instant data
    update_market_summary_cache()

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)