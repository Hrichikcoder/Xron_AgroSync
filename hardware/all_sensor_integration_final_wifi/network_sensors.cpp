#include "network_sensors.h"
#include "globals.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "diagnostics.h"

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
        manualPump1 = doc["pump1"] | false;
        manualPump2 = doc["pump2"] | false;
        manualSprinkler = doc["sprinkler"] | false;
        
        disableSoil = doc["disable_soil_moisture"] | false; 
        disableDepth = doc["disable_depth"] | false;
        disableTemp = doc["disable_temperature"] | false;
        disableLdr = doc["disable_ldr"] | false;
        disableRain = doc["disable_rain_level"] | false;
        
        manualShade = doc["shade"] | false;
        shadeOverride = doc["shade_override"] | false;
      }
    }
    http.end();
  }
}

void sendSensorDataToBackend(float temp, float hum, int ldr, int cap, int rain, int depth, float flow, float flow_rate) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(backendUrl);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<512> doc;
    doc["temperature"] = temp;
    doc["humidity"] = hum;
    doc["ldr_value"] = ldr;
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
    doc["node_id"] = "esp32_zone_1"; 

    String requestBody;
    serializeJson(doc, requestBody);

    int httpResponseCode = http.POST(requestBody);
    http.end();
  }
}

void printEnvironmentSensors() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  int ldrValue = analogRead(LDR_PIN);
  int rainValue = analogRead(RAIN_PIN);

  Serial.println("\n--- Environment Data ---");
  if (isnan(h) || isnan(t)) {
    Serial.println("Failed to read from DHT sensor!");
  } else {
    Serial.print("Temp: ");
    Serial.print(t);
    Serial.print(" *C\t");
    Serial.print("Humidity: ");
    Serial.print(h);
    Serial.println(" %");
  }
  Serial.print("LDR Value: ");
  Serial.println(ldrValue);
  Serial.print("Rain Sensor Value: ");
  Serial.println(rainValue);
  Serial.println("------------------------\n");
}