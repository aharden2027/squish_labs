#include <ESP32Servo.h>

Servo myservo;
int servoPin = 10;

#define SWITCH1 3   // Shutter control pin 1 (e.g., focus)
#define SWITCH2 2   // Shutter control pin 2 (e.g., shutter release)

// Track last trigger time to prevent double triggering
unsigned long lastTriggerTime = 0;
const unsigned long debounceDelay = 500;  // 500ms debounce time

// State tracking to prevent unwanted triggers
volatile bool isTriggering = false;

void setup() {
  Serial.begin(115200);
  
  // Configure pins with INPUT_PULLDOWN when not in use
  // This ensures they're not floating when the ESP32 is on but not actively driving them
  pinMode(SWITCH1, OUTPUT);
  pinMode(SWITCH2, OUTPUT);
  digitalWrite(SWITCH1, LOW);
  digitalWrite(SWITCH2, LOW);

  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);
  
  myservo.setPeriodHertz(50);
  myservo.attach(servoPin, 700, 2400);  // Adjust for your servo

  Serial.println("ESP32-C3 Integrated Control Ready");
}

void triggerShutter() {
  // Check if enough time has passed since last trigger
  unsigned long currentTime = millis();
  if (currentTime - lastTriggerTime < debounceDelay) {
    Serial.println("Debouncing: Ignored rapid trigger request");
    return;  // Exit if we're still within debounce time
  }
  
  // Set flag to prevent reentrancy
  if (isTriggering) {
    Serial.println("Already triggering, ignoring request");
    return;
  }
  
  isTriggering = true;
  
  // Store the trigger time
  lastTriggerTime = currentTime;
  
  // Actual trigger sequence
  digitalWrite(SWITCH1, HIGH);
  delay(100);  // Reduced from 1000ms to 100ms - faster focus
  digitalWrite(SWITCH2, HIGH);
  delay(100);  // Reduced from 1000ms to 100ms - shorter shutter press
  digitalWrite(SWITCH2, LOW);
  delay(50);   // Small delay before releasing focus
  digitalWrite(SWITCH1, LOW);
  
  // Clear trigger flag
  isTriggering = false;
  
  // Add additional debounce delay to ensure no double triggers
  delay(50);
}

void loop() {
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    command.trim();

    if (command == "SHUTTER") {
      triggerShutter();
      Serial.println("OK: Shutter triggered");

    } else if (command == "FILTER,ON") {
      myservo.write(0);  // Filter in front
      Serial.println("OK: Filter ON");

    } else if (command == "FILTER,OFF") {
      myservo.write(180);  // Filter away
      Serial.println("OK: Filter OFF");

    } else {
      Serial.println("ERROR: Unknown command");
    }
  }

  // Reduced main loop delay for better responsiveness
  delay(10);
}