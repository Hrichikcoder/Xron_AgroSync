from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
from app.schemas.payloads import PredictionRequest
from app.services.market_service import recommend_real_markets, update_market_summary_cache, get_real_market_features
from app.db.redis_client import get_cache
from app.db.postgres import get_db
from pydantic import BaseModel
from typing import List
from app.models.user_crop import UserTrackedCrop
from sqlalchemy.orm import Session
import xgboost as xgb
from app.core.config import settings

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


class TrackCropRequest(BaseModel):
    user_id: str
    crop_name: str

# 1. Add a crop
@router.post("/user/crops/add")
def add_user_crop(request: TrackCropRequest, db: Session = Depends(get_db)):
    # Standardize crop name format
    crop_name = request.crop_name.capitalize()
    
    existing = db.query(UserTrackedCrop).filter_by(
        user_id=request.user_id, crop_name=crop_name
    ).first()
    
    if not existing:
        new_crop = UserTrackedCrop(user_id=request.user_id, crop_name=crop_name)
        db.add(new_crop)
        db.commit()
    
    return {"status": "success", "crop": crop_name}

# 2. Delete a crop
@router.delete("/user/{user_id}/crops/{crop_name}")
def delete_user_crop(user_id: str, crop_name: str, db: Session = Depends(get_db)):
    crop = db.query(UserTrackedCrop).filter_by(
        user_id=user_id, crop_name=crop_name.capitalize()
    ).first()
    
    if crop:
        db.delete(crop)
        db.commit()
        
    return {"status": "success"}

# 3. Get User Crops Summary
@router.get("/user/{user_id}/markets/summary")
def get_user_market_summary(user_id: str, db: Session = Depends(get_db)):
    # 1. Get user's custom crops from PostgreSQL
    user_crops = db.query(UserTrackedCrop).filter_by(user_id=user_id).all()
    custom_crop_names = [c.crop_name for c in user_crops]
    
    # 2. Get global defaults
    cached_summary = get_cache("market_summary") or []
    
    # 3. Fetch real-time data for the user's custom crops
    custom_summary = []
    
    # Load model dynamically for custom crops not in default cache
    model = xgb.XGBRegressor()
    model.load_model(settings.MARKET_MODEL_PATH)
    try:
        expected_features = model.feature_names_in_
    except AttributeError:
        expected_features = model.get_booster().feature_names

    for crop in custom_crop_names:
        # Check if crop is already in the global cache to save API processing time
        cached_item = next((item for item in cached_summary if item['crop'].lower() == crop.lower()), None)
        
        if cached_item:
            cached_copy = cached_item.copy()
            cached_copy["detail"] = "Custom user tracked crop."
            custom_summary.append(cached_copy)
            continue

        # If it's a completely new crop, run the prediction model
        latest_data = get_real_market_features(crop) 
        if not latest_data.empty:
            predictions = []
            for index, row in latest_data.iterrows():
                feature_vector = row.reindex(expected_features).to_frame().T.astype(float).fillna(0)
                pred_price = model.predict(feature_vector)[0]
                predictions.append(float(pred_price))
            
            avg_price = sum(predictions) / len(predictions) if predictions else 0.0

            custom_summary.append({
                "crop": crop,
                "price": round(avg_price / 100, 2), 
                "trend": "+0.0%",
                "color": "blue",
                "detail": "Custom user tracked crop."
            })

    # 4. Remove duplicates (Filter out defaults that the user is explicitly tracking)
    # This prevents the double-listing issue
    filtered_cached_summary = [item for item in cached_summary if item['crop'] not in custom_crop_names]

    # Combine custom crops at the top, followed by remaining global defaults
    return {"summary": custom_summary + filtered_cached_summary}