#ifndef NETWORK_SENSORS_H
#define NETWORK_SENSORS_H

void checkBackendOverride();
void printEnvironmentSensors();
void sendSensorDataToBackend(float temp, float hum, int ldr, int cap, int rain, int depth, float flow, float flow_rate);

#endif