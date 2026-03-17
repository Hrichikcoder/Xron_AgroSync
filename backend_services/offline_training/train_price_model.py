import sys
import os
import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

# Add project root to path so we can import the app modules for offline training
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.services.data_loader import build_data_lake, merge_pipeline
from app.core.config import settings

def engineer_time_series_features(df):
    print("Engineering features (Lags, Volatility, Spread)...")
    df = df.sort_values(by=['State', 'District', 'Market', 'Crop', 'Date'])
    
    df['Min_Price'] = df['Min_Price'].fillna(df['Modal_Price'])
    df['Max_Price'] = df['Max_Price'].fillna(df['Modal_Price'])
    df['Price_Spread'] = df['Max_Price'] - df['Min_Price']
    
    df['Price_Volatility'] = df.groupby(['Market', 'Crop'])['Modal_Price'].transform(
        lambda x: x.rolling(window=7, min_periods=1).std()
    ).fillna(0)
    
    df['Lag_7'] = df.groupby(['Market', 'Crop'])['Modal_Price'].shift(7)
    df['Lag_30'] = df.groupby(['Market', 'Crop'])['Modal_Price'].shift(30)
    
    df.dropna(subset=['Lag_7', 'Lag_30', 'Modal_Price'], inplace=True)
    return df

def train_xgboost_gpu(df):
    print(f"Data shape after feature engineering: {df.shape}")
    print("Pushing data to RTX 5060 for training...")
    
    df = df.sort_values(by=['Date'])
    numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
    if 'Modal_Price' in numeric_cols: numeric_cols.remove('Modal_Price')
    if 'Sl no.' in numeric_cols: numeric_cols.remove('Sl no.')
        
    features = numeric_cols
    target = 'Modal_Price'
    
    split_idx = int(len(df) * 0.8)
    train_df = df.iloc[:split_idx]
    test_df = df.iloc[split_idx:]
    
    X_train, y_train = train_df[features].fillna(0), train_df[target]
    X_test, y_test = test_df[features].fillna(0), test_df[target]
    
    model = xgb.XGBRegressor(
        tree_method="hist", device="cuda", n_estimators=500,
        learning_rate=0.05, max_depth=8, subsample=0.8
    )
    model.fit(X_train, y_train)
    
    print("Evaluating Model...")
    predictions = model.predict(X_test)
    metrics = {
        "MAE": mean_absolute_error(y_test, predictions),
        "RMSE": np.sqrt(mean_squared_error(y_test, predictions)),
        "R2": r2_score(y_test, predictions)
    }
    
    # Save directly to the new ml_models folder
    model.save_model(settings.MARKET_MODEL_PATH)
    print(f"Model successfully saved to {settings.MARKET_MODEL_PATH}")
    
    return model, metrics

if __name__ == "__main__":
    print("Loading all datasets from the Data Lake...")
    lake = build_data_lake(settings.DATASET_DIR)
    raw_data = merge_pipeline(lake)
    processed_data = engineer_time_series_features(raw_data)
    trained_model, eval_metrics = train_xgboost_gpu(processed_data)
    
    print("\n🔥 --- RTX 5060 Training Complete --- 🔥")
    for metric, value in eval_metrics.items(): print(f"{metric}: {value:.4f}")