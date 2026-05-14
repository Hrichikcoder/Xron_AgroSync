const int PUMP1_PIN = 18;
const int PUMP2_PIN = 19;
const int PUMP3_PIN = 21;

void setup() {
  Serial.begin(115200);

  pinMode(PUMP1_PIN, OUTPUT);
  pinMode(PUMP2_PIN, OUTPUT);
  pinMode(PUMP3_PIN, OUTPUT);

  digitalWrite(PUMP1_PIN, HIGH);
  digitalWrite(PUMP2_PIN, HIGH);
  digitalWrite(PUMP3_PIN, HIGH);
}

void loop() {
  Serial.println("Testing Pump 1");
  digitalWrite(PUMP1_PIN, LOW);
  delay(2000);
  digitalWrite(PUMP1_PIN, HIGH);
  delay(1000);

  Serial.println("Testing Pump 2");
  digitalWrite(PUMP2_PIN, LOW);
  delay(2000);
  digitalWrite(PUMP2_PIN, HIGH);
  delay(1000);

  Serial.println("Testing Pump 3");
  digitalWrite(PUMP3_PIN, LOW);
  delay(2000);
  digitalWrite(PUMP3_PIN, HIGH);
  delay(1000);
}