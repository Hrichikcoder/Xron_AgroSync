#include "network_sensors.h"
#include "globals.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "diagnostics.h"

// Check Backend for Manual Control Overrides
void checkBackendOverride() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(overrideUrl);
    int httpResponseCode = http.GET();
    
    if (httpResponseCode == 200) {
      String payload = http.getString();
      
      DynamicJsonDocument doc(1024); 
      DeserializationError error = deserializeJson(doc, payload);
      
      if (!error) {
        currentMode = doc["mode"].as<String>();
        manualPump1 = doc["pump1"].as<bool>();
        manualPump2 = doc["pump2"].as<bool>();
        manualShade = doc["shade"].as<bool>(); 
        manualSprinkler = doc["sprinkler"].as<bool>(); 
        

        disableSoil = doc["disable_soil_moisture"] | false; 
        disableDepth = doc["disable_depth"] | false;
        disableTemp = doc["disable_temperature"] | false;
        disableLdr = doc["disable_ldr"] | false;
        disableRain = doc["disable_rain_level"] | false;
        
        if (doc.containsKey("run_diag") && doc["run_diag"].as<bool>() == true) {
            runSelfDiagnostics(); // Execute the Serial print sequence
        }

        // ---> FETCH & SCALE THE ML TARGET VOLUME <---
        if (doc.containsKey("target_volume")) {
          float mlPrediction = doc["target_volume"].as<float>();
          
          // Define your scaling factor for the demo here
          float scaleFactor = 55.0; 
          
          // Apply the division
          targetVolume = mlPrediction * scaleFactor; 
          
          // Print the math to the Serial Monitor so you can show it off!
          Serial.print("\n[ML PREDICTION RECEIVED] Raw ML: "); 
          Serial.print(mlPrediction);
          Serial.print("mL | Scaled ( / "); 
          Serial.print(scaleFactor); 
          Serial.print(") -> Demo Target Volume: "); 
          Serial.print(targetVolume); 
          Serial.println("mL");
        }
      } else {
        Serial.print("JSON Parse Error in checkBackendOverride: ");
        Serial.println(error.c_str());
      }
    }
    http.end();
  }
}

// Helper function to read and print environmental sensors
void printEnvironmentSensors() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  int ldrValue = analogRead(LDR_PIN);
  int rainValue = analogRead(RAIN_PIN);

  Serial.println("\n--- Environment Status ---");
  if (isnan(h) || isnan(t)) {
    Serial.println("Failed to read from DHT sensor!");
  } else {
    Serial.print("Temperature: "); Serial.print(t); Serial.println("°C");
    Serial.print("Humidity: "); Serial.print(h); Serial.println("%");
  }
  
  Serial.print("LDR Light Value: "); Serial.println(ldrValue);
  Serial.print("Rain Sensor Value: "); Serial.println(rainValue);
  Serial.print("Active Target Volume: "); Serial.println(targetVolume);
  Serial.println("--------------------------\n");
}

// Function to send data to FastAPI backend
void sendSensorDataToBackend(float temp, float hum, int ldr, int cap, int rain, int depth, float flow, float flow_rate) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(backendUrl);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<256> doc;
    doc["node_id"] = "esp32_zone_1";
    doc["temperature"] = isnan(temp) ? 0.0 : temp;
    doc["humidity"] = isnan(hum) ? 0.0 : hum;
    
    doc["ldr"] = ldr;
    doc["soil_moisture"] = cap; 
    doc["rain_level"] = rain;
    doc["depth_level"] = depth;
    doc["water_flow"] = flow;
    doc["last_cycle_volume"] = lastCycleVolume;
    doc["flow_rate"] = flow_rate;
    String requestBody;
    serializeJson(doc, requestBody);

    int httpResponseCode = http.POST(requestBody);
    
    if (httpResponseCode > 0) {
      Serial.print("Sensor Data POSTed successfully. Response code: ");
      Serial.println(httpResponseCode);
    } else {
      Serial.print("Error sending sensor data. Code: ");
      Serial.println(httpResponseCode);
    }
    
    http.end();
  } else {
    Serial.println("WiFi Disconnected. Cannot send data.");
  }
}

void sendNotification(String message, String type) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(notificationUrl);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<256> doc;
    doc["message"] = message;
    doc["type"] = type;
    doc["node_id"] = "esp32_zone_1"; // Matches your Python schema default

    String requestBody;
    serializeJson(doc, requestBody);

    int httpResponseCode = http.POST(requestBody);
    
    if (httpResponseCode > 0) {
      Serial.println("[NOTIFICATION SENT] " + message);
    } else {
      Serial.print("[NOTIFICATION FAILED] HTTP Code: ");
      Serial.println(httpResponseCode);
    }
    
    http.end();
  } else {
    Serial.println("WiFi Disconnected. Cannot send notification.");
  }
}