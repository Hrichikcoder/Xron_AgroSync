#include "globals.h"
#include "secrets.h"

// --- Network Configuration ---
const char* ssid = SECRET_SSID;
const char* password = SECRET_PASS;

// --- Backend Configuration ---
const char* backendUrl = SECRET_BACKEND_URL; 
const char* overrideUrl = SECRET_OVERRIDE_URL;
const char* notificationUrl = SECRET_NOTIFICATION_URL;

// Define Pin Connections
const int PUMP1_PIN = 13;
const int PUMP2_PIN = 14;
const int DEPTH_SENSOR_PIN = 34;
const int CAP_SENSOR_PIN = 32; 
const int FLOW_SENSOR_PIN = 27; 
const int SERVO_PIN = 4;
const int SPRINKLER_PIN = 25; 

// Environmental Sensor Setup
DHT dht(DHTPIN, DHTTYPE);
const int LDR_PIN = 33;
const int RAIN_PIN = 35;

// System State Variables
int currentPhase = 1;
bool pump1Running = false;        

// Override State Tracking
String currentMode = "auto";
bool manualPump1 = false;
bool manualPump2 = false;
bool manualSprinkler = false;

// Servo Speed Control Variables
int currentServoAngle = 0;
int targetServoAngle = 0;
unsigned long lastServoMoveTime = 0;
const int servoMoveDelay = 15; 

unsigned long lastOverrideCheck = 0;
const unsigned long overrideInterval = 3000; 

// Volume Tracking Variables
float targetVolume = 500.0;
float currentVolume = 0.0;         
float lastCycleVolume = 0.0;       
bool targetVolumeReached = false;
unsigned long lastFlowMillis = 0;
float currentFlowRate = 0.0; 
const float calibrationFactor = 4.5;

// Flow Sensor Interrupt Variables
volatile unsigned long pulseCount = 0; 
float mlPerPulse = 0.0; 

// --- Timers ---
unsigned long lastPrintTime = 0;
const unsigned long printInterval = 1000;

unsigned long lastEnvPrintTime = 0;
// CHANGED: Reduced to 5 seconds (5000ms) for fast-paced demo so ML updates quickly!
const unsigned long envPrintInterval = 5000; 

unsigned long pump2StartTime = 0;
const unsigned long pump2RunDuration = 18000;

unsigned long volumeReachedTime = 0;
const unsigned long restartDelay = 5000;