// Define Pin Connections
const int PUMP1_PIN = 13;
const int PUMP2_PIN = 14;
const int DEPTH_SENSOR_PIN = 34;

// Variables to track the current state of the system
int currentPhase = 1; 
bool jobCompleted = false;

// Variable to control how often Serial messages print (in milliseconds)
unsigned long lastPrintTime = 0;
const unsigned long printInterval = 1000; // Print status every 1 second

void setup() {
  // Initialize Serial Monitor
  Serial.begin(115200); // Use 115200 baud rate for ESP32
  
  // Detailed Startup Messages
  Serial.println("\n=====================================");
  Serial.println("System Startup Initialized...");
  
  Serial.println("Step 1: Configuring Pins...");
  pinMode(PUMP1_PIN, OUTPUT);
  pinMode(PUMP2_PIN, OUTPUT);
  pinMode(DEPTH_SENSOR_PIN, INPUT);
  
  // *** FIX: Using HIGH to turn OFF Active-LOW relays ***
  Serial.println("Step 2: Forcing Pumps to Initial OFF State...");
  digitalWrite(PUMP1_PIN, HIGH); 
  digitalWrite(PUMP2_PIN, HIGH);
  
  Serial.println("Startup Complete!");
  Serial.println("Beginning Phase 1 -> Goal: Wait for depth to reach 0");
  Serial.println("=====================================\n");
}

void loop() {
  // If the job is already finished, do nothing else.
  if (jobCompleted) {
    return; 
  }

  // Read the depth sensor value
  int depthValue = analogRead(DEPTH_SENSOR_PIN);
  unsigned long currentMillis = millis();
  
  // --- PHASE 1: Pump 1 running ---
  if (currentPhase == 1) {
    // *** FIX: LOW turns ON, HIGH turns OFF ***
    digitalWrite(PUMP1_PIN, LOW);  // Turn ON Pump 1
    digitalWrite(PUMP2_PIN, HIGH); // Ensure Pump 2 is OFF
    
    // Print status every second
    if (currentMillis - lastPrintTime >= printInterval) {
      Serial.print("STEP: Phase 1 Active | Pump 1: ON  | Pump 2: OFF | Current Depth: ");
      Serial.println(depthValue);
      lastPrintTime = currentMillis;
    }
    
    // Check if depth has reached 0
    if (depthValue <= 0) {
      currentPhase = 2; // Move to the next phase
      Serial.println("\n*** EVENT: Depth reached 0! ***");
      Serial.println("Stopping Pump 1...");
      Serial.println("Starting Pump 2...");
      Serial.println("Beginning Phase 2 -> Goal: Wait for depth to cross 1800\n");
    }
  }
  
  // --- PHASE 2: Pump 2 running ---
  else if (currentPhase == 2) {
    // *** FIX: LOW turns ON, HIGH turns OFF ***
    digitalWrite(PUMP1_PIN, HIGH);  // Ensure Pump 1 is OFF
    digitalWrite(PUMP2_PIN, LOW);   // Turn ON Pump 2
    
    // Print status every second
    if (currentMillis - lastPrintTime >= printInterval) {
      Serial.print("STEP: Phase 2 Active | Pump 1: OFF | Pump 2: ON  | Current Depth: ");
      Serial.println(depthValue);
      lastPrintTime = currentMillis;
    }
    
    // Check if depth crosses 1800
    if (depthValue > 1900) {
      // Job is done
      Serial.println("\n*** EVENT: Depth crossed 1800! ***");
      Serial.println("Shutting down all pumps...");
      
      // *** FIX: HIGH turns OFF Active-LOW relays ***
      digitalWrite(PUMP1_PIN, HIGH);  // Turn OFF Pump 1
      digitalWrite(PUMP2_PIN, HIGH);  // Turn OFF Pump 2
      
      jobCompleted = true; // Set flag so the loop stops checking
      Serial.println("\n=====================================");
      Serial.println("All jobs completed successfully.");
      Serial.println("System standing by.");
      Serial.println("=====================================");
    }
  }

  // Small delay for overall stability
  delay(50); 
}