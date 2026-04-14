// ============================================================
//  Cardioid via Multiplication Method  –  controlP5 edition
//
//  Sliders (controlP5 library):
//    Points      – evenly-spaced points on the circle
//    Multiplier  – chord factor  n → (n × mult) % N
//    Hue         – base colour of the chords (HSB 0–360)
//    Chord Width – stroke weight of each chord
//
//  Animation:
//    Shift+Space – sweep multiplier 1→10 while hue 0→360 (~30 s)
//    Space       – reset both to start, stop animation
// ============================================================

import controlP5.*;

// ── controlP5 ─────────────────────────────────────────────────
ControlP5 cp5;
Slider    sPoints, sMult, sHue, sChord;

// ── runtime values ─────────────────────────────────────────────
int   numPoints  = 200;
float multiplier = 2.0;
float hueBase    = 0.0;
float chordWidth = 1.0;

// ── animation state ────────────────────────────────────────────
boolean animating    = false;
boolean animDone     = false;
float   animProgress = 0.0;
final float ANIM_SPEED = 0.00055;   // full sweep ≈ 30 s @ 60 fps

boolean shiftHeld = false;

// ── layout ─────────────────────────────────────────────────────
final int   CANVAS_W  = 820;
final int   CANVAS_H  = 740;
final float CIRCLE_R  = 255;
final float CIRCLE_CX = CANVAS_W / 2.0;
final float CIRCLE_CY = 295;

// Slider belt
final int SL_Y = 648;   // slider track centre y
final int SL_W = 155;   // slider track width
final int SL_H = 14;    // slider track height

// ─────────────────────────────────────────────────────────────
void setup() {
  size(820, 740);
  colorMode(HSB, 360, 100, 100, 100);
  textFont(createFont("SansSerif", 12, true));
  buildControls();
}

// ─────────────────────────────────────────────────────────────
void buildControls() {
  cp5 = new ControlP5(this);

  int gap = (CANVAS_W - 4 * SL_W) / 5;

  sPoints = cp5.addSlider("sPoints")
               .setRange(10, 500).setValue(numPoints)
               .setPosition(gap,               SL_Y).setSize(SL_W, SL_H)
               .setLabel("Points").setDecimalPrecision(0);

  sMult   = cp5.addSlider("sMult")
               .setRange(1, 10).setValue(multiplier)
               .setPosition(gap * 2 + SL_W,   SL_Y).setSize(SL_W, SL_H)
               .setLabel("Multiplier").setDecimalPrecision(2);

  sHue    = cp5.addSlider("sHue")
               .setRange(0, 360).setValue(hueBase)
               .setPosition(gap * 3 + SL_W*2, SL_Y).setSize(SL_W, SL_H)
               .setLabel("Hue").setDecimalPrecision(1);

  sChord  = cp5.addSlider("sChord")
               .setRange(0.2, 6).setValue(chordWidth)
               .setPosition(gap * 4 + SL_W*3, SL_Y).setSize(SL_W, SL_H)
               .setLabel("Chord Width").setDecimalPrecision(2);

  // Initial theme + label placement for all four sliders
  for (Slider s : new Slider[]{ sPoints, sMult, sHue, sChord }) {
    applyTheme(s, false);
  }
}

// ── apply colour theme to a slider ───────────────────────────
//   animated=true  → vivid, hue-matched colours (locked sliders)
//   animated=false → neutral grey colours (free sliders)
void applyTheme(Slider s, boolean animated) {
  if (animated) {
    s.setColorBackground(color(0,        0,  12))
     .setColorForeground(color(hueBase, 80, 100))
     .setColorActive    (color(hueBase, 95, 100))
     .setColorLabel     (color(0,        0,  92))
     .setColorValue     (color(hueBase, 20, 100));
  } else {
    s.setColorBackground(color(0,  0,  12))
     .setColorForeground(color(0,  0,  50))
     .setColorActive    (color(0,  0,  78))
     .setColorLabel     (color(0,  0,  72))
     .setColorValue     (color(0,  0,  88));
  }
  // Label above the track, value below it
  s.getCaptionLabel().align(ControlP5.CENTER, ControlP5.TOP_OUTSIDE   ).setPaddingY(4);
  s.getValueLabel  ().align(ControlP5.CENTER, ControlP5.BOTTOM_OUTSIDE).setPaddingY(4);
}

// ─────────────────────────────────────────────────────────────
void draw() {
  background(0, 0, 8);

  // ── advance animation ────────────────────────────────────────
  if (animating) {
    animProgress = min(animProgress + ANIM_SPEED, 1.0);

    // Push animated values into the controlP5 sliders
    sMult.setValue(map(animProgress, 0, 1, sMult.getMin(), sMult.getMax()));
    sHue .setValue(map(animProgress, 0, 1, 0, 360));

    if (animProgress >= 1.0) {
      animating = false;
      animDone  = true;
      sMult.unlock();
      sHue .unlock();
      applyTheme(sMult, false);
      applyTheme(sHue,  false);
    }
  }

  // ── read current slider values ───────────────────────────────
  numPoints  = max(3, (int) sPoints.getValue());
  multiplier = sMult.getValue();
  hueBase    = sHue .getValue();
  chordWidth = sChord.getValue();

  // ── re-tint animated sliders with the freshly read hue ───────
  if (animating) {
    applyTheme(sMult, true);
    applyTheme(sHue,  true);
  }

  // ── scene ────────────────────────────────────────────────────
  drawTitle();
  drawChords();
  drawCircleOutline();
  drawAnimOverlay();
  drawHint();

  // controlP5 auto-draws its controls on top after draw() returns
}

// ─────────────────────────────────────────────────────────────
void drawTitle() {
  fill(0, 0, 95);
  noStroke();
  textSize(18);
  textAlign(CENTER, TOP);
  text("Cardioid  –  Multiplication Method", CANVAS_W / 2.0, 12);

  textSize(13);
  fill(0, 0, 65);
  text("n  →  ( n × " + nf(multiplier, 1, 3) + " )  mod  " + numPoints,
       CANVAS_W / 2.0, 38);
}

// ─────────────────────────────────────────────────────────────
void drawChords() {
  strokeWeight(chordWidth);
  noFill();

  for (int n = 0; n < numPoints; n++) {
    float a1 = map(n,                           0, numPoints, 0, TWO_PI) - HALF_PI;
    float a2 = map((n * multiplier) % numPoints, 0, numPoints, 0, TWO_PI) - HALF_PI;

    float x1 = CIRCLE_CX + CIRCLE_R * cos(a1);
    float y1 = CIRCLE_CY + CIRCLE_R * sin(a1);
    float x2 = CIRCLE_CX + CIRCLE_R * cos(a2);
    float y2 = CIRCLE_CY + CIRCLE_R * sin(a2);

    float h = (hueBase + map(n, 0, numPoints, 0, 40)) % 360;
    stroke(h, 75, 100, 65);
    line(x1, y1, x2, y2);
  }
}

// ─────────────────────────────────────────────────────────────
void drawCircleOutline() {
  noFill();
  stroke(0, 0, 45, 50);
  strokeWeight(1);
  ellipse(CIRCLE_CX, CIRCLE_CY, CIRCLE_R * 2, CIRCLE_R * 2);

  stroke(0, 0, 55, 35);
  strokeWeight(1);
  for (int n = 0; n < numPoints; n++) {
    float a  = map(n, 0, numPoints, 0, TWO_PI) - HALF_PI;
    float c_ = cos(a), s_ = sin(a);
    line(CIRCLE_CX + (CIRCLE_R - 5) * c_, CIRCLE_CY + (CIRCLE_R - 5) * s_,
         CIRCLE_CX + (CIRCLE_R + 5) * c_, CIRCLE_CY + (CIRCLE_R + 5) * s_);
  }
}

// ─────────────────────────────────────────────────────────────
void drawAnimOverlay() {
  float barX = 14, barY = 602;
  float barW = CANVAS_W - 28, barH = 8;

  // Track background
  noStroke();
  fill(0, 0, 18);
  rect(barX, barY, barW, barH, 4);

  // Filled portion in current hue
  if (animProgress > 0) {
    fill(hueBase, 80, 95, 90);
    rect(barX, barY, barW * animProgress, barH, 4);
  }

  // Status label
  String statusText;
  color  statusCol;

  if (animating) {
    statusText = "PLAYING";
    statusCol  = color((int) hueBase, 70, 85);
  } else if (animDone) {
    statusText = "DONE  –  Space to reset  |  Shift+Space to play again";
    statusCol  = color(120, 55, 70);
  } else {
    statusText = "READY  –  Shift+Space to play";
    statusCol  = color(0, 0, 45);
  }

  fill(statusCol);
  noStroke();
  textSize(11);
  textAlign(LEFT, BASELINE);
  text(statusText, barX, barY - 6);

  if (animating || animDone) {
    textAlign(RIGHT, BASELINE);
    fill(0, 0, 62);
    text(nf(animProgress * 100, 1, 1) + "%", barX + barW, barY - 6);
  }
}

// ─────────────────────────────────────────────────────────────
void drawHint() {
  fill(0, 0, 30);
  noStroke();
  textSize(11);
  textAlign(LEFT, BASELINE);
  text("mult ≈ 2 → cardioid   mult ≈ 3 → nephroid", 14, CANVAS_H - 10);
  textAlign(RIGHT, BASELINE);
  text("Shift+Space = play  |  Space = reset", CANVAS_W - 14, CANVAS_H - 10);
}

// ── keyboard ─────────────────────────────────────────────────
void keyPressed() {
  if (keyCode == SHIFT) { shiftHeld = true; return; }

  if (key == ' ') {
    if (shiftHeld) {
      // Shift+Space → start / restart sweep
      animProgress = 0.0;
      animDone     = false;
      animating    = true;
      sMult.lock(); sHue.lock();
      applyTheme(sMult, true);
      applyTheme(sHue,  true);
    } else {
      // Space → reset
      animating    = false;
      animDone     = false;
      animProgress = 0.0;
      sMult.setValue(sMult.getMin());
      sHue .setValue(0);
      sMult.unlock(); sHue.unlock();
      applyTheme(sMult, false);
      applyTheme(sHue,  false);
    }
  }
}

void keyReleased() {
  if (keyCode == SHIFT) shiftHeld = false;
}
