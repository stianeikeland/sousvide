/*
 * Sous Vide controller by Stian Eikeland
 * <stian.eikeland@gmail.com>
 *
 * Libraries used:
 * - Button: https://github.com/tigoe/Button
 * - OneWire: http://www.pjrc.com/teensy/td_libs_OneWire.html
 * - DallasTemperature: http://www.milesburton.com/?title=Dallas_Temperature_Control_Library
 * - PID v1: http://code.google.com/p/arduino-pid-library/
 * - LiquidCrystal: http://www.arduino.cc/en/Tutorial/LiquidCrystal
 *
 * Pins-layout:
 * - LCD: 12, 11, 5, 4, 3, 2
 * - Onewire: 10
 * - SSR: 9
 * - Buttons: 6 (up), 7 (down), 8 (set)
 * - Status LED: 13
 */

#define DEBUGMODE

#ifndef DEBUGMODE
#define DEBUG(a)
#define DEBUGSTART(a)
#else
#define DEBUG(a) Serial.println(a);
#define DEBUGSTART(a) Serial.begin(a);
#endif

#include <Button.h>
#include <LiquidCrystal.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <PID_v1.h>

#define LCDSIZE 20, 4

#define SSR 9
#define ONEWIRE 10
#define BTN_UP 6
#define BTN_DOWN 7
#define BTN_SET 8
#define LED 13
#define LCD 12, 11, 5, 4, 3, 2

enum programmode {
	menumode,
	cooking
};


programmode mode = menumode;

LiquidCrystal lcd(LCD);

#define RESOLUTION 12
#define TEMPINTERVAL 2000

OneWire oneWire(ONEWIRE);
DallasTemperature sensor(&oneWire);
DeviceAddress tempDeviceAddress;

Button btnUp = Button(BTN_UP, PULLUP);
Button btnDown = Button(BTN_DOWN, PULLUP);
Button btnSet = Button(BTN_SET, PULLUP);

unsigned long lastTempRequest = 0;
unsigned long lastPIDCalculation = 0;
float temperature;
float prevTemperature = -9999.0;

double pidSetPoint = 60;
double pidInput, pidOutput;

PID pid(&pidInput, &pidOutput, &pidSetPoint, 2, 5, 1, DIRECT);

void setup()
{
	DEBUGSTART(9600);
	DEBUG("Running setup..");
	
	lcd.begin(LCDSIZE);
	lcd.clear();
	
	lcd.print("Sous Vide 2000");
	lcd.noCursor();
	
	pinMode(SSR, OUTPUT);
	pinMode(LED, OUTPUT);
	
	sensor.begin();
	
	// Sensor detected?
	checkSensor();
	
	lcd.setCursor(0, 2);
	lcd.print("Sensor detected");
	lcd.setCursor(0, 3);
	lcd.print("");
	
	pid.SetOutputLimits(0, TEMPINTERVAL);
	pid.SetSampleTime(TEMPINTERVAL);
	
	delay(1000);
}

/* Detect sensor, ask user to attach if not.. */
void checkSensor()
{
	DEBUG("Checking sensor..");
	
	// Wait for sensor and ask user
	while (sensor.getDeviceCount() == 0)
	{
		lcd.setCursor(0, 2);
		lcd.print("No temp-sensor detected,");
		lcd.setCursor(0, 3);
		lcd.print("please attach probe..");
	
		DEBUG("No sensor detected..");
		delay(1000);
		sensor.begin();
	}
	
	// Set sensor options and request first sample
	sensor.getAddress(tempDeviceAddress, 0);
	sensor.setResolution(tempDeviceAddress, RESOLUTION);
	sensor.setWaitForConversion(false);
	sensor.requestTemperatures();
	prevTemperature = millis();
}

void menu()
{
	bool changed = false;
	
	if (btnUp.uniquePress()) {
		DEBUG("Button Up");
		pidSetPoint += 1.0;
		changed = true;
	}
	
	if (btnDown.uniquePress()) {
		DEBUG("Button Down");
		pidSetPoint -= 1.0;
		changed = true;
	}
	
	if (changed) {
		lcd.setCursor(0, 2);
		lcd.print("Target temperature: ");
		lcd.print(int(pidSetPoint));
	}
	
	delay(10);
}

void cook()
{
	
	if (millis() <= (lastPIDCalculation + pidOutput)) {
		// Power cooker on:
		digitalWrite(SSR, HIGH);
		digitalWrite(LED, HIGH);
	} else {
		// Power cooker off:
		digitalWrite(SSR, LOW);
		digitalWrite(LED, LOW);
	}
	
	delay(10);
}

void loop()
{
	// Check temperature and request new sample:
	if (millis() - lastTempRequest >= TEMPINTERVAL) {
		temperature = sensor.getTempCByIndex(0);
		pidInput = (double)temperature;
		
		// Calculate PID value:
		if (mode == cooking) {
			pid.Compute();
			lastPIDCalculation = millis();
		}
		
		if (temperature != prevTemperature) {
			lcd.setCursor(0, 2);
			lcd.print("Current temperature: ");
			lcd.print(temperature, 1);
			
			DEBUG("Temperature:");
			DEBUG(temperature);
			DEBUG("Output:");
			DEBUG(pidOutput);
		}
		
		prevTemperature = temperature;
		
		sensor.requestTemperatures();
		lastTempRequest = millis();
	}
		
	// Change mode?
	if (btnSet.uniquePress()) {
		if (mode == menumode) {
			pid.SetMode(AUTOMATIC);
			lcd.setCursor(0,1);
			lcd.print(" - Cooking mode engaged!");
			DEBUG("Cooking mode..");
			mode = cooking;
			
		} else if (mode == cooking) {
			pid.SetMode(MANUAL);
			digitalWrite(SSR, LOW);
			digitalWrite(LED, LOW);
			lcd.setCursor(0,1);
			lcd.print(" - Set target temperature:");
			DEBUG("Setup mode..");
			mode = menumode;
		}
	}
	
	if (mode == menumode)
		menu();
	else
		cook();
	
}
