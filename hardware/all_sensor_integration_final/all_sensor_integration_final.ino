#include <DHT.h> // *** NEW: Make sure you have the "DHT sensor library" by Adafruit installed in the IDE ***

// Define Pin Connections
const int PUMP1_PIN = 13;
const int PUMP2_PIN = 14;
const int DEPTH_SENSOR_PIN = 34;
const int CAP_SENSOR_PIN = 32; 
const int FLOW_SENSOR_PIN = 27; 

// *** NEW: Environmental Sensor Pins ***
#define DHTPIN 26
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

const int LDR_PIN = 33;
const int RAIN_PIN = 35;

// System State Variables
int currentPhase = 1; 
bool pump1Running = false;        // Tracks if Pump 1 is currently active

// Volume Tracking Variables
float targetVolume = 50.0;         // *** CHANGED: Removed 'const' so we can increase it later ***
float currentVolume = 0.0;         // Tracks how much has been delivered so far
bool targetVolumeReached = false;  // Flag for when target is met

// Flow Sensor Interrupt Variables
volatile unsigned long pulseCount = 0; 
float mlPerPulse = 2.22; 

// Timers
unsigned long lastPrintTime = 0;
const unsigned long printInterval = 1000; // Print status every 1 second

// *** NEW: Timer for Environmental Sensors ***
unsigned long lastEnvPrintTime = 0;
const unsigned long envPrintInterval = 30000; // 30 seconds (in milliseconds)

// Timer for Pump 2
unsigned long pump2StartTime = 0;
const unsigned long pump2RunDuration = 18000; // 18 seconds (in milliseconds)

// Cooldown Timer for Pump 1
unsigned long volumeReachedTime = 0;
const unsigned long restartDelay = 10000; // 10 seconds cooldown between batches

// Interrupt Service Routine (ISR) for the Flow Sensor
void IRAM_ATTR countPulse() {
  pulseCount++;
}

// *** NEW: Helper function to read and print environmental sensors ***
void printEnvironmentSensors() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  int ldrValue = analogRead(LDR_PIN);
  int rainValue = analogRead(RAIN_PIN);

  Serial.println("\n--- Environment Status ---");
  
  if (isnan(h) || isnan(t)) {
    Serial.println("Failed to read from DHT sensor! Check wiring.");
  } else {
    Serial.print("Temperature: "); Serial.print(t); Serial.print("°C | ");
    Serial.print("Humidity: "); Serial.print(h); Serial.println("%");
  }
  
  Serial.print("LDR Light Value: "); Serial.println(ldrValue);
  Serial.print("Rain Sensor Value: "); Serial.println(rainValue);
  Serial.print("Current Target Volume: "); Serial.println(targetVolume);
  Serial.println("--------------------------\n");
}

void setup() {
  Serial.begin(115200); 
  
  Serial.println("\n=====================================");
  Serial.println("System Startup Initialized...");
  
  Serial.println("Step 1: Configuring Pins...");
  pinMode(PUMP1_PIN, OUTPUT);
  pinMode(PUMP2_PIN, OUTPUT);
  pinMode(DEPTH_SENSOR_PIN, INPUT);
  pinMode(CAP_SENSOR_PIN, INPUT); 
  
  // Setup Flow Sensor Pin and attach the Interrupt
  pinMode(FLOW_SENSOR_PIN, INPUT_PULLUP); 
  attachInterrupt(digitalPinToInterrupt(FLOW_SENSOR_PIN), countPulse, FALLING);
  
  // *** NEW: Initialize Environmental Sensors ***
  dht.begin();
  pinMode(LDR_PIN, INPUT);
  pinMode(RAIN_PIN, INPUT);

  // Forcing Pumps to Initial OFF State (Active-LOW: HIGH is OFF)
  Serial.println("Step 2: Forcing Pumps to Initial OFF State...");
  digitalWrite(PUMP1_PIN, HIGH); 
  digitalWrite(PUMP2_PIN, HIGH);
  
  Serial.println("Startup Complete!");
  
  // *** NEW: Print sensors on startup ***
  printEnvironmentSensors();
  lastEnvPrintTime = millis(); // Initialize the 30-second timer
  
  Serial.println("Beginning Phase 1 -> Continuously monitoring Cap Sensor.");
  Serial.println("=====================================\n");
}

void loop() {
  // Continuously read sensors
  int depthValue = analogRead(DEPTH_SENSOR_PIN);
  int capValue = analogRead(CAP_SENSOR_PIN);
  unsigned long currentMillis = millis();
  
  // *** NEW: Print Environmental Sensors every 30 seconds continuously ***
  if (currentMillis - lastEnvPrintTime >= envPrintInterval) {
    printEnvironmentSensors();
    lastEnvPrintTime = currentMillis;
  }
  
  // --- PHASE 1: Managing Pump 1 & Monitoring ---
  if (currentPhase == 1) {
    
    // 1. URGENT CHECK: Emergency Stop (Depth <= 0)
    if (depthValue <= 0) {
      currentPhase = 2; // Move to Phase 2
      pump1Running = false;
      
      digitalWrite(PUMP1_PIN, HIGH); // Immediate OFF for Pump 1 (Active-LOW)
      digitalWrite(PUMP2_PIN, LOW);  // Immediate ON for Pump 2 (Active-LOW)
      
      pump2StartTime = millis();     // Record the exact time Pump 2 started
      
      Serial.println("\n*** URGENT NOTIFICATION: Depth reached 0! ***");
      Serial.println("Emergency Stop: Pump 1");
      Serial.println("Starting Pump 2...");
      Serial.println("Beginning Phase 2 -> Goal: Run Pump 2 for 18 seconds\n");
      return; // Skip the rest of this loop iteration to enforce immediate action
    }

    // 2. NORMAL SHUTOFF CHECK: Target Volume Reached
    if (pump1Running && !targetVolumeReached && (currentVolume >= targetVolume)) {
      pump1Running = false;
      targetVolumeReached = true;
      digitalWrite(PUMP1_PIN, HIGH); // Turn OFF Pump 1
      
      volumeReachedTime = millis();  // Record the time the batch finished
      
      Serial.println("\n*** NOTIFICATION: Target volume delivered. Pump 1 OFF. ***");
      Serial.println("*** Starting 10-second cooldown before allowing restart... ***\n");
    }

    // 3. COOLDOWN & RESET CHECK
    // If the pump is off and we are waiting after a finished batch
    if (!pump1Running && targetVolumeReached) {
      if (currentMillis - volumeReachedTime >= restartDelay) {
        targetVolumeReached = false; // Un-lock the start check
        currentVolume = 0.0;         // Reset the flow tracker
        pulseCount = 0;              // Reset the physical hardware pulse counter
        
        // *** MOVED: Cycle completed logic (Increases volume after irrigation finishes) ***
        targetVolume += 10.0; 
        
        Serial.println("\n=====================================");
        Serial.println("Irrigation cycle completed successfully.");
        Serial.println("System ready for next batch.");
        Serial.println("=====================================\n");
        
        printEnvironmentSensors(); // Print the new target and sensor data
      }
    }

    // 4. CONTINUOUS START CHECK
    // If Pump 1 is OFF, instantly check if conditions are met to start it
    if (!pump1Running) {
      if (capValue > 2000 && !targetVolumeReached && depthValue > 0) {
        pump1Running = true;
        digitalWrite(PUMP1_PIN, LOW); // Turn ON Pump 1 (Active-LOW)
        Serial.println("\n*** EVENT: Cap value > 2000. Pump 1 STARTED. ***\n");
      }
    }

    // 5. REAL FLOW COUNTER & PRINT STATUS (Every 1 second)
    if (currentMillis - lastPrintTime >= printInterval) {
      
      // Calculate real volume based on hardware pulses
      currentVolume = pulseCount * mlPerPulse;

      float volumeLeft = targetVolume - currentVolume;
      if (volumeLeft < 0) volumeLeft = 0; 

      // Print the updated status string
      Serial.print("STEP: Phase 1 | Pump 1: ");
      Serial.print(pump1Running ? "ON " : "OFF");
      Serial.print(" | Depth: ");
      Serial.print(depthValue);
      Serial.print(" | Cap: ");
      Serial.print(capValue);
      Serial.print(" | Delivered: ");
      Serial.print(currentVolume);
      Serial.print(" | Left: ");
      
      // Show "COOLDOWN" in the print instead of 0 if we are waiting
      if (!pump1Running && targetVolumeReached) {
        int cooldownLeft = (restartDelay - (currentMillis - volumeReachedTime)) / 1000;
        Serial.print("COOLDOWN (");
        Serial.print(cooldownLeft);
        Serial.println("s)");
      } else {
        Serial.println(volumeLeft);
      }
      
      lastPrintTime = currentMillis;
    }
  }
  
  // --- PHASE 2: Pump 2 running (Filling) ---
  else if (currentPhase == 2) {
    // Ensure Pump 1 stays OFF and Pump 2 stays ON
    digitalWrite(PUMP1_PIN, HIGH); 
    digitalWrite(PUMP2_PIN, LOW);   
    
    // Print status every 1 second
    if (currentMillis - lastPrintTime >= printInterval) {
      int secondsRemaining = (pump2RunDuration - (currentMillis - pump2StartTime)) / 1000;
      
      Serial.print("STEP: Phase 2 Active | Pump 1: OFF | Pump 2: ON  | Time Remaining: ");
      Serial.print(secondsRemaining);
      Serial.println("s");
      lastPrintTime = currentMillis;
    }
    
    // Check if 18 seconds have passed
    if (currentMillis - pump2StartTime >= pump2RunDuration) {
      Serial.println("\n*** EVENT: 18 seconds elapsed! ***");
      Serial.println("Shutting down Pump 2...");
      
      digitalWrite(PUMP1_PIN, HIGH);  // Ensure Pump 1 is OFF
      digitalWrite(PUMP2_PIN, HIGH);  // Turn OFF Pump 2
      
      // RESET SYSTEM FOR CONTINUOUS OPERATION
      currentPhase = 1; 
      targetVolumeReached = false; 
      currentVolume = 0.0;         
      pulseCount = 0;              
      
      Serial.println("\n=====================================");
      Serial.println("Refill phase completed.");
      Serial.println("System resetting to Phase 1...");
      Serial.println("=====================================\n");
    }
  }

  delay(50); // Small delay for overall loop stability
}