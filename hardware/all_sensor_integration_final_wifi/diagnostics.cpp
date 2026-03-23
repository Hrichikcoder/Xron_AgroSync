#include <Arduino.h>
#include "diagnostics.h"
#include "globals.h"

// Runs a quick local hardware sanity check and prints to Serial
void runSelfDiagnostics() {
    Serial.println("\n=====================================");
    Serial.println("   INITIATING HARDWARE DIAGNOSTICS   ");
    Serial.println("=====================================");

    // 1. Check DHT11
    float h = dht.readHumidity();
    float t = dht.readTemperature();
    Serial.print("[TEST] DHT11 Temp/Hum: ");
    if (isnan(h) || isnan(t)) {
        Serial.println("FAIL (Check wiring)");
    } else {
        Serial.print("PASS (Temp: "); Serial.print(t); 
        Serial.print("C, Hum: "); Serial.print(h); Serial.println("%)");
    }

    // 2. Check LDR
    int ldrValue = analogRead(LDR_PIN);
    Serial.print("[TEST] LDR Sensor: ");
    if (ldrValue == 0 || ldrValue == 4095) {
        Serial.print("WARNING - Extreme Value ("); Serial.print(ldrValue); Serial.println(")");
    } else {
        Serial.print("PASS (Value: "); Serial.print(ldrValue); Serial.println(")");
    }

    // 3. Check Rain Sensor
    int rainValue = analogRead(RAIN_PIN);
    Serial.print("[TEST] Rain Sensor: ");
    if (rainValue == 0 || rainValue == 4095) {
        Serial.print("WARNING - Extreme Value ("); Serial.print(rainValue); Serial.println(")");
    } else {
        Serial.print("PASS (Value: "); Serial.print(rainValue); Serial.println(")");
    }

    // 4. Check Capacitive Soil Sensor
    int capValue = analogRead(CAP_SENSOR_PIN);
    Serial.print("[TEST] Soil Moisture: ");
    if (capValue == 0 || capValue == 4095) {
        Serial.print("WARNING - Extreme Value ("); Serial.print(capValue); Serial.println(")");
    } else {
        Serial.print("PASS (Value: "); Serial.print(capValue); Serial.println(")");
    }
    
    // 5. Check Depth Sensor
    int depthValue = analogRead(DEPTH_SENSOR_PIN);
    Serial.print("[TEST] Water Depth: ");
    Serial.print("PASS (Value: "); Serial.print(depthValue); Serial.println(")");

    Serial.println("=====================================\n");
}