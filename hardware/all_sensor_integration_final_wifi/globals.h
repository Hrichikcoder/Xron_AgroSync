#ifndef GLOBALS_H
#define GLOBALS_H

#include <Arduino.h>
#include <DHT.h>
#include <ESP32Servo.h>

extern const char* ssid;
extern const char* password;
extern const char* backendUrl;
extern const char* overrideUrl;
extern const char* notificationUrl;

extern const int PUMP1_PIN;
extern const int PUMP2_PIN;
extern const int DEPTH_SENSOR_PIN;
extern const int CAP_SENSOR_PIN;
extern const int FLOW_SENSOR_PIN;
extern const int SERVO_PIN;
extern const int SPRINKLER_PIN;

#define DHTPIN 26
#define DHTTYPE DHT11
extern DHT dht;
extern const int LDR_PIN;
extern const int RAIN_PIN;

extern int currentPhase;
extern bool pump1Running;

extern String currentMode;
extern bool manualPump1;
extern bool manualPump2;
extern bool manualShade;
extern bool shadeOverride; 
extern bool manualSprinkler;
extern Servo shadeServo;
extern unsigned long lastOverrideCheck;
extern const unsigned long overrideInterval;

extern float targetVolume;
extern float currentVolume;
extern float lastCycleVolume;
extern bool targetVolumeReached;

extern volatile unsigned long pulseCount;
extern float mlPerPulse;
extern unsigned long lastFlowMillis;
extern float currentFlowRate;
extern const float calibrationFactor;

extern unsigned long lastPrintTime;
extern const unsigned long printInterval;

extern unsigned long lastEnvPrintTime;
extern const unsigned long envPrintInterval;

extern unsigned long pump2StartTime;
extern const unsigned long pump2RunDuration;

extern unsigned long volumeReachedTime;
extern const unsigned long restartDelay;

extern bool disableSoil;
extern bool disableDepth;
extern bool disableTemp;
extern bool disableLdr;
extern bool disableRain;

#endif