// Define Pin Connections
const int PUMP1_PIN = 13;
const int PUMP2_PIN = 14;
const int DEPTH_SENSOR_PIN = 34;
const int CAP_SENSOR_PIN = 32; 
const int FLOW_SENSOR_PIN = 27; // *** NEW: Real Flow Sensor Pin ***

// System State Variables
int currentPhase = 1; 
bool pump1Running = false;        // Tracks if Pump 1 is currently active

// Volume Tracking Variables
const float TARGET_VOLUME = 50.0;  // Your target volume (e.g., in milliliters)
float currentVolume = 0.0;         // Tracks how much has been delivered so far
bool targetVolumeReached = false;  // Flag for when target is met

// *** NEW: Flow Sensor Interrupt Variables ***
volatile unsigned long pulseCount = 0; // 'volatile' tells the ESP32 this can change at any millisecond
float mlPerPulse = 2.22; // Calibration: Standard YF-S201 flow sensor is ~2.22 mL per pulse. Adjust as needed!

// Timers
unsigned long lastPrintTime = 0;
const unsigned long printInterval = 1000; // Print status every 1 second

// Timer for Pump 2
unsigned long pump2StartTime = 0;
const unsigned long pump2RunDuration = 18000; // 18 seconds (in milliseconds)

// Cooldown Timer for Pump 1
unsigned long volumeReachedTime = 0;
const unsigned long restartDelay = 10000; // 10 seconds cooldown between batches

// *** NEW: Interrupt Service Routine (ISR) for the Flow Sensor ***
// The ESP32 requires "IRAM_ATTR" to run this function in RAM for maximum speed
void IRAM_ATTR countPulse() {
  pulseCount++;
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
  
  // *** NEW: Setup Flow Sensor Pin and attach the Interrupt ***
  pinMode(FLOW_SENSOR_PIN, INPUT_PULLUP); // PULLUP helps prevent false triggers from electrical noise
  attachInterrupt(digitalPinToInterrupt(FLOW_SENSOR_PIN), countPulse, FALLING);
  
  // Forcing Pumps to Initial OFF State (Active-LOW: HIGH is OFF)
  Serial.println("Step 2: Forcing Pumps to Initial OFF State...");
  digitalWrite(PUMP1_PIN, HIGH); 
  digitalWrite(PUMP2_PIN, HIGH);
  
  Serial.println("Startup Complete!");
  Serial.println("Beginning Phase 1 -> Continuously monitoring Cap Sensor.");
  Serial.println("=====================================\n");
}

void loop() {
  // Continuously read sensors
  int depthValue = analogRead(DEPTH_SENSOR_PIN);
  int capValue = analogRead(CAP_SENSOR_PIN);
  unsigned long currentMillis = millis();
  
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
    // *** NEW: Only evaluate this if it hasn't already been triggered ***
    if (pump1Running && !targetVolumeReached && (currentVolume >= TARGET_VOLUME)) {
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
        pulseCount = 0;              // *** NEW: Reset the physical hardware pulse counter ***
        Serial.println("\n*** EVENT: 10-second cooldown finished. System ready for next batch. ***\n");
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
      
      // *** NEW: Calculate real volume based on hardware pulses ***
      currentVolume = pulseCount * mlPerPulse;

      // Calculate remaining volume
      float volumeLeft = TARGET_VOLUME - currentVolume;
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
      targetVolumeReached = false; // Reset the flow sensor flag for the next cycle
      currentVolume = 0.0;         // Reset the volume counter for the next cycle
      pulseCount = 0;              // *** NEW: Reset hardware pulses after phase 2 as well ***
      
      Serial.println("\n=====================================");
      Serial.println("Cycle completed successfully.");
      Serial.println("System resetting to Phase 1...");
      Serial.println("=====================================\n");
    }
  }

  delay(50); // Small delay for overall loop stability
}