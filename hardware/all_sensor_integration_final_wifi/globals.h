#ifndef GLOBALS_H
#define GLOBALS_H

#include <Arduino.h>
#include <DHT.h>
#include <ESP32Servo.h> // Included Servo library

// --- Network & Backend Configuration ---
extern const char* ssid;
extern const char* password;
extern const char* backendUrl;
extern const char* overrideUrl;
extern const char* notificationUrl;

// --- Define Pin Connections ---
extern const int PUMP1_PIN;
extern const int PUMP2_PIN;
extern const int DEPTH_SENSOR_PIN;
extern const int CAP_SENSOR_PIN;
extern const int FLOW_SENSOR_PIN;
extern const int SERVO_PIN; // Added Servo Pin declaration
extern const int SPRINKLER_PIN; // Added Sprinkler Pin declaration

// --- Environmental Sensor Pins ---
#define DHTPIN 26
#define DHTTYPE DHT11
extern DHT dht;
extern const int LDR_PIN;
extern const int RAIN_PIN;

// --- System State Variables ---
extern int currentPhase;
extern bool pump1Running;

// --- Override State Tracking ---
extern String currentMode;
extern bool manualPump1;
extern bool manualPump2;
extern bool manualShade; // Added manual shade override state
extern bool manualSprinkler; // Added sprinkler override state
extern Servo shadeServo; // Added Servo instance
extern unsigned long lastOverrideCheck;
extern const unsigned long overrideInterval;

// --- Volume Tracking Variables ---
extern float targetVolume;
extern float currentVolume;
extern float lastCycleVolume;
extern bool targetVolumeReached;

// --- Flow Sensor Interrupt Variables ---
extern volatile unsigned long pulseCount;
extern float mlPerPulse;
extern unsigned long lastFlowMillis; // <-- ADD THIS
extern float currentFlowRate;        // <-- ADD THIS
extern const float calibrationFactor; // <-- ADD THIS

// --- Timers ---
extern unsigned long lastPrintTime;
extern const unsigned long printInterval;

extern unsigned long lastEnvPrintTime;
extern const unsigned long envPrintInterval;

extern unsigned long pump2StartTime;
extern const unsigned long pump2RunDuration;

extern unsigned long volumeReachedTime;
extern const unsigned long restartDelay;

#endif