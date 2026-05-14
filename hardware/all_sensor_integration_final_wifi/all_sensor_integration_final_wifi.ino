#include <WiFi.h>
#include <ESP32Servo.h>
#include "globals.h"
#include "network_sensors.h"

bool manualShade = false;
bool lastShadeState = false;
bool shadeOverride = false; 
Servo shadeServo;

portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;

void IRAM_ATTR countPulse() {
  portENTER_CRITICAL_ISR(&mux);
  pulseCount++;
  portEXIT_CRITICAL_ISR(&mux);
}

void setup() {
  Serial.begin(115200); 
  
  Serial.println("\n=====================================");
  Serial.println("System Startup Initialized...");
  
  Serial.println("Step 1: Configuring Pins...");
  pinMode(PUMP1_PIN, OUTPUT);
  pinMode(PUMP2_PIN, OUTPUT);
  pinMode(SPRINKLER_PIN, OUTPUT);
  pinMode(DEPTH_SENSOR_PIN, INPUT);
  pinMode(CAP_SENSOR_PIN, INPUT); 
  
  pinMode(FLOW_SENSOR_PIN, INPUT_PULLUP); 
  attachInterrupt(digitalPinToInterrupt(FLOW_SENSOR_PIN), countPulse, FALLING);

  dht.begin();
  pinMode(LDR_PIN, INPUT);
  pinMode(RAIN_PIN, INPUT);

  shadeServo.setPeriodHertz(50);
  shadeServo.attach(SERVO_PIN, 500, 2400);
  shadeServo.write(0);

  Serial.println("Step 2: Forcing Pumps to Initial OFF State...");
  digitalWrite(PUMP1_PIN, HIGH); 
  digitalWrite(PUMP2_PIN, HIGH);
  digitalWrite(SPRINKLER_PIN, HIGH);

  Serial.println("Step 3: Connecting to WiFi...");
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\nWiFi Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  Serial.println("Startup Complete!");
  printEnvironmentSensors();
  lastEnvPrintTime = millis();
  lastOverrideCheck = millis();
  lastFlowMillis = millis(); 
  
  Serial.println("Beginning Operations...");
  Serial.println("=====================================\n");
}

void loop() {
  unsigned long currentMillis = millis();

  if (currentMillis - lastFlowMillis >= 1000) {
    unsigned long currentPulses = 0;
    portENTER_CRITICAL(&mux);
    currentPulses = pulseCount;
    pulseCount = 0;
    portEXIT_CRITICAL(&mux);

    float elapsedSeconds = (currentMillis - lastFlowMillis) / 1000.0;
    float frequency = currentPulses / elapsedSeconds;
    currentFlowRate = frequency / calibrationFactor;

    float mlPerPulse = 1000.0 / (calibrationFactor * 60.0);
    float volumeAdded = currentPulses * mlPerPulse;

    currentVolume += volumeAdded;
    lastFlowMillis = currentMillis; 
  }

  int depthValue = analogRead(DEPTH_SENSOR_PIN);
  int capValue = analogRead(CAP_SENSOR_PIN);
  
  if (disableSoil) capValue = 1500; 
  if (disableDepth) depthValue = 2000;

  if (currentMillis - lastOverrideCheck >= overrideInterval) {
    checkBackendOverride();
    lastOverrideCheck = currentMillis;
  }
  
  int currentLdr = analogRead(LDR_PIN);
  int currentRain = analogRead(RAIN_PIN);
  if (disableLdr) currentLdr = 1000;
  if (disableRain) currentRain = 4095;

  bool desiredShade = lastShadeState;

  if (!shadeOverride) {
    if (currentRain < 1800 || currentLdr > 2200) {
      desiredShade = true;
    } else if (currentRain > 2200 && currentLdr < 1800) {
      desiredShade = false;
    }
  } else {
    desiredShade = manualShade;
  }

  if (desiredShade != lastShadeState) {
    if (desiredShade) {
      for (int pos = 0; pos <= 180; pos += 2) { 
        shadeServo.write(pos);
        delay(5); 
      }
      Serial.println("\n>>> ACTION: Farm Shade DEPLOYED <<<");
    } else {
      for (int pos = 180; pos >= 0; pos -= 2) { 
        shadeServo.write(pos);
        delay(5); 
      }
      Serial.println("\n>>> ACTION: Farm Shade RETRACTED <<<");
    }
    lastShadeState = desiredShade;
  }

  digitalWrite(SPRINKLER_PIN, manualSprinkler ? LOW : HIGH);

  if (currentMillis - lastEnvPrintTime >= envPrintInterval) {
    printEnvironmentSensors();
    float h = dht.readHumidity();
    float t = dht.readTemperature();
    int ldrValue = analogRead(LDR_PIN);
    int rainValue = analogRead(RAIN_PIN);

    if (disableTemp) {
       t = 25.0;
       h = 50.0;
    }
    if (disableLdr) ldrValue = 1000;
    if (disableRain) rainValue = 4095;

    sendSensorDataToBackend(t, h, ldrValue, capValue, rainValue, depthValue, currentVolume, currentFlowRate);
    lastEnvPrintTime = currentMillis;
  }
  
  if (currentMode == "manual") {
     digitalWrite(PUMP1_PIN, manualPump1 ? LOW : HIGH);
     digitalWrite(PUMP2_PIN, manualPump2 ? LOW : HIGH);
     
     if (currentMillis - lastPrintTime >= printInterval) {
        Serial.print("MODE: MANUAL | P1: ");
        Serial.print(manualPump1 ? "ON " : "OFF");
        Serial.print(" | P2: "); Serial.print(manualPump2 ? "ON " : "OFF");
        Serial.print(" | SPRK: ");
        Serial.print(manualSprinkler ? "ON " : "OFF"); 
        Serial.print(" | Delivered Vol: "); Serial.println(currentVolume);
        lastPrintTime = currentMillis;
     }
     delay(50);
     return; 
  }

  if (currentPhase == 1) {
    if (depthValue <= 0) {
      currentPhase = 2;
      pump1Running = false;
      digitalWrite(PUMP1_PIN, HIGH);
      digitalWrite(PUMP2_PIN, LOW);
      pump2StartTime = millis();
      Serial.println("\n*** URGENT NOTIFICATION: Depth reached 0! ***");
      sendNotification("URGENT: Water Tank Depth reached 0! Refill Pump Started.", "alert");
      Serial.println("Emergency Stop: Pump 1 | Starting Pump 2...");
      return;
    }

    if (pump1Running && !targetVolumeReached && (currentVolume >= targetVolume)) {
      pump1Running = false;
      targetVolumeReached = true;
      digitalWrite(PUMP1_PIN, HIGH); 
      volumeReachedTime = millis();
      Serial.println("\n*** NOTIFICATION: Target volume delivered. Pump 1 OFF. ***");
    }

    if (!pump1Running && targetVolumeReached) {
      if (currentMillis - volumeReachedTime >= restartDelay) {
        lastCycleVolume = currentVolume;
        targetVolumeReached = false;
        currentVolume = 0.0;
        
        Serial.println("\n=====================================");
        Serial.println("Irrigation cycle completed successfully.");
        sendNotification("Irrigation cycle completed successfully.", "info");
        Serial.println("System awaiting next sensor trigger...");
        Serial.println("=====================================\n");
      }
    }

    if (!pump1Running) {
      if (capValue > 2000 && !targetVolumeReached && depthValue > 0) {
        pump1Running = true;
        digitalWrite(PUMP1_PIN, LOW); 
        Serial.println("\n*** EVENT: Cap value > 2000. Pump 1 STARTED. ***\n");
      }
    }

    if (currentMillis - lastPrintTime >= printInterval) {
      float volumeLeft = targetVolume - currentVolume;
      if (volumeLeft < 0) volumeLeft = 0;
      Serial.print("STEP: Phase 1 | Pump 1: ");
      Serial.print(pump1Running ? "ON " : "OFF");
      Serial.print(" | Depth: "); Serial.print(depthValue);
      Serial.print(" | Cap: "); Serial.print(capValue);
      Serial.print(" | Delivered: ");
      Serial.print(currentVolume);
      Serial.print(" | Target: ");
      Serial.print(targetVolume);
      Serial.print(" | Left: ");
      
      if (!pump1Running && targetVolumeReached) {
        int cooldownLeft = (restartDelay - (currentMillis - volumeReachedTime)) / 1000;
        Serial.print("COOLDOWN ("); Serial.print(cooldownLeft); Serial.println("s)");
      } else {
        Serial.println(volumeLeft);
      }
      lastPrintTime = currentMillis;
    }
  }
  else if (currentPhase == 2) {
    digitalWrite(PUMP1_PIN, HIGH);
    digitalWrite(PUMP2_PIN, LOW);   
    
    if (currentMillis - lastPrintTime >= printInterval) {
      int secondsRemaining = (pump2RunDuration - (currentMillis - pump2StartTime)) / 1000;
      Serial.print("STEP: Phase 2 Active | Pump 1: OFF | Pump 2: ON  | Time Remaining: ");
      Serial.print(secondsRemaining);
      Serial.println("s");
      lastPrintTime = currentMillis;
    }
    
    if (currentMillis - pump2StartTime >= pump2RunDuration) {
      digitalWrite(PUMP1_PIN, HIGH);
      digitalWrite(PUMP2_PIN, HIGH);
      
      currentPhase = 1;
      targetVolumeReached = false; 
      currentVolume = 0.0;     
      
      Serial.println("\n=====================================");
      Serial.println("Refill phase completed. System resetting to Phase 1.");
    }
  }

  delay(50); 
}