// ============================================================
//  Cardioid via Multiplication Method
//  Controls:
//    • Points      – number of evenly-spaced points on the circle
//    • Multiplier  – the factor n → (n × mult) % points
//    • Hue         – base colour of the chords
//    • Chord Width – stroke weight of each chord
// ============================================================

// ── runtime parameters (driven by sliders) ──────────────────
int   numPoints    = 200;
float multiplier   = 2.0;
float hueBase      = 0.0;
float chordWidth   = 1.0;

// ── layout constants ─────────────────────────────────────────
final int   CANVAS_W   = 820;
final int   CANVAS_H   = 720;
final float CIRCLE_R   = 270;
final float CIRCLE_CX  = CANVAS_W / 2.0;
final float CIRCLE_CY  = 310;

// ── sliders ──────────────────────────────────────────────────
Slider slPoints, slMult, slHue, slChord;

// ─────────────────────────────────────────────────────────────
void setup() {
  size(820, 720);
  colorMode(HSB, 360, 100, 100, 100);
  textFont(createFont("SansSerif", 12, true));

  float slY  = 640;
  float slW  = 160;
  float gap  = (CANVAS_W - 4 * slW) / 5.0;

  slPoints = new Slider(gap,               slY, slW, "Points",      10,  500, numPoints);
  slMult   = new Slider(gap * 2 + slW,     slY, slW, "Multiplier",   1,   10, multiplier);
  slHue    = new Slider(gap * 3 + slW * 2, slY, slW, "Hue",          0,  360, hueBase);
  slChord  = new Slider(gap * 4 + slW * 3, slY, slW, "Chord Width", 0.2,   6, chordWidth);
}

// ─────────────────────────────────────────────────────────────
void draw() {
  background(0, 0, 8);

  // ── update sliders & read values ────────────────────────────
  slPoints.update(); slMult.update(); slHue.update(); slChord.update();

  numPoints  = max(3, (int) slPoints.getValue());
  multiplier = slMult.getValue();
  hueBase    = slHue.getValue();
  chordWidth = slChord.getValue();

  // ── title ───────────────────────────────────────────────────
  fill(0, 0, 95);
  noStroke();
  textSize(18);
  textAlign(CENTER, TOP);
  text("Cardioid  –  Multiplication Method", CANVAS_W / 2.0, 14);

  textSize(13);
  fill(0, 0, 65);
  text("n  →  ( n × " + nf(multiplier, 1, 2) + " )  mod  " + numPoints,
       CANVAS_W / 2.0, 40);

  // ── draw ────────────────────────────────────────────────────
  drawChords();
  drawCircleOutline();

  // ── sliders ─────────────────────────────────────────────────
  slPoints.render();
  slMult.render();
  slHue.render();
  slChord.render();

  // ── legend ──────────────────────────────────────────────────
  drawLegend();
}

// ─────────────────────────────────────────────────────────────
void drawChords() {
  strokeWeight(chordWidth);
  noFill();

  for (int n = 0; n < numPoints; n++) {
    float a1 = map(n,                          0, numPoints, 0, TWO_PI) - HALF_PI;
    float a2 = map((n * multiplier) % numPoints, 0, numPoints, 0, TWO_PI) - HALF_PI;

    float x1 = CIRCLE_CX + CIRCLE_R * cos(a1);
    float y1 = CIRCLE_CY + CIRCLE_R * sin(a1);
    float x2 = CIRCLE_CX + CIRCLE_R * cos(a2);
    float y2 = CIRCLE_CY + CIRCLE_R * sin(a2);

    // Shift hue gently across the chord set for depth
    float h = (hueBase + map(n, 0, numPoints, 0, 40)) % 360;
    stroke(h, 75, 100, 65);
    line(x1, y1, x2, y2);
  }
}

// ─────────────────────────────────────────────────────────────
void drawCircleOutline() {
  noFill();
  stroke(0, 0, 45, 55);
  strokeWeight(1);
  ellipse(CIRCLE_CX, CIRCLE_CY, CIRCLE_R * 2, CIRCLE_R * 2);

  // tick marks at each point
  stroke(0, 0, 55, 40);
  strokeWeight(1);
  for (int n = 0; n < numPoints; n++) {
    float a   = map(n, 0, numPoints, 0, TWO_PI) - HALF_PI;
    float cos_ = cos(a);
    float sin_ = sin(a);
    float r0  = CIRCLE_R - 5;
    float r1  = CIRCLE_R + 5;
    line(CIRCLE_CX + r0 * cos_, CIRCLE_CY + r0 * sin_,
         CIRCLE_CX + r1 * cos_, CIRCLE_CY + r1 * sin_);
  }
}

// ─────────────────────────────────────────────────────────────
void drawLegend() {
  float lx = 14, ly = CANVAS_H - 22;
  fill(0, 0, 45);
  noStroke();
  textSize(11);
  textAlign(LEFT, BASELINE);
  text("Drag any slider handle to adjust  •  mult ≈ 2 → cardioid  •  mult ≈ 3 → nephroid", lx, ly);
}

// ─────────────────────────────────────────────────────────────
void mousePressed()  { slPoints.onPress(); slMult.onPress(); slHue.onPress(); slChord.onPress(); }
void mouseReleased() { slPoints.onRelease(); slMult.onRelease(); slHue.onRelease(); slChord.onRelease(); }


// ╔══════════════════════════════════════════════════════════╗
// ║  Slider class                                            ║
// ╚══════════════════════════════════════════════════════════╝
class Slider {
  float  x, y, w;
  String label;
  float  minVal, maxVal, value;
  boolean dragging = false;

  final float TRACK_H    = 4;
  final float HANDLE_R   = 8;
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

  void update() {
    if (dragging) {
      value = map(constrain(mouseX, x, x + w), x, x + w, minVal, maxVal);
    }
  }

  void render() {
    float hx = map(value, minVal, maxVal, x, x + w);

    // ── filled track ──────────────────────────────────────────
    stroke(0, 0, 30);
    strokeWeight(TRACK_H);
    line(x, y, x + w, y);

    stroke(hueBase, 70, 90);
    strokeWeight(TRACK_H);
    line(x, y, hx, y);

    // ── handle ────────────────────────────────────────────────
    noStroke();
    fill(0, 0, 95);
    ellipse(hx, y, HANDLE_R * 2, HANDLE_R * 2);

    // ── label ─────────────────────────────────────────────────
    fill(0, 0, 75);
    noStroke();
    textSize(11);
    textAlign(CENTER, BASELINE);
    text(label, x + w / 2.0, y - LABEL_ABOVE);

    // ── value ─────────────────────────────────────────────────
    fill(0, 0, 90);
    textSize(11);
    textAlign(CENTER, TOP);

    String display;
    if (label.equals("Points")) {
      display = str((int) value);
    } else {
      display = nf(value, 1, 2);
    }
    text(display, x + w / 2.0, y + VALUE_BELOW);
  }

  void onPress() {
    float hx = map(value, minVal, maxVal, x, x + w);
    if (dist(mouseX, mouseY, hx, y) < HANDLE_R + 4) dragging = true;
  }

  void onRelease() { dragging = false; }
}
