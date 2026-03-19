import time
import re
import requests
import pandas as pd
import xgboost as xgb
from math import radians, cos, sin, asin, sqrt
from app.core.config import settings
from app.services.data_loader import build_data_lake, merge_pipeline, normalize_crop_name
from app.db.redis_client import set_cache, get_cache

# Load Model once at startup
market_model = xgb.XGBRegressor()
market_model.load_model(settings.MARKET_MODEL_PATH)

def haversine_distance(lat1, lon1, lat2, lon2):
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    return 6371 * c

def get_driving_route_osrm(lat1, lon1, lat2, lon2):
    """
    Uses the free OSRM API to get actual driving distance and duration.
    Falls back to Haversine straight-line if the API fails or times out.
    """
    url = f"http://router.project-osrm.org/route/v1/driving/{lon1},{lat1};{lon2},{lat2}?overview=false"
    
    try:
        response = requests.get(url, timeout=2) # 2 second timeout to prevent hanging
        if response.status_code == 200:
            data = response.json()
            if data.get("routes"):
                distance_km = data["routes"][0]["distance"] / 1000.0
                duration_mins = data["routes"][0]["duration"] / 60.0
                return distance_km, duration_mins
    except Exception as e:
        print(f"OSRM Routing failed, falling back to Haversine: {e}")
        
    # Fallback to straight line if no internet or API limit hit
    return haversine_distance(lat1, lon1, lat2, lon2), None

def get_real_market_features(target_crop):
    cache_key = f"market_features_{normalize_crop_name(target_crop)}"
    cached_df = get_cache(cache_key)
    
    if cached_df:
        # If cache hit, load the dictionary/list directly into a DataFrame
        return pd.DataFrame(cached_df)

    lake = build_data_lake(settings.DATASET_DIR)
    df = merge_pipeline(lake)
    
    if df.empty: return pd.DataFrame()
        
    df = df.sort_values(by=['State', 'District', 'Market', 'Crop', 'Date'])
    df['Min_Price'] = df['Min_Price'].fillna(df['Modal_Price'])
    df['Max_Price'] = df['Max_Price'].fillna(df['Modal_Price'])
    
    df['Price_Volatility'] = df.groupby(['Market', 'Crop'])['Modal_Price'].transform(
        lambda x: x.rolling(window=7, min_periods=1).std()
    ).fillna(0)
    
    df = df.dropna(subset=['Modal_Price'])
    target_crop = normalize_crop_name(target_crop)
    crop_df = df[df['Crop'] == target_crop].groupby('Market').tail(1).copy()
    
    # Store as a list of dicts so redis_client.set_cache can dump it properly
    set_cache(cache_key, crop_df.to_dict(orient='records'), expire=1800) 
    return crop_df
def recommend_real_markets(crop, farmer_lat, farmer_lon, transport_cost_per_km):
    try:
        expected_features = market_model.feature_names_in_
    except AttributeError:
        expected_features = market_model.get_booster().feature_names
        
    latest_data = get_real_market_features(crop)
    if latest_data.empty: return pd.DataFrame()
    
    # Pre-filter using local Haversine distance
    latest_data['straight_distance'] = latest_data.apply(
        lambda row: haversine_distance(farmer_lat, farmer_lon, row['Latitude'], row['Longitude']) 
        if pd.notnull(row.get('Latitude')) and pd.notnull(row.get('Longitude')) else 99999, 
        axis=1
    )
    
    # --- FIX 1: Only keep the top 5 closest markets (instead of 10) ---
    closest_markets = latest_data.nsmallest(5, 'straight_distance')
        
    predictions = []
    for index, row in closest_markets.iterrows():
        feature_vector = row.reindex(expected_features).to_frame().T.astype(float).fillna(0)
        pred_price = market_model.predict(feature_vector)[0]
        
        m_lat, m_lon = row.get('Latitude'), row.get('Longitude')
        
        safe_lat = float(m_lat) if pd.notnull(m_lat) else None
        safe_lon = float(m_lon) if pd.notnull(m_lon) else None
        
        # OSRM Driving Route Calculation
        if safe_lat is not None and safe_lon is not None and row['straight_distance'] != 99999:
            distance_km, travel_time = get_driving_route_osrm(farmer_lat, farmer_lon, safe_lat, safe_lon)
            
            # --- FIX 2: Add a 0.3 second pause to bypass OSRM spam filters ---
            time.sleep(0.3) 
        else:
            distance_km, travel_time = row['straight_distance'], None # Default fallback
            
        total_transport_cost = distance_km * transport_cost_per_km
        net_profit = pred_price - total_transport_cost
        
        # Format travel time
        time_str = f"{int(travel_time // 60)}h {int(travel_time % 60)}m" if travel_time else "Unknown"
        
        predictions.append({
            "Market": row['Market'],
            "State": row.get('State', ''),
            "Distance (km)": round(distance_km, 2), 
            "Travel Time": time_str,
            "Expected Price (Rs/Q)": round(float(pred_price), 2),
            "Transport Cost (Rs)": round(total_transport_cost, 2),
            "Net Profit (Rs)": round(float(net_profit), 2),
            "Confidence Score": f"{round(max(0, min(100, 100 - (distance_km * 0.05))), 1)}%",
            "market_lat": safe_lat,
            "market_lon": safe_lon 
        })
        
    results_df = pd.DataFrame(predictions)
    
    results_df = results_df.replace({pd.NA: None, float('nan'): None})
    
    return results_df.sort_values(by="Net Profit (Rs)", ascending=False).head(3)
    
def update_market_summary_cache():
    default_crops = ["Wheat", "Soyabean", "Maize", "Rice", "Cotton", "Sugarcane", "Potato", "Onion", "Tomato", "Apple"]
    summary_data = []
    
    # Reload model just in case it's missing from the global scope in background task
    model = xgb.XGBRegressor()
    model.load_model(settings.MARKET_MODEL_PATH)
    
    try:
        expected_features = model.feature_names_in_
    except AttributeError:
        expected_features = model.get_booster().feature_names
    
    for crop in default_crops:
        try:
            latest_data = get_real_market_features(crop)
            if latest_data.empty:
                continue
            
            # Predict prices for all optimal markets for this crop
            predictions = []
            for index, row in latest_data.iterrows():
                feature_vector = row.reindex(expected_features).to_frame().T.astype(float).fillna(0)
                pred_price = model.predict(feature_vector)[0]
                predictions.append(float(pred_price))
            
            # Global Average Calculation
            avg_price = sum(predictions) / len(predictions) if predictions else 0.0
            
            summary_data.append({
                "crop": crop,
                "price": round(avg_price / 100, 2), 
                "trend": "0.0%", 
                "color": "blue",
                "detail": "Global AI average across all available markets."
            })
        except Exception as e:
            print(f"Error updating cache for {crop}: {e}")
            
    set_cache("market_summary", summary_data, expire=86400)
    return summary_data