// Got this from: http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1226431507/105

#include <TimerOne.h>
#include <PID_Beta6.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <LiquidCrystal.h>
#include <Button.h>

#define ONE_WIRE_BUS 9

OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

int controlPin = 10;

int upButtonPin = 6;
int downButtonPin = 7;
int selButtonPin = 8;

Button upButton = Button(upButtonPin, PULLDOWN);
Button downButton = Button(downButtonPin, PULLDOWN);
Button selButton = Button(selButtonPin, PULLDOWN);

double params[4] = {140, 90,300,0};
char param_char[4] = {'S', 'P', 'I', 'D'};
double increment[4] = {1, 5, 5, 5};

double Input, Output;                            
double Setpoint = params[0];                          
double Bias = 200;

float temperature = 0;			          
int menuPos = 0;
int loopDelay = 0;

PID pid(&Input, &Output, &Setpoint, &Bias, params[1], params[2], params[3]);

void setup()
{
  /*Serial.begin(9600);*/
  pinMode(controlPin, OUTPUT);  
  
  sensors.begin();

  pid.SetOutputLimits(0,1023);  
  Output = 0;
  pid.SetMode(AUTO);

  Timer1.initialize();
  Timer1.pwm(controlPin, Output);
  

  lcd.begin(16, 2);
  lcd.clear();
  lcd.print("Arduino PID");
  lcd.setCursor(0,1);
  lcd.print("Controller");
  /*Serial.print("Arduino PID Controller\n");*/
  delay(5000);
  lcd.clear();
}

void loop()
{
  sensors.requestTemperatures();
  temperature = sensors.getTempFByIndex(0);

  Input = (double)temperature;
  if(Setpoint - Input > 3){
    Setpoint -= 5;
    pid.Compute();
    Setpoint += 5;
  }
  else{
    pid.Compute();
  }
  
  Timer1.setPwmDuty(controlPin, (int)Output);
  delay(loopDelay);
  
  lcd.setCursor(0,0);
  lcd.print("T:");
  lcd.print(temperature,1);
  lcd.setCursor(9,1);
  lcd.print("O:");
  lcd.print(Output,0);
  lcd.setCursor(0, 1);
  lcd.print("S:");
  lcd.print(Setpoint,0);

  /*Serial.print("T:");
  Serial.print(temperature);
  Serial.print("\t");
  Serial.print("O:");
  Serial.print(Output,0);
  Serial.print("\t");
  Serial.print("S:");
  Serial.print(Setpoint,0);
  Serial.print("\n");*/
  
  if(selButton.uniquePress()) {
    lcd.clear();
    for(menuPos = 0; menuPos < 4; ){
      lcd.setCursor(0,0);
      lcd.print(param_char[menuPos]);
      lcd.print(": ");
      lcd.print(params[menuPos],0);

      /*Serial.print(param_char[menuPos]);
      Serial.print(": ");
      Serial.print(params[menuPos],0);      
      Serial.print("\n");*/

      if (upButton.uniquePress()) {        
        params[menuPos] += increment[menuPos];
      }
      if (downButton.uniquePress()) {        
        params[menuPos] -= increment[menuPos];
      }
      if(selButton.uniquePress()) {
        menuPos++;
        lcd.clear();
      }
    }
    Setpoint = params[0];
    pid.SetTunings(params[1], params[2], params[3]);
    lcd.clear();
  }
}  
 

