from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
from app.schemas.payloads import PredictionRequest, FeedbackPayload
from app.services.market_service import recommend_real_markets, update_market_summary_cache, get_real_market_features, retrain_model_batch
from app.db.redis_client import get_cache
from app.db.postgres import get_db
from pydantic import BaseModel, Field
from typing import List
from app.models.user_crop import UserTrackedCrop
from app.models.market_data import CrowdsourcedPrice
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta
import statistics
import xgboost as xgb
from app.core.config import settings
from collections import Counter
import os
import json
from google import genai

router = APIRouter(prefix="/api", tags=["Markets"])

# ==========================================
# PYDANTIC SCHEMAS
# ==========================================
class TrackCropRequest(BaseModel):
    user_id: str
    crop_name: str

class StarCropRequest(BaseModel):
    user_id: str
    crop_name: str
    is_starred: bool

class ParseSpeechRequest(BaseModel):
    text: str
    language: str

class ParsedSpeechResponse(BaseModel):
    crop: str = Field(description="The English translated name of the crop. Empty string if not found.")
    market: str = Field(description="The English translated name of the market or location. Empty string if not found.")
    price: str = Field(description="The calculated price strictly for 10kg of the crop as a number string. Empty string if not found.")


# ==========================================
# TREND CALCULATION HELPER
# ==========================================
def get_crowdsourced_trend(db: Session, crop_name: str, current_price_10kg: float) -> str:
    """
    Calculates the % difference between today's predicted price 
    and the last known real-world crowdsourced average.
    """
    crop_clean = crop_name.capitalize()
    today = datetime.utcnow().date()
    
    # 1. Get the max date BEFORE today
    last_date_result = db.query(func.max(func.date(CrowdsourcedPrice.reported_at)))\
        .filter(
            CrowdsourcedPrice.crop_name == crop_clean,
            func.date(CrowdsourcedPrice.reported_at) < today
        ).scalar()
        
    if not last_date_result:
        return "0.0%"
        
    # 2. Get all crowdsourced prices on that specific date
    past_records = db.query(CrowdsourcedPrice).filter(
        CrowdsourcedPrice.crop_name == crop_clean,
        func.date(CrowdsourcedPrice.reported_at) == last_date_result
    ).all()
    
    if not past_records:
        return "0.0%"
        
    past_prices = [float(r.selling_price) for r in past_records]
    avg_past = sum(past_prices) / len(past_prices)
    
    if avg_past == 0:
        return "0.0%"
        
    # 3. Calculate Day-over-Day percentage change
    pct_change = ((current_price_10kg - avg_past) / avg_past) * 100
    return f"{'+' if pct_change > 0 else ''}{pct_change:.1f}%"


# ==========================================
# CORE MARKET ENDPOINTS
# ==========================================
@router.post("/markets/parse_speech")
def parse_speech(request: ParseSpeechRequest):
    try:
        # Use settings if available, fallback to os.environ for the API Key
        api_key = getattr(settings, "GEMINI_API_KEY", os.environ.get("GEMINI_API_KEY"))
        client = genai.Client(api_key="AIzaSyC-HhD72DgkkhpO3YakMIVwvUjUYoRRDkw") 
        
        prompt = f"""
        You are an agricultural data extractor. Extract the Crop Name, Market Name, and Price from the user's spoken text.
        Translate the Crop Name and Market Name to English.
        
        CRITICAL CALCULATION RULE FOR PRICE: 
        The target form expects the price strictly per 10kg. 
        If the user mentions a different quantity, you MUST calculate the proportional price for exactly 10kg.
        - Example 1: If user says "sold 100kg for 20 rupees", math is 20 / (100/10). Output: "2"
        - Example 2: If user says "sold 1 quintal (100kg) for 2500", output: "250"
        - Example 3: If user says "50 rupees per kg", output: "500"
        - Example 4: If no quantity is mentioned, assume the price given is already for 10kg.
        
        If a value is not found, leave it as an empty string.

        Spoken Text: "{request.text}"
        """
        
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config={
                'response_mime_type': 'application/json',
                'response_schema': ParsedSpeechResponse,
                'temperature': 0.1
            }
        )

        # The new SDK parses it into a Pydantic object automatically when a schema is provided
        if response.parsed:
            return response.parsed.model_dump()
        else:
            return json.loads(response.text)
    
    except Exception as e:
        print(f"NLP Parsing Error: {e}")
        # Fallback to empty fields so the user can type them manually if it fails
        return {"crop": "", "market": "", "price": ""}

@router.post("/predict_markets")
def predict_markets(request: PredictionRequest, db: Session = Depends(get_db)):
    try:
        results_df = recommend_real_markets(
            crop=request.crop,
            farmer_lat=request.lat,
            farmer_lon=request.lon,
            transport_cost_per_km=request.transport_rate
        )
        recommendations = [] if results_df.empty else results_df.to_dict(orient="records")
        
        # Inject the real trend based on crowdsourced history
        trend_str = "0.0%"
        if recommendations:
            top3 = recommendations[:3]
            avg_price_quintal = sum(m['Expected Price (Rs/Q)'] for m in top3) / len(top3)
            avg_price_10kg = avg_price_quintal / 10
            trend_str = get_crowdsourced_trend(db, request.crop, avg_price_10kg)

        return {
            "coordinates": {"lat": request.lat, "lon": request.lon},
            "target_crop": request.crop.upper(),
            "recommendations": recommendations,
            "trend": trend_str
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/markets/summary")
def get_market_summary():
    cached_summary = get_cache("market_summary")
    if cached_summary:
        return {"summary": cached_summary}
    return {"summary": update_market_summary_cache()}

@router.post("/markets/update_cache")
def trigger_cache_update(background_tasks: BackgroundTasks):
    background_tasks.add_task(update_market_summary_cache)
    return {"message": "Market summary cache update triggered in the background."}


# ==========================================
# USER PREFERENCES (TRACKING & STARS)
# ==========================================
@router.post("/user/crops/add")
def add_user_crop(request: TrackCropRequest, db: Session = Depends(get_db)):
    crop_name = request.crop_name.capitalize()
    existing = db.query(UserTrackedCrop).filter_by(user_id=request.user_id, crop_name=crop_name).first()
    if not existing:
        db.add(UserTrackedCrop(user_id=request.user_id, crop_name=crop_name))
        db.commit()
    return {"status": "success", "crop": crop_name}

@router.delete("/user/{user_id}/crops/{crop_name}")
def delete_user_crop(user_id: str, crop_name: str, db: Session = Depends(get_db)):
    crop = db.query(UserTrackedCrop).filter_by(user_id=user_id, crop_name=crop_name.capitalize()).first()
    if crop:
        db.delete(crop)
        db.commit()
    return {"status": "success"}

@router.post("/user/crops/star")
def toggle_star_crop(request: StarCropRequest, db: Session = Depends(get_db)):
    crop_name = request.crop_name.capitalize()
    existing = db.query(UserTrackedCrop).filter_by(user_id=request.user_id, crop_name=crop_name).first()
    
    if existing:
        existing.is_starred = request.is_starred
    else:
        if request.is_starred:
            new_crop = UserTrackedCrop(user_id=request.user_id, crop_name=crop_name, is_starred=True)
            db.add(new_crop)
            
    db.commit()
    return {"status": "success", "is_starred": request.is_starred}

@router.get("/user/{user_id}/markets/summary")
def get_user_market_summary(user_id: str, db: Session = Depends(get_db)):
    user_crops = db.query(UserTrackedCrop).filter_by(user_id=user_id).all()
    custom_crop_names = [c.crop_name.capitalize() for c in user_crops]
    starred_status_map = {c.crop_name.capitalize(): c.is_starred for c in user_crops}
    
    cached_summary = get_cache("market_summary") or []
    custom_summary = []
    
    try:
        model = xgb.XGBRegressor()
        model.load_model(settings.MARKET_MODEL_PATH)
        expected_features = model.feature_names_in_ if hasattr(model, 'feature_names_in_') else model.get_booster().feature_names

        for crop in custom_crop_names:
            cached_item = next((item for item in cached_summary if item['crop'].lower() == crop.lower()), None)
            if cached_item:
                cached_copy = cached_item.copy()
                cached_copy["detail"] = "Custom user tracked crop."
                cached_copy["is_starred"] = starred_status_map.get(crop, False)
                # Overwrite the default trend with live DoD trend
                price_10kg = cached_item['price'] * 10
                cached_copy["trend"] = get_crowdsourced_trend(db, crop, price_10kg)
                custom_summary.append(cached_copy)
                continue

            latest_data = get_real_market_features(crop) 
            if not latest_data.empty:
                predictions = [float(model.predict(row.reindex(expected_features).to_frame().T.astype(float).fillna(0))[0]) for _, row in latest_data.iterrows()]
                avg_price_quintal = sum(predictions) / len(predictions) if predictions else 0.0
                price_10kg = avg_price_quintal / 10
                
                custom_summary.append({
                    "crop": crop.capitalize(),
                    "price": round(avg_price_quintal / 100, 2), 
                    "trend": get_crowdsourced_trend(db, crop, price_10kg),
                    "color": "blue",
                    "detail": "Custom user tracked crop.",
                    "is_starred": starred_status_map.get(crop, False)
                })
    except Exception as e:
        print(f"Prediction Error: {e}")

    filtered_cached_summary = []
    for item in cached_summary:
        if item['crop'].capitalize() not in custom_crop_names:
            item['is_starred'] = False 
            price_10kg = item['price'] * 10
            item['trend'] = get_crowdsourced_trend(db, item['crop'], price_10kg)
            filtered_cached_summary.append(item)

    return {"summary": custom_summary + filtered_cached_summary}


# ==========================================
# CROWDSOURCED COMMUNITY & ML FEEDBACK
# ==========================================
@router.post("/markets/feedback")
def submit_market_feedback(payload: FeedbackPayload, db: Session = Depends(get_db)):
    try:
        new_feedback = CrowdsourcedPrice(
            user_id=payload.user_id,
            crop_name=payload.crop_name.capitalize(),
            market_name=payload.market_name.title(),
            selling_price=payload.selling_price,
            lat=payload.lat,
            lon=payload.lon
        )
        db.add(new_feedback)
        db.commit()
        return {"status": "success", "message": "Feedback submitted successfully."}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/markets/admin/retrain_batch")
def trigger_batch_retrain(db: Session = Depends(get_db)):
    result = retrain_model_batch(db)
    return result

@router.get("/markets/community")
def get_community_markets(db: Session = Depends(get_db)):
    try:
        today_date = datetime.utcnow().date()
        # Fetch up to 2 years of data to support "Previous Year" comparisons
        two_years_ago = today_date - timedelta(days=730)
        
        reports = db.query(CrowdsourcedPrice).filter(
            func.date(CrowdsourcedPrice.reported_at) >= two_years_ago
        ).order_by(CrowdsourcedPrice.reported_at.desc()).all()
        
        grouped = {}
        for r in reports:
            crop = r.crop_name
            if crop not in grouped:
                grouped[crop] = []
            grouped[crop].append(r)
            
        community_data = []
        
        for crop, crop_reports in grouped.items():
            market_groups = {}
            for r in crop_reports:
                mkt = r.market_name
                if mkt not in market_groups:
                    market_groups[mkt] = []
                market_groups[mkt].append(r)
                
            markets_breakdown = []
            for mkt, mkt_reports in market_groups.items():
                history_dict = {}
                today_prices = []
                for r in mkt_reports:
                    if r.reported_at:
                        d_str = r.reported_at.strftime("%Y-%m-%d")
                        val = float(r.selling_price)
                        if d_str not in history_dict:
                            history_dict[d_str] = []
                        history_dict[d_str].append(val)
                        if r.reported_at.date() == today_date:
                            today_prices.append(val)
                            
                history = []
                for d_str, prices in sorted(history_dict.items()):
                    history.append({
                        "date": d_str,
                        "price": round(sum(prices)/len(prices), 2),
                        "min": round(min(prices), 2),
                        "max": round(max(prices), 2)
                    })
                    
                if not history:
                    continue
                
                avg_today = sum(today_prices)/len(today_prices) if today_prices else history[-1]['price']
                
                markets_breakdown.append({
                    "market": mkt,
                    "state": "West Bengal",
                    "price": round(avg_today, 2),
                    "reports": len(today_prices),
                    "history": history
                })
                    
            if markets_breakdown:
                community_data.append({
                    "crop": crop,
                    "markets": sorted(markets_breakdown, key=lambda x: x['reports'], reverse=True)
                })
            
        return {"community_markets": community_data}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/user/{user_id}/selling_pattern")
def get_selling_pattern(user_id: str, db: Session = Depends(get_db)):
    records = db.query(CrowdsourcedPrice).filter(CrowdsourcedPrice.user_id == user_id).all()
    if not records:
        return {"should_prompt": False}
    
    days_of_week = [r.reported_at.weekday() for r in records if r.reported_at]
    if not days_of_week:
        return {"should_prompt": False}
        
    most_common_day = Counter(days_of_week).most_common(1)[0][0]
    today_day = datetime.utcnow().weekday()
    
    last_sale = max([r.reported_at for r in records if r.reported_at])
    days_since_last = (datetime.utcnow() - last_sale).days

    days_map = {0: "Mondays", 1: "Tuesdays", 2: "Wednesdays", 3: "Thursdays", 4: "Fridays", 5: "Saturdays", 6: "Sundays"}

    if today_day == most_common_day and days_since_last > 0:
        return {
            "should_prompt": True, 
            "message": f"You usually sell on {days_map[most_common_day]}. Did you sell today? Add quickly in 5 sec!"
        }
    elif days_since_last > 0 and days_since_last % 7 == 0:
        return {
            "should_prompt": True,
            "message": "It's been a week since your last sale. Did you sell today? Add quickly in 5 sec!"
        }

    return {"should_prompt": False}