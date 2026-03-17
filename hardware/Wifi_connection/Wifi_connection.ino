#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include "secrets.h"

// --- Network Configuration ---

const char* ssid = SECRET_SSID;
const char* password = SECRET_PASS;

//const char* serverName = "http://10.221.198.114:8000/api";

// Sensor Pins
#define DHTPIN 26
#define DHTTYPE DHT11
#define LDR_PIN 33
#define SOIL_MOISTURE_PIN 32
#define RAIN_SENSOR_PIN 34 
#define DEPTH_SENSOR_PIN 27

// Pump Relay Pins
#define PUMP1_PIN 13  // Irrigation Pump
#define PUMP2_PIN 14  // Tank Refill Pump

// --- Calibration Thresholds ---
// Adjust these based on your specific sensor readings (0-4095 for ESP32)
const int DRY_SOIL_THRESHOLD = 2500;   // Soil moisture value that triggers irrigation
const int WET_SOIL_THRESHOLD = 1500;   // Soil moisture value that stops irrigation
const int NO_RAIN_THRESHOLD = 2000;    // Rain sensor value indicating clear weather
const int TANK_EMPTY_THRESHOLD = 500;  // Depth level that triggers tank refill
const int TANK_FULL_THRESHOLD = 3000;  // Depth level that stops tank refill

DHT dht(DHTPIN, DHTTYPE);

void setup() {
  Serial.begin(115200);
  dht.begin();
  
  // Initialize Pump Pins
  pinMode(PUMP1_PIN, OUTPUT);
  pinMode(PUMP2_PIN, OUTPUT);
  
  // Turn pumps OFF initially. 
  // NOTE: If using active-LOW relays, change these to HIGH.
  digitalWrite(PUMP1_PIN, LOW); 
  digitalWrite(PUMP2_PIN, LOW);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  Serial.print("Connecting to WiFi");
  while(WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected to WiFi network");
}

void loop() {
  if(WiFi.status() == WL_CONNECTED){
    HTTPClient http;
    http.begin(serverName);
    http.addHeader("Content-Type", "application/json");

    // Read Sensors
    float temperature = dht.readTemperature();
    float humidity = dht.readHumidity();
    int ldrValue = analogRead(LDR_PIN);
    int soilMoisture = analogRead(SOIL_MOISTURE_PIN);
    int rainLevel = analogRead(RAIN_SENSOR_PIN);
    int depthLevel = analogRead(DEPTH_SENSOR_PIN);

    if (isnan(temperature) || isnan(humidity)) {
      temperature = 0.0;
      humidity = 0.0;
    }

    // --- Print Sensor Data to Serial ---
    Serial.println("--- Sensor Readings ---");
    Serial.print("Temp: "); Serial.print(temperature); Serial.print("C | ");
    Serial.print("Humidity: "); Serial.print(humidity); Serial.println("%");
    Serial.print("LDR: "); Serial.print(ldrValue); Serial.print(" | ");
    Serial.print("Rain Level: "); Serial.println(rainLevel);
    Serial.print("Soil Moisture: "); Serial.print(soilMoisture); Serial.print(" | ");
    Serial.print("Tank Depth: "); Serial.println(depthLevel);

    // --- Pump 1 Logic (Irrigation) ---
    // Assuming higher soil analog value = drier, and higher rain value = no rain
    if (soilMoisture > DRY_SOIL_THRESHOLD && rainLevel > NO_RAIN_THRESHOLD) {
      digitalWrite(PUMP1_PIN, HIGH);
      Serial.println("ACTION: Soil is dry and no rain. Pump 1 (Irrigation) turned ON.");
    } else if (soilMoisture <= WET_SOIL_THRESHOLD || rainLevel <= NO_RAIN_THRESHOLD) {
      digitalWrite(PUMP1_PIN, LOW);
      Serial.println("ACTION: Soil is wet or it is raining. Pump 1 (Irrigation) turned OFF.");
    }

    // --- Pump 2 Logic (Tank Refill) ---
    // Assuming higher depth analog value = deeper water
    if (depthLevel < TANK_EMPTY_THRESHOLD) {
      digitalWrite(PUMP2_PIN, HIGH);
      Serial.println("ACTION: Tank level low. Pump 2 (Refill) turned ON.");
    } else if (depthLevel >= TANK_FULL_THRESHOLD) {
      digitalWrite(PUMP2_PIN, LOW);
      Serial.println("ACTION: Tank is full. Pump 2 (Refill) turned OFF.");
    }
    Serial.println("-----------------------");

    // --- Send Data to FastAPI Server ---
    StaticJsonDocument<300> doc; // Increased size to handle new fields
    doc["temperature"] = temperature;
    doc["humidity"] = humidity;
    doc["ldr"] = ldrValue;
    doc["soil_moisture"] = soilMoisture;
    doc["rain_level"] = rainLevel;
    doc["depth_level"] = depthLevel;
    
    // Optional: Send pump status to the backend for the frontend dashboard
    doc["pump1_status"] = digitalRead(PUMP1_PIN); 
    doc["pump2_status"] = digitalRead(PUMP2_PIN);

    String requestBody;
    serializeJson(doc, requestBody);

    int httpResponseCode = http.POST(requestBody);
    
    if(httpResponseCode > 0){
      Serial.print("HTTP Response code: ");
      Serial.println(httpResponseCode);
    } else {
      Serial.print("Error code: ");
      Serial.println(httpResponseCode);
    }
    
    http.end();
  } else {
    Serial.println("WiFi Disconnected. Reconnecting...");
    WiFi.begin(ssid, password);
  }
  
  delay(10000); // 10-second delay between cycles
}