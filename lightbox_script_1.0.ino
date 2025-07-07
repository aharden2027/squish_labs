#include <FastLED.h>

#define NUM_LEDS_PER_STRIP 211
#define NUM_STRIPS 9
#define BRIGHTNESS 255

// LED arrays for each strip
CRGB leds0[NUM_LEDS_PER_STRIP];
CRGB leds1[NUM_LEDS_PER_STRIP];
CRGB leds2[NUM_LEDS_PER_STRIP];
CRGB leds3[NUM_LEDS_PER_STRIP];
CRGB leds4[NUM_LEDS_PER_STRIP];
CRGB leds5[NUM_LEDS_PER_STRIP];
CRGB leds6[NUM_LEDS_PER_STRIP];
CRGB leds7[NUM_LEDS_PER_STRIP];
CRGB leds8[NUM_LEDS_PER_STRIP];

CRGB* ledArrays[NUM_STRIPS] = {
  leds0, leds1, leds2, leds3, leds4, leds5, leds6, leds7, leds8
};

void setup() {
  Serial.begin(9600);
  FastLED.setBrightness(BRIGHTNESS);

  // Initialize each strip with its specific pin
  FastLED.addLeds<WS2812B, 12, GRB>(leds0, NUM_LEDS_PER_STRIP);
  FastLED.addLeds<WS2812B, 11, GRB>(leds1, NUM_LEDS_PER_STRIP);
  FastLED.addLeds<WS2812B, 10, GRB>(leds2, NUM_LEDS_PER_STRIP);
  FastLED.addLeds<WS2812B, 9, GRB>(leds3, NUM_LEDS_PER_STRIP);
  FastLED.addLeds<WS2812B, 8, GRB>(leds4, NUM_LEDS_PER_STRIP);
  FastLED.addLeds<WS2812B, 7, GRB>(leds5, NUM_LEDS_PER_STRIP);
  FastLED.addLeds<WS2812B, 6, GRB>(leds6, NUM_LEDS_PER_STRIP);
  FastLED.addLeds<WS2812B, 5, GRB>(leds7, NUM_LEDS_PER_STRIP);
  FastLED.addLeds<WS2812B, 3, GRB>(leds8, NUM_LEDS_PER_STRIP);
}

void loop() {
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim(); // Remove trailing newline and whitespace

    if (command.equalsIgnoreCase("RED")) {
      setColor(CRGB::Red);
      Serial.println("Color = RED");
    } else if (command.equalsIgnoreCase("GREEN")) {
      setColor(CRGB::Green);
      Serial.println("Color = GREEN");
    } else if (command.equalsIgnoreCase("OFF")) {
      setColor(CRGB::Black);
      Serial.println("Color = OFF");
    } else if (command.equalsIgnoreCase("SETUP")) {
      setupFlash();
      Serial.println("SETUP complete");
    } else {
      Serial.println("Unknown command. Use RED, GREEN, OFF, or SETUP.");
    }
  }
}

void setColor(CRGB color) {
  for (int i = 0; i < NUM_STRIPS; i++) {
    fill_solid(ledArrays[i], NUM_LEDS_PER_STRIP, color);
  }
  FastLED.show();
}

void setupFlash() {
  for (int i = 0; i < 3; i++) {
    setColor(CRGB::Green);
    delay(2000);
    setColor(CRGB::Red);
    delay(2000);
  }
}
