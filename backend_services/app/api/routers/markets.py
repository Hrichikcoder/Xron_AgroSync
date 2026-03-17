from fastapi import APIRouter, HTTPException, BackgroundTasks
from app.schemas.payloads import PredictionRequest
from app.services.market_service import recommend_real_markets, update_market_summary_cache
from app.db.redis_client import get_cache

router = APIRouter(prefix="/api", tags=["Markets"])

@router.post("/predict_markets")
def predict_markets(request: PredictionRequest):
    try:
        results_df = recommend_real_markets(
            crop=request.crop,
            farmer_lat=request.lat,
            farmer_lon=request.lon,
            transport_cost_per_km=request.transport_rate
        )

        recommendations = [] if results_df.empty else results_df.to_dict(orient="records")

        return {
            "coordinates": {"lat": request.lat, "lon": request.lon},
            "target_crop": request.crop.upper(),
            "recommendations": recommendations
        }
    except Exception as e:
        print(f"CRITICAL ERROR: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/markets/summary")
def get_market_summary():
    cached_summary = get_cache("market_summary")
    if cached_summary:
        return {"summary": cached_summary}
    
    summary = update_market_summary_cache()
    return {"summary": summary}

@router.post("/markets/update_cache")
def trigger_cache_update(background_tasks: BackgroundTasks):
    background_tasks.add_task(update_market_summary_cache)
    return {"message": "Market summary cache update triggered in the background."}