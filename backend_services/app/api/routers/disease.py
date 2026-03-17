from fastapi import APIRouter, UploadFile, File, Request
from app.services.disease_service import predict_disease
from google import genai
from google.genai import types
import os
import json
from dotenv import load_dotenv

load_dotenv()

client = genai.Client(api_key="AIzaSyCHiVS5oAvAomhjNQ7f_LSkiYiiil3NtoI")

router = APIRouter(tags=["Disease Prediction"])

def clean_json_response(text: str) -> str:
    text = text.strip()
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()

@router.post("/predict")
async def predict(file: UploadFile = File(...)):
    try:
        image_data = await file.read()
        clean_diagnosis, details = predict_disease(image_data)

        return {
            "diagnosis": clean_diagnosis,
            "details": details
        }
    except Exception as e:
        print(f"Prediction Error: {e}")
        return {"diagnosis": f"Error processing image: {str(e)}", "details": {}}
    

# Add this mapping dictionary near the top of your file (under your imports)
LANGUAGE_MAP = {
    'en': 'English',
    'hi': 'Hindi',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'mr': 'Marathi',
    'gu': 'Gujarati',
    'kn': 'Kannada'
}

@router.post("/api/recommendations")
async def get_recommendations(request: Request):
    data = await request.json()
    crop = data.get("current_crop", "Unknown")
    lang_code = data.get("language", "en")
    target_language = LANGUAGE_MAP.get(lang_code, "English")
    
    prompt = f"""
    You are an expert agronomist AI. The farmer has just finished growing '{crop}'.
    First, analyze how '{crop}' affects soil nutrients (what it heavily depletes and what it leaves behind or fixes).
    Then, based on this specific nutrient profile, recommend the best NEXT crops for rotation that will naturally replenish the soil, along with a fertilizer strategy.
    
    CRITICAL LANGUAGE INSTRUCTION: You must write all textual content (descriptions, titles, analysis) entirely in {target_language}. Keep the exact JSON keys in English, but translate all values into {target_language}.
    
    Return ONLY a valid JSON object with this exact structure:
    {{
      "nutrient_analysis": "A brief, 2-sentence explanation in {target_language} of how '{crop}' impacted the soil.",
      "next_crops": [
        {{
            "title": "Crop Name in {target_language}", 
            "desc": "How this crop interacts with the soil left behind, written in {target_language}.",
            "key_benefit": "Short tag in {target_language} (e.g., 'Fixes Nitrogen')"
        }}
      ],
      "fertilizers": [
        {{"title": "Fertilizer Name in {target_language}", "desc": "Usage instructions in {target_language}"}}
      ]
    }}
    """
    
    try:
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
            ),
        )
        cleaned_text = clean_json_response(response.text)
        return json.loads(cleaned_text)
    except Exception as e:
        print(f"Recommendations Error: {e}")
        return {"nutrient_analysis": "", "next_crops": [], "fertilizers": []}


@router.post("/api/consult_ai")
async def consult_ai(request: Request):
    import datetime
    data = await request.json()
    current_crop = data.get("current_crop")
    query_type = data.get("query_type")
    user_query = data.get("user_query")
    lang_code = data.get("language", "en")
    target_language = LANGUAGE_MAP.get(lang_code, "English")
    
    current_month = datetime.datetime.now().strftime("%B")
    
    prompt = f"""
    You are an expert agronomist and soil scientist providing a highly specific, scientific consultation.
    Current Month: {current_month}
    Previous/Current Crop: '{current_crop}'
    Farmer's proposed idea: "{user_query}"
    Query Focus: {query_type}
    
    CRITICAL INSTRUCTIONS TO AVOID GENERIC RESPONSES:
    1. NO FILLER: Do not start with generic phrases. Dive immediately into the science.
    2. CHEMICAL SPECIFICITY: Explicitly name the exact nutrients that '{current_crop}' depleted from the soil, and state EXACTLY how the proposed crop/fertilizer interacts with that deficit.
    3. BIOLOGICAL SPECIFICITY: Name specific pests or diseases that share a host bridge.
    4. SEASONAL ACCURACY: Evaluate if the proposed idea is viable right now given that it is {current_month}.
    5. LANGUAGE: You MUST write your entire response (feedback and better_alternative) natively in {target_language}. Keep the JSON keys in English, but all values must be in {target_language}.
    
    Return ONLY a valid JSON object with this exact structure:
    {{
      "is_good": true or false,
      "feedback": "Direct, hyper-specific explanation in {target_language} focusing on exact soil chemistry, nutrient transfer, pest cycles, and seasonal timing. Use markdown formatting.",
      "better_alternative": "A highly specific, data-backed alternative crop or exact fertilizer formulation in {target_language} if their idea is sub-optimal. Otherwise, return null."
    }}
    """
    
    try:
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
            ),
        )
        cleaned_text = clean_json_response(response.text)
        return json.loads(cleaned_text)
    except Exception as e:
        print(f"Consult AI Error: {e}")
        return {
            "is_good": False,
            "feedback": f"The AI service is currently unavailable. Error: {str(e)}",
            "better_alternative": None
        }