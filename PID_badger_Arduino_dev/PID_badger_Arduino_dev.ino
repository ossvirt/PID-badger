/******************************************************************
 * PID Simple Example (Augmented with Processing.org Communication)
 * Version 0.3
 * by Brett Beauregard
 * License: Creative-Commons Attribution Share-Alike
 * April 2011
 ******************************************************************/

#include <PID_v1.h>

#define pHupPin 2
#define pHdownPin 3

//Define Variables we'll be connecting to
double Setpoint, Input, Output, SendOutput;
int inputPin=A0, RelayPin;

double Dissolved_Oxygen = 5.7;
double Temp = 6.7;
double Oxygen_Gas = 7.7;
double CO2 = 8.7;
int timeFrame = 11;

//Specify the links and initial tuning parameters
PID myPID(&Input, &Output, &Setpoint,1 ,0 ,0 , DIRECT);

int WindowSize = 5000;
unsigned long windowStartTime;

unsigned long serialTime; //this will help us know when to talk with processing

void setup()
{
  // define pin usage types for Arduino
  pinMode(2, OUTPUT);
  pinMode(3, OUTPUT);
  pinMode(A0, INPUT);

  windowStartTime = millis();

  //initialize the serial link with processing
  Serial.begin(9600);

  //initialize the variables we're linked to
  Input = (4 + ((analogRead(inputPin))/170.67));
  Setpoint = 7;

  //tell the PID to range between 0 and the full window size
  myPID.SetOutputLimits(0, WindowSize);

  //turn the PID on
  myPID.SetMode(AUTOMATIC);

  digitalWrite(pHupPin,LOW);
  digitalWrite(pHdownPin,LOW);

}





void loop()
{
  //pid-related code
  Input = analogRead(inputPin);
  myPID.Compute();

   if(millis() - windowStartTime > WindowSize)
 { //time to shift the Relay Window
   windowStartTime += WindowSize;
 }

 if (Output > 0) RelayPin = pHupPin;
 else RelayPin = pHdownPin;

 SendOutput = abs(Output * 39);

 if (SendOutput > 5000) SendOutput = 5000;
 if (SendOutput < 0) SendOutput = 0;

 if(SendOutput < millis() - windowStartTime) digitalWrite(RelayPin,HIGH);
 else digitalWrite(RelayPin,LOW);

  //send-receive with processing if it's time
  if(millis() > serialTime)
  {
    SerialReceive();
    SerialSend();
    serialTime += 500;
  }


}


/********************************************
 * Serial Communication functions / helpers
 ********************************************/


union {                // This Data structure lets
  byte asBytes[16];    // us take the byte array
  float asFloat[4];    // sent from processing and
}                      // easily convert it to a
foo;                   // float array



// getting float values from processing into the arduino
// was no small task.  the way this program does it is
// as follows:
//  * a float takes up 4 bytes.  in processing, convert
//    the array of floats we want to send, into an array
//    of bytes.
//  * send the bytes to the arduino
//  * use a data structure known as a union to convert
//    the array of bytes back into an array of floats

//  the bytes coming from the arduino follow the following
//  format:
//  0: 0=Manual, 1=Auto, else = ? error ?
//  1: 0=Direct, 1=Reverse, else = ? error ?
//  2-5: float setpoint
//  6-9: float input
//  10-13: float output
//  14-17: float P_Param
//  18-21: float I_Param
//  22-245: float D_Param
void SerialReceive()
{

  // read the bytes sent from Processing
  int index=0;
  while(Serial.available()&&index<16){
    foo.asBytes[index] = Serial.read();
    index++;
  }
  if(index==16){
    double p, i, d;                       // * read in and set the controller tunings
    Setpoint = double(foo.asFloat[0]);           //
    p = double(foo.asFloat[1]);           //
    i = double(foo.asFloat[2]);           //
    d = double(foo.asFloat[3]);           //
    myPID.SetTunings(p, i, d);            //
  }
  Serial.flush();                         // * clear any random data from the serial buffer
}

// unlike our tiny microprocessor, the processing ap
// has no problem converting strings into floats, so
// we can just send strings.  much easier than getting
// floats from processing to here no?
void SerialSend()
{
  Serial.print(timeFrame);
  Serial.print(" ");
  Serial.print("PID ");
  Serial.print(Setpoint);
  Serial.print(" ");
  Serial.print(Input);
  Serial.print(" ");
  Serial.print(Output);
  Serial.print(" ");
  Serial.print(myPID.GetKp());
  Serial.print(" ");
  Serial.print(myPID.GetKi());
  Serial.print(" ");
  Serial.print(myPID.GetKd());
  Serial.print(" ");
  Serial.print(Temp);
  Serial.print(" ");
  Serial.print(Dissolved_Oxygen);
  Serial.print(" ");
  Serial.print(Oxygen_Gas);
  Serial.print(" ");
  Serial.println(CO2);
}
