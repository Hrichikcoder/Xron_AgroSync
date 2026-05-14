# Run this once manually
from app.services.data_loader import build_data_lake, merge_pipeline
datasets = build_data_lake()
final_df = merge_pipeline(datasets)
final_df.to_parquet("app/data/optimized_market_data.parquet", engine="pyarrow")