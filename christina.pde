import processing.serial.*;
import cc.arduino.*;
import processing.video.*;
import ddf.minim.*;
import ddf.minim.ugens.*;
import controlP5.*;

ControlP5 cp5;
Minim minim;
AudioSnippet mainAudio;
AudioSample soundOne;
AudioSample soundTwo;
AudioSample soundThree;
Movie movie;
Arduino arduino;
Smoother videoSmoother;
Smoother audioSmoother;
Smoother soundTriggerSmoother;
Textlabel origValueLabel;
Textlabel modValueLabel;
Range rangeSlider;
RadioButton filterRadio;
Slider delaySlider;

// "posterize", "pixel"
String videoFilter = "pixel";

// sensor calibration settings
int maxValue = 525;
int minValue = 0;

// fullscreen
boolean isFullscreen = false;

// flags
boolean debug = false;
boolean soundOnePlayed = false;
boolean soundTwoPlayed = false;
boolean soundThreePlayed = false;

// other settings
int appDelay = 25;

void setup() {

	// this must be the size of the video file
	size(1280, 720);

	// this prints out the possible arduino connections
	println(Arduino.list());

	// create the connection with arduino
	arduino = new Arduino(this, Arduino.list()[7], 57600);
	arduino.pinMode(0, Arduino.INPUT);

	// create the cp5 instance
	cp5 = new ControlP5(this);

	// create the minim instance
	minim = new Minim(this);

	// load and play the main background sound
	mainAudio = minim.loadSnippet("movie_sound.mp3");
	mainAudio.play();
	mainAudio.loop();

	// load the other sounds
	soundOne = minim.loadSample("sound1.mp3");
	soundTwo = minim.loadSample("sound2.mp3");
	soundThree = minim.loadSample("sound3.mp3");

	// value smoothing
	videoSmoother = new Smoother(20);
	audioSmoother = new Smoother(20);
	soundTriggerSmoother = new Smoother(50);

	// start the movie
	movie = new Movie(this, "movie.mp4");
	movie.loop();

	// setup the debug console
	setupDebugConsole();

}

void draw() {

	float value = arduino.analogRead(0);

	image(movie, 0, 0, 1280, 720);

	applyVideoEffects(value);
	applySoundEffects(value);

	if (debug) {
		origValueLabel.setText("origValue: " + value);
	}

	delay(appDelay);

}

void movieEvent(Movie m) {
	m.read();
}

void applyVideoEffects(float value) {

	float modValue = 0;

	// set the output range for sensor reading value
	if (videoFilter == "posterize") {
		modValue = map(value, minValue, maxValue, 2, 255);
	} else if (videoFilter == "pixel") {
		modValue = map(value, minValue, maxValue, 32, 1);
		modValue = modValue / (32 - modValue);
	}

	// value correction if for any case it is wrong
	if (videoFilter == "posterize") {
		if (modValue < 2) modValue = 2;
		if (modValue > 255) modValue = 255;
	} else if (videoFilter == "pixel") {
		if (modValue < 1) modValue = 1;
		if (modValue > 32) modValue = 32;
	}

	// smooth out the sensor reading value
	videoSmoother.add(modValue);
	modValue = round(videoSmoother.read());

	if (debug) {
		modValueLabel.setText("modValue: " + modValue);
	}

	// apply specific video effect
	if (videoFilter == "posterize") {
		filter(POSTERIZE, modValue);
	} else if (videoFilter == "pixel") {
		doPixelImage(modValue);
	}

}

void applySoundEffects(float value) {

	float modValue = 0;

	// set range for modified value (gain range goes from around -50 to +6)
	modValue = map(value, minValue, maxValue, 6, -30);

	audioSmoother.add(modValue);
	modValue = round(audioSmoother.read());

	soundTriggerSmoother.add(modValue);

	int triggerValue = int(soundTriggerSmoother.read());

	if (triggerValue > -30 && triggerValue < -20 && soundOnePlayed == false) {
		soundOne.trigger();
		soundOnePlayed = true;
		soundTwoPlayed = false;
		soundThreePlayed = false;
		println("sound1");
	}

	if (triggerValue > -20 && triggerValue < 0 && soundTwoPlayed == false) {
		soundTwo.trigger();
		soundOnePlayed = false;
		soundTwoPlayed = true;
		soundThreePlayed = false;
		println("sound2");
	}

	if (triggerValue > 0 && triggerValue < 6 && soundThreePlayed == false) {
		soundThree.trigger();
		soundOnePlayed = false;
		soundTwoPlayed = false;
		soundThreePlayed = true;
		println("sound3");
	}

	mainAudio.setGain(modValue);

}

void doPixelImage(float modValue) {

	int newPixelSize = int(modValue);

	if (newPixelSize < 5) {
		return;
	}

	int cols = width / newPixelSize;
	int rows = height / newPixelSize;

	movie.loadPixels();

	for (int i = 0; i < cols; i++) {

		for (int j = 0; j < rows; j++) {

			int x = i * newPixelSize;
			int y = j * newPixelSize;

			color c = movie.get(x, y);
			fill(c);
			stroke(c);
			rect(x, y, newPixelSize, newPixelSize);

		}

	}

}

void setupDebugConsole() {

	// labels
	origValueLabel = cp5.addTextlabel("orig_value_label")
		.setText("origValue: 0")
		.setPosition(5, 5)
		.setColorValue(0xff000000)
		.setFont(createFont("Monospace", 12));

	modValueLabel = cp5.addTextlabel("mod_value_label")
		.setText("modValue: 0")
		.setPosition(5, 25)
		.setColorValue(0xff000000)
		.setFont(createFont("Monospace", 12));

	// range slider
	rangeSlider = cp5.addRange("Min/Max Sensor Range Calibration")
		.setBroadcast(false)
		.setPosition(10, 50)
		.setSize(400, 20)
		.setHandleSize(20)
		.setRange(0, 600)
		.setRangeValues(minValue, maxValue)
		.setBroadcast(true)
		.setColorForeground(color(0, 50))
		.setColorBackground(color(0, 85));

	// filter radio buttons
	filterRadio = cp5.addRadioButton("filterRadioController")
		.setPosition(10, 80)
		.setSize(40, 20)
		.setColorForeground(color(0, 50))
		.setColorBackground(color(0, 75))
		.setItemsPerRow(1)
		.addItem("pixel", 0)
		.addItem("posterize", 1);

	// delay slider
	delaySlider = cp5.addSlider("Delay Ms")
		.setPosition(10, 135)
		.setColorForeground(color(0, 50))
		.setColorBackground(color(0, 75))
		.setValue(appDelay)
		.setRange(0, 255);

	if (videoFilter == "pixel") {
		filterRadio.activate(0);
	} else if (videoFilter == "posterize") {
		filterRadio.activate(1);
	}

	cp5.hide();

}

void toggleDebug() {

	debug =! debug;

	if (debug) {
		cp5.show();
	} else {
		cp5.hide();
	}

}

void keyReleased() {
	if (key == 'd' || key == 'D') {
		toggleDebug();
	}
}

void controlEvent(ControlEvent theControlEvent) {

	if (theControlEvent.isFrom(rangeSlider)) {
		minValue = int(theControlEvent.getController().getArrayValue(0));
		maxValue = int(theControlEvent.getController().getArrayValue(1));
	}

	if (theControlEvent.isFrom(filterRadio)) {

		int val = int(theControlEvent.group().value());

		if (val == 0) {
			videoFilter = "pixel";
			rangeSlider.setRangeValues(0, 525);
		} else if (val == 1) {
			videoFilter = "posterize";
			rangeSlider.setRangeValues(50, 525);
		}

		videoSmoother.reset(2);

	}

	if (theControlEvent.isFrom(delaySlider)) {
		appDelay = int(theControlEvent.value());
	}

}

boolean sketchFullScreen() {
	return isFullscreen;
}