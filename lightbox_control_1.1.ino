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
    command.trim(); // Remove newline and whitespace

    if (command.startsWith("SET_COLOR")) {
      handleSetColor(command);
    } else if (command.equalsIgnoreCase("OFF")) {
      setColor(CRGB::Black);
      Serial.println("Color = OFF");
    } else if (command.equalsIgnoreCase("SETUP")) {
      setupFlash();
      Serial.println("SETUP complete");
    } else {
      Serial.println("Unknown command. Use SET_COLOR R G B, OFF, or SETUP.");
    }
  }
}

void handleSetColor(String command) {
  int r = -1, g = -1, b = -1;

  // Extract RGB values from string
  sscanf(command.c_str(), "SET_COLOR %d %d %d", &r, &g, &b);

  // Validate range
  if (r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0 && b <= 255) {
    setColor(CRGB(r, g, b));
    Serial.print("Color = ");
    Serial.print(r); Serial.print(", ");
    Serial.print(g); Serial.print(", ");
    Serial.println(b);
  } else {
    Serial.println("Invalid SET_COLOR values. Use: SET_COLOR R G B");
  }
}

void setColor(CRGB color) {
  for (int i = 0; i < NUM_STRIPS; i++) {
    fill_solid(ledArrays[i], NUM_LEDS_PER_STRIP, color);
  }
  FastLED.show();
}

void setupFlash() {
  const int cycles = 2;         // Number of full rainbow waves
  const int delayMs = 20;       // Delay between frames
  const int hueStep = 1;        // Speed of wave motion

  for (int t = 0; t < 256 * cycles; t += hueStep) {
    for (int i = 0; i < NUM_STRIPS; i++) {
      for (int j = 0; j < NUM_LEDS_PER_STRIP; j++) {
        uint8_t hue = (j * 256 / NUM_LEDS_PER_STRIP + t) % 256;
        ledArrays[i][j] = CHSV(hue, 255, BRIGHTNESS);
      }
    }
    FastLED.show();
    delay(delayMs);
  }

  // Optionally turn off LEDs after the animation
  setColor(CRGB::Black);
}
