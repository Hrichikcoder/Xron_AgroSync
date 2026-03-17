// Define Pin Connection
const int FLOW_SENSOR_PIN = 27;
const int PUMP = 13;

// Variables for calculation
volatile unsigned long pulseCount = 0; 
const float mlPerPulse = 2.22;         // Your specific calibration factor
float totalVolumeML = 0.0;

// Timer variables
unsigned long lastPrintTime = 0;
const unsigned long printInterval = 1000; // Update every 1 second

// Interrupt Service Routine (ISR)
// IRAM_ATTR ensures this runs in RAM for the fastest possible response
void IRAM_ATTR countPulse() {
  pulseCount++;
}

void setup() {
  Serial.begin(115200);
  
  // Using INPUT_PULLUP stabilizes the signal if the sensor pulls to ground
  pinMode(FLOW_SENSOR_PIN, INPUT_PULLUP);
  pinMode(PUMP, OUTPUT);
  
  // TURN PUMP ON CONTINUOUSLY (Active-LOW relay: LOW is ON, HIGH is OFF)
  digitalWrite(PUMP, LOW);
  
  // Attach the interrupt to trigger every time the signal falls from HIGH to LOW
  attachInterrupt(digitalPinToInterrupt(FLOW_SENSOR_PIN), countPulse, FALLING);
  
  Serial.println("\n--- Flow Sensor & Pump Test Initialized ---");
  Serial.print("Listening for pulses on Pin: ");
  Serial.println(FLOW_SENSOR_PIN);
  Serial.println("Pump is currently RUNNING. Measuring flow...\n");
}

void loop() {
  unsigned long currentMillis = millis();
  
  // Print the status every 1 second without interfering with the pump
  if (currentMillis - lastPrintTime >= printInterval) {
    
    // Temporarily pause interrupts to safely read the volatile variable
    noInterrupts();
    unsigned long currentPulses = pulseCount;
    interrupts();
    
    // Calculate total volume in milliliters
    totalVolumeML = currentPulses * mlPerPulse;
    
    // Calculate simulated flow rate (pulses in the last second)
    static unsigned long lastPulses = 0;
    unsigned long pulsesThisSecond = currentPulses - lastPulses;
    lastPulses = currentPulses;
    
    float flowRateMLPerSec = pulsesThisSecond * mlPerPulse;
    
    // Print the results
    Serial.print("Raw Pulses: ");
    Serial.print(currentPulses);
    Serial.print(" | Flow Rate: ");
    Serial.print(flowRateMLPerSec);
    Serial.print(" mL/s | Total Volume: ");
    Serial.print(totalVolumeML);
    Serial.println(" mL");
    
    lastPrintTime = currentMillis;
  }
}