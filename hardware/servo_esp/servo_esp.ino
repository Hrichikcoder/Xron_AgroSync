#include <ESP32Servo.h>

// Create a servo object
Servo myServo;  

// Define the GPIO pin for the servo (using GPIO 4 as discussed)
const int servoPin = 4; 

void setup() {
  Serial.begin(115200);
  
  // Standard servos operate at 50Hz
  myServo.setPeriodHertz(50); 
  
  // Attach the servo to the pin. 
  // Pulse widths of 500 and 2400 usually ensure a full 0 to 180 degree rotation.
  myServo.attach(servoPin, 500, 2400); 
  
  Serial.println("Servo attached and ready.");
}

void loop() {
  Serial.println("Fast sweep to 180 degrees...");
  
  // Sweep from 0 to 180 in steps of 2 degrees for faster movement
  for (int pos = 0; pos <= 180; pos += 2) { 
    myServo.write(pos);    
    delay(5); // Only wait 5ms per step
  }
  
  delay(1000); // Pause for 1 second at the 180-degree mark
  
  Serial.println("Fast sweep to 0 degrees...");
  
  // Sweep back from 180 to 0 in steps of 2 degrees
  for (int pos = 180; pos >= 0; pos -= 2) { 
    myServo.write(pos);    
    delay(5); // Only wait 5ms per step
  }
  
  delay(1000); // Pause for 1 second at the 0-degree mark
}