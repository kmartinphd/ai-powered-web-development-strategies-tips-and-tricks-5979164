// ============================================================
//  Cardioid via Multiplication Method
//
//  Interactive sliders:
//    • Points      – evenly-spaced points on the circle
//    • Multiplier  – chord-mapping factor  n → (n × mult) % N
//    • Hue         – base colour of the chords
//    • Chord Width – stroke weight
//
//  Animation keyboard shortcuts:
//    Shift + Space – START  (sweep multiplier 1→10, hue 0→360)
//    Space         – RESET  (stop animation, return to start)
// ============================================================

// ── runtime parameters (driven by sliders / animation) ──────
int   numPoints  = 200;
float multiplier = 2.0;
float hueBase    = 0.0;
float chordWidth = 1.0;

// ── animation state ─────────────────────────────────────────
boolean animating    = false;
boolean animDone     = false;
float   animProgress = 0.0;        // 0.0 → 1.0
final float ANIM_SPEED = 0.00055;  // ≈ 30 s for a full sweep at 60 fps

// ── shift-key tracker (for Shift+Space) ─────────────────────
boolean shiftHeld = false;

// ── layout constants ─────────────────────────────────────────
final int   CANVAS_W  = 820;
final int   CANVAS_H  = 720;
final float CIRCLE_R  = 270;
final float CIRCLE_CX = CANVAS_W / 2.0;
final float CIRCLE_CY = 308;

// ── sliders ──────────────────────────────────────────────────
Slider slPoints, slMult, slHue, slChord;

// ─────────────────────────────────────────────────────────────
void setup() {
  size(820, 720);
  colorMode(HSB, 360, 100, 100, 100);
  textFont(createFont("SansSerif", 12, true));

  float slY = 638;
  float slW = 160;
  float gap = (CANVAS_W - 4 * slW) / 5.0;

  slPoints = new Slider(gap,               slY, slW, "Points",      10,  500, numPoints);
  slMult   = new Slider(gap*2 + slW,       slY, slW, "Multiplier",   1,   10, multiplier);
  slHue    = new Slider(gap*3 + slW*2,     slY, slW, "Hue",          0,  360, hueBase);
  slChord  = new Slider(gap*4 + slW*3,     slY, slW, "Chord Width", 0.2,   6, chordWidth);
}

// ─────────────────────────────────────────────────────────────
void draw() {
  background(0, 0, 8);

  // ── advance animation ────────────────────────────────────────
  if (animating) {
    animProgress += ANIM_SPEED;
    if (animProgress >= 1.0) {
      animProgress = 1.0;
      animating    = false;
      animDone     = true;
    }
    // Drive multiplier and hue from progress, write back into sliders
    slMult.setValue(map(animProgress, 0, 1, slMult.minVal, slMult.maxVal));
    slHue.setValue (map(animProgress, 0, 1, 0, 360));
  }

  // ── read slider values ───────────────────────────────────────
  slPoints.update(); slMult.update(); slHue.update(); slChord.update();

  numPoints  = max(3, (int) slPoints.getValue());
  multiplier = slMult.getValue();
  hueBase    = slHue.getValue();
  chordWidth = slChord.getValue();

  // ── title ────────────────────────────────────────────────────
  fill(0, 0, 95);
  noStroke();
  textSize(18);
  textAlign(CENTER, TOP);
  text("Cardioid  –  Multiplication Method", CANVAS_W / 2.0, 12);

  textSize(13);
  fill(0, 0, 65);
  text("n  →  ( n × " + nf(multiplier, 1, 3) + " )  mod  " + numPoints,
       CANVAS_W / 2.0, 38);

  // ── main drawing ─────────────────────────────────────────────
  drawChords();
  drawCircleOutline();

  // ── sliders ──────────────────────────────────────────────────
  slPoints.render();
  slMult.render();
  slHue.render();
  slChord.render();

  // ── animation overlay (progress bar + status) ────────────────
  drawAnimOverlay();

  // ── bottom hint ──────────────────────────────────────────────
  drawHint();
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
    line(CIRCLE_CX + (CIRCLE_R-5)*c_, CIRCLE_CY + (CIRCLE_R-5)*s_,
         CIRCLE_CX + (CIRCLE_R+5)*c_, CIRCLE_CY + (CIRCLE_R+5)*s_);
  }
}

// ─────────────────────────────────────────────────────────────
void drawAnimOverlay() {
  float barX = 14, barY = 598;
  float barW = CANVAS_W - 28, barH = 8;

  // Track background
  noStroke();
  fill(0, 0, 20);
  rect(barX, barY, barW, barH, 4);

  if (animProgress > 0) {
    // Filled portion – colour follows current hue
    float fillW = barW * animProgress;
    fill(hueBase, 80, 95, 90);
    rect(barX, barY, fillW, barH, 4);
  }

  // Status badge
  String statusText;
  int    badgeH = 0;
  int    badgeSat = 0;
  int    badgeBri = 0;

  if (animating) {
    statusText = "PLAYING";
    badgeH = (int)hueBase; badgeSat = 70; badgeBri = 80;
  } else if (animDone) {
    statusText = "DONE  –  Space to reset  |  Shift+Space to play again";
    badgeH = 120; badgeSat = 60; badgeBri = 70;
  } else {
    statusText = "READY  –  Shift+Space to play";
    badgeH = 0; badgeSat = 0; badgeBri = 45;
  }

  fill(badgeH, badgeSat, badgeBri, 90);
  noStroke();
  textSize(11);
  textAlign(LEFT, BASELINE);
  text(statusText, barX, barY - 6);

  // Progress percentage on the right
  if (animating || animDone) {
    textAlign(RIGHT, BASELINE);
    fill(0, 0, 65);
    text(nf(animProgress * 100, 1, 1) + "%", barX + barW, barY - 6);
  }
}

// ─────────────────────────────────────────────────────────────
void drawHint() {
  fill(0, 0, 35);
  noStroke();
  textSize(11);
  textAlign(LEFT, BASELINE);
  text("Drag sliders  •  mult ≈ 2 → cardioid  •  mult ≈ 3 → nephroid", 14, CANVAS_H - 8);
  textAlign(RIGHT, BASELINE);
  text("Shift+Space = play  |  Space = reset", CANVAS_W - 14, CANVAS_H - 8);
}

// ── keyboard ──────────────────────────────────────────────────
void keyPressed() {
  if (keyCode == SHIFT) {
    shiftHeld = true;
    return;
  }

  if (key == ' ') {
    if (shiftHeld) {
      // Shift+Space → start (or restart) the animation
      animProgress = 0.0;
      animDone     = false;
      animating    = true;
      // Unlock multiplier & hue sliders during animation
      slMult.locked = true;
      slHue.locked  = true;
    } else {
      // Space → reset to beginning, stop
      animating    = false;
      animDone     = false;
      animProgress = 0.0;
      slMult.setValue(slMult.minVal);
      slHue.setValue(0);
      slMult.locked = false;
      slHue.locked  = false;
    }
  }
}

void keyReleased() {
  if (keyCode == SHIFT) shiftHeld = false;
}

// When animation finishes naturally, unlock the sliders
void unlockAfterAnim() {
  if (!animating && animDone) {
    slMult.locked = false;
    slHue.locked  = false;
  }
}

// ── mouse ─────────────────────────────────────────────────────
void mousePressed() {
  unlockAfterAnim();
  slPoints.onPress(); slMult.onPress(); slHue.onPress(); slChord.onPress();
}

void mouseReleased() {
  slPoints.onRelease(); slMult.onRelease(); slHue.onRelease(); slChord.onRelease();
}


// ╔══════════════════════════════════════════════════════════╗
// ║  Slider class                                            ║
// ╚══════════════════════════════════════════════════════════╝
class Slider {
  float   x, y, w;
  String  label;
  float   minVal, maxVal, value;
  boolean dragging = false;
  boolean locked   = false;   // true while animation drives this slider

  final float TRACK_H     = 4;
  final float HANDLE_R    = 8;
  final float LABEL_ABOVE = 18;
  final float VALUE_BELOW = 16;

  Slider(float x, float y, float w,
         String label, float minVal, float maxVal, float defaultVal) {
    this.x      = x;
    this.y      = y;
    this.w      = w;
    this.label  = label;
    this.minVal = minVal;
    this.maxVal = maxVal;
    this.value  = defaultVal;
  }

  float getValue() { return value; }

  void setValue(float v) {
    value = constrain(v, minVal, maxVal);
  }

  void update() {
    if (!locked && dragging) {
      value = map(constrain(mouseX, x, x + w), x, x + w, minVal, maxVal);
    }
  }

  void render() {
    float hx = map(value, minVal, maxVal, x, x + w);

    // ── track (background) ───────────────────────────────────
    stroke(0, 0, 22);
    strokeWeight(TRACK_H);
    line(x, y, x + w, y);

    // ── track (filled) ───────────────────────────────────────
    float fillHue = locked ? hueBase : hueBase;
    float fillSat = locked ? 85 : 70;
    float fillBri = locked ? 100 : 90;
    stroke(fillHue, fillSat, fillBri);
    strokeWeight(TRACK_H);
    line(x, y, hx, y);

    // ── handle ───────────────────────────────────────────────
    noStroke();
    if (locked) {
      // Animated slider: glowing coloured handle
      fill(hueBase, 80, 100, 80);
      ellipse(hx, y, (HANDLE_R+2) * 2, (HANDLE_R+2) * 2);   // glow ring
      fill(hueBase, 40, 100);
      ellipse(hx, y, HANDLE_R * 2, HANDLE_R * 2);
    } else {
      fill(0, 0, 95);
      ellipse(hx, y, HANDLE_R * 2, HANDLE_R * 2);
    }

    // ── label ────────────────────────────────────────────────
    fill(locked ? 0 : 0, locked ? 0 : 0, locked ? 90 : 75);
    noStroke();
    textSize(11);
    textAlign(CENTER, BASELINE);
    text(label, x + w / 2.0, y - LABEL_ABOVE);

    // ── value ────────────────────────────────────────────────
    fill(0, 0, locked ? 100 : 90);
    textSize(11);
    textAlign(CENTER, TOP);
    String display = label.equals("Points") ? str((int) value) : nf(value, 1, 2);
    text(display, x + w / 2.0, y + VALUE_BELOW);
  }

  void onPress() {
    if (locked) return;
    float hx = map(value, minVal, maxVal, x, x + w);
    if (dist(mouseX, mouseY, hx, y) < HANDLE_R + 4) dragging = true;
  }

  void onRelease() { dragging = false; }
}
