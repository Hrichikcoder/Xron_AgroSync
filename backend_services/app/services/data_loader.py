import os
import glob
import pandas as pd
from app.core.config import settings

COLUMN_MAPPING = {
    'Price Date': 'Date', 'Arrival_Date': 'Date', 'time': 'Date',
    'District Name': 'District', 'Dist Name': 'District',
    'State Name': 'State', 'Market Name': 'Market',
    'Commodity': 'Crop',
    'Modal Price (Rs./Quintal)': 'Modal_Price', 'Modal_x0020_Price': 'Modal_Price',
    'Min Price (Rs./Quintal)': 'Min_Price', 'Min_x0020_Price': 'Min_Price',
    'Max Price (Rs./Quintal)': 'Max_Price', 'Max_x0020_Price': 'Max_Price'
}

def normalize_crop_name(crop_name):
    if not isinstance(crop_name, str):
        return crop_name
        
    c = crop_name.upper().strip()
    
    if "SOYA" in c: return "SOYABEAN"
    if "CORN" in c or "MAIZE" in c: return "MAIZE"
    if "RICE" in c or "PADDY" in c or "DHAN" in c: return "RICE"
    if "BRINJAL" in c or "EGGPLANT" in c: return "BRINJAL"
    if "GRAM" in c or "CHANA" in c: return "GRAM"
    if "CORIANDER" in c or "DHANIA" in c: return "CORIANDER"
    if "LENTIL" in c or "MASUR" in c: return "LENTIL"
    if "BAJRA" in c or "MILLET" in c: return "BAJRA"
    if "MUSTARD" in c or "RAPESEED" in c: return "MUSTARD"
    if "COTTON" in c: return "COTTON"
    if "CHILLI" in c: return "CHILLI"
    
    return c

def standardize_columns(df):
    df = df.rename(columns=COLUMN_MAPPING)
    
    clean_cols = {}
    for col in df.columns:
        if 'Yield' in col: clean_cols[col] = 'Yield'
        elif 'Cost of Production' in col: clean_cols[col] = 'Cost_of_Production'
        elif 'Cost of Cultivation' in col and 'A2' in col: clean_cols[col] = 'Cost_A2'
        elif 'Cost of Cultivation' in col and 'C2' in col: clean_cols[col] = 'Cost_C2'
            
    df = df.rename(columns=clean_cols)
    
    if 'Crop' in df.columns: df['Crop'] = df['Crop'].apply(normalize_crop_name)
    if 'State' in df.columns: df['State'] = df['State'].str.upper().str.strip()
    if 'District' in df.columns: df['District'] = df['District'].str.upper().str.strip()
    if 'Date' in df.columns:
        df['Date'] = pd.to_datetime(df['Date'], format='mixed', dayfirst=True, errors='coerce')
        df['Year'] = df['Date'].dt.year
        df['Month'] = df['Date'].dt.month
        
    return df

def build_data_lake(folder_path=settings.DATASET_DIR):
    all_files = glob.glob(os.path.join(folder_path, "*.csv"))
    datasets = {'core_price': [], 'weather_daily': [], 'macro_yearly': [], 'geospatial': []}
    
    for file in all_files:
        try:
            df = pd.read_csv(file, low_memory=False)
            df = standardize_columns(df)
            cols = df.columns.tolist()
            if 'Modal_Price' in cols and 'Date' in cols: datasets['core_price'].append(df)
            elif 'tavg' in cols and 'Date' in cols: datasets['weather_daily'].append(df)
            elif 'Yield' in cols or 'Cost_of_Production' in cols: datasets['macro_yearly'].append(df)
            elif 'Latitude' in cols or 'Longitude' in cols: datasets['geospatial'].append(df)
        except Exception:
            continue
            
    return datasets

def merge_pipeline(datasets):
    if not datasets['core_price']: return pd.DataFrame()
        
    main_df = pd.concat(datasets['core_price'], ignore_index=True)
    main_df = main_df.dropna(subset=['Date', 'Modal_Price', 'Crop', 'Market'])
    
    if datasets['weather_daily']:
        weather_df = pd.concat(datasets['weather_daily'], ignore_index=True)
        weather_df = weather_df.groupby(['Date']).mean(numeric_only=True).reset_index()
        main_df = main_df.merge(weather_df, on='Date', how='left')
        
    for macro_df in datasets['macro_yearly']:
        merge_keys = [k for k in ['Crop', 'State'] if k in macro_df.columns and k in main_df.columns]
        if merge_keys:
            macro_df = macro_df.groupby(merge_keys).mean(numeric_only=True).reset_index()
            main_df = main_df.merge(macro_df, on=merge_keys, how='left')
            
    if datasets['geospatial']:
        geo_df = pd.concat(datasets['geospatial'], ignore_index=True)
        geo_df = geo_df[['Market', 'Latitude', 'Longitude']].drop_duplicates(subset=['Market'])
        main_df = main_df.merge(geo_df, on='Market', how='left')
            
    return main_df