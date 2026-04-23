from fastapi import APIRouter, UploadFile, File, Request
from app.services.disease_service import predict_disease
from google import genai
from google.genai import types
import os
import json
from dotenv import load_dotenv

load_dotenv()

client = genai.Client(api_key="AIzaSyBIuHK1vVgUW4o2KqMUuLnmdVHOh_CmVjU")

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

@router.post("/api/predict")
async def predict(file: UploadFile = File(...)):
    try:
        image_data = await file.read()
        result = predict_disease(image_data)
        return result
    except Exception as e:
        print(f"Prediction Error: {e}")
        return {
            "status": "error",
            "message": f"Error processing image: {str(e)}",
            "diagnosis": "Error",
            "details": {}
        }
    

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
    location = data.get("location", "Unknown Location")
    season = data.get("season", "Unknown Season")
    target_language = LANGUAGE_MAP.get(lang_code, "English")
    
    prompt = f"""
    You are an expert agronomist AI. The farmer has just finished growing '{crop}'.
    Farmer's Location: {location}
    Current Season: {season}
    
    CRITICAL GEOGRAPHICAL INSTRUCTION: You MUST strictly tailor all recommendations to the climate, typical soil profile, and water availability of '{location}'. (e.g., Do not recommend water-heavy crops in arid regions like Rajasthan).
    
    First, provide a PROBABILISTIC soil condition analysis. Estimate the expected state of the soil after '{crop}' in {location}.
    Then, based strictly on this expected soil state and the regional viability of {location} during {season}, recommend the best NEXT crops and fertilizers.
    
    CRITICAL INSTRUCTIONS: 
    1. EXCELLENT FORMATTING: Use Markdown formatting (**bolding**). Keep descriptions crisp.
    2. Write all textual content entirely in {target_language}. Keep the exact JSON keys in English.
    
    Return ONLY a valid JSON object with this exact structure:
    {{
      "nutrient_analysis": "A brief, probabilistic explanation in {target_language} using Markdown of the expected soil condition (e.g., 'There is a high probability of Nitrogen depletion...').",
      "next_crops": [
        {{
            "title": "Crop Name in {target_language}", 
            "desc": "Why this crop survives specifically in {location} during {season} and fixes the expected soil deficit. Use Markdown.",
            "key_benefit": "Short tag in {target_language}"
        }}
      ],
      "fertilizers": [
        {{"title": "Fertilizer Name in {target_language}", "desc": "Usage instructions tailored for {location} using Markdown."}}
      ]
    }}
    """
    
    try:
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(response_mime_type="application/json"),
        )
        return json.loads(clean_json_response(response.text))
    except Exception as e:
        print(f"Recommendations Error: {e}")
        return {"nutrient_analysis": "", "next_crops": [], "fertilizers": []}


@router.post("/api/consult_ai")
async def consult_ai(request: Request):
    data = await request.json()
    current_crop = data.get("current_crop")
    query_type = data.get("query_type")
    user_query = data.get("user_query")
    chat_history = data.get("chat_history", []) 
    lang_code = data.get("language", "en")
    location = data.get("location", "Unknown Location")
    season = data.get("season", "Unknown Season")
    target_language = LANGUAGE_MAP.get(lang_code, "English")
    
    history_text = ""
    if chat_history:
        history_text = "PREVIOUS CONVERSATION HISTORY:\n"
        for msg in chat_history:
            role = "Farmer" if msg.get("role") == "user" else "AI"
            history_text += f"{role}: {msg.get('content')}\n"
        history_text += "\n"
    
    prompt = f"""
    You are an expert agronomist providing a highly specific consultation.
    Farmer's Location: {location}
    Current Season: {season}
    Previous/Current Crop: '{current_crop}'
    Query Focus: {query_type}
    
    {history_text}
    Farmer's latest message: "{user_query}"
    
    CRITICAL INSTRUCTIONS:
    1. INTENT PARSING: Determine if the farmer is asking an open-ended question ("What is best?") or proposing an idea to validate ("Can I use urea?").
    2. CRISP AND CONCISE: Maximum of 3 short bullet points.
    3. EXCELLENT FORMATTING: You MUST use Markdown. Use **bold text** for emphasis. 
    4. LOCATION/SEASON ACCURACY: Advice MUST be viable for {season} in {location}.
    5. LANGUAGE: Write natively in {target_language}. Keep JSON keys in English.
    
    Return ONLY a valid JSON object with this exact structure:
    {{
      "response_type": "success" | "warning" | "info", 
      "heading": "A short, dynamic 2-4 word heading in {target_language} (e.g., 'Safe Strategy', 'High Risk', 'Top Recommendation')",
      "feedback": "Crisp, Markdown-formatted explanation in {target_language}.",
      "better_alternative": "If their idea is sub-optimal, provide a highly specific alternative in {target_language} using Markdown. YOU MUST BRIEFLY EXPLAIN WHY this alternative is better suited for the soil, {location}, and {season}. Otherwise, return null."
    }}
    """
    
    try:
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(response_mime_type="application/json"),
        )
        return json.loads(clean_json_response(response.text))
    except Exception as e:
        print(f"Consult AI Error: {e}")
        return {"response_type": "warning", "heading": "Error", "feedback": f"Error: {str(e)}", "better_alternative": None}