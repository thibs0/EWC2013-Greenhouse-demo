// Controlling a servo position using a potentiometer (variable resistor) 
// by Michal Rinott <http://people.interaction-ivrea.it/m.rinott> 

#include <SimpleModbusSlave.h>
#include <Servo.h> 

#define potPin      0  // analog pin used to connect the potentiometer
#define tempPin     1  // analog pin used to connect the temperature meter
#define lightPin    2  // analog pin used to connect the light sensor
#define moisturePin 3  // analog pin used to connect the moisture sensor
#define buttonPin   7  // digital pin for push button
#define servoPin    9  // digital PWM pin to connect the servomotor
#define ledPin     10  // digital pin for onboard led


Servo myservo;  // create servo object to control a servo 
 
// Variables
int pot;
int temp;
int temp_calib = 3975;
int light;
int moisture;
byte led = HIGH;
byte button;

#define CLOSED 142
#define OPENED 42
int servo = CLOSED;

//////////////// MODBUS Registers (Slave) ///////////////////
enum 
{     
  // just add or remove registers and your good to go...
  // The first register starts at address 0
  ADC0,         // Pot analog read
  ADC1,         // Temp analog read
  ADC2,         // Light analog read
  ADC3,         // Moisture analog read
  ADC4,         // unused but kept here just in case...
  ADC5,         // unused but kept here just in case...
  BUTTON_STATE, // Button digital read
  LED_STATE,    // LED state write => command servo
  TOTAL_ERRORS,
  // leave this one
  TOTAL_REGS_SIZE 
  // total number of registers for function 3 and 16 share the same register array
};

unsigned int holdingRegs[TOTAL_REGS_SIZE]; // function 3 and 16 register array

////////////////////////////////////////////////////////////
 
void setup() 
{ 
  Serial.begin(115200);
  
  /* parameters(long baudrate, 
                unsigned char ID, 
                unsigned char transmit enable pin, 
                unsigned int holding registers size
                unsigned char low latency enabled)
                x
     The transmit enable pin is used in half duplex communication to activate a MAX485 or similar
     to deactivate this mode use any value < 2 because 0 & 1 is reserved for Rx & Tx
  */
  modbus_configure(115200, 1, 2, TOTAL_REGS_SIZE, 0);
  
  myservo.attach(servoPin);  // attaches the servo on pin 9 to the servo object 
  
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, led);
  
  pinMode(buttonPin, INPUT);
  button = digitalRead(buttonPin);
}

void loop()
{
  // modbus_update() returns the total error
  // count since the slave started. You don't have to use it but it's useful
  // for fault finding by the modbus master.
  holdingRegs[TOTAL_ERRORS] = modbus_update(holdingRegs);

  // Read analog inputs and set to first assigned registers
  for (byte i = 0; i < 6; i++)
  {
    holdingRegs[i] = analogRead(i);
    delayMicroseconds(500);	     
  }
  
  // Read button state and set register
  button = digitalRead(buttonPin);
  holdingRegs[BUTTON_STATE] = button; 
  
  // Read the LED_STATE register value and set the onboard LED high or low and command servo
  led = holdingRegs[LED_STATE]; 
  
  if (led)
  {		  
    digitalWrite(ledPin, HIGH);
    if(servo == CLOSED)
    {
      while(servo > OPENED) {
        myservo.write(servo--);
        delay (20);
      }
    }
  } 
    
  if (!led)
  {
    digitalWrite(ledPin, LOW);
    if(servo == OPENED)
    {
     while(servo < CLOSED) {
        myservo.write(servo++);
        delay (20);
      }
    }
  }
}
