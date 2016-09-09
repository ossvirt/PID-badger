/********************************************************
 * Arduino PID Tuning Front-End,  Version 0.3
 * by Brett Beauregard
 * License: Creative-Commons Attribution Share-Alike
 * April 2011
 *
 * This application is designed to interface with an
 * arduino running the PID Library.  From this Control
 * Panel you can observe & adjust PID performance in
 * real time
 *
 * The ControlP5 library is required to run this sketch.
 * files and install instructions can be found at
 * http://www.sojamo.de/libraries/controlP5/
 *
 ********************************************************/

import java.nio.ByteBuffer;
import processing.serial.*;
import controlP5.*;

/***********************************************
 * User spcification section
 **********************************************/
int windowWidth = 900;      // set the size of the
int windowHeight = 600;     // form

float InScaleMin = 4;       // set the Y-Axis Min
float InScaleMax = 10;    // and Max for both
float OutScaleMin = -127;      // the top and
float OutScaleMax = 128;    // bottom trends


int windowSpan = 300000;    // number of mS into the past you want to display
int refreshRate = 100;      // how often you want the graph to be reDrawn;

//float displayFactor = 1; //display Time as Milliseconds
//float displayFactor = 1000; //display Time as Seconds
float displayFactor = 60000; //display Time as Minutes

String outputFileName = "data_log.txt"; // if you'd like to output data to
// a file, specify the path here

/***********************************************
 * end user spec
 **********************************************/

int nextRefresh;
int arrayLength = windowSpan / refreshRate+1;
int[] InputData = new int[arrayLength];     //we might not need them this big, but
int[] SetpointData = new int[arrayLength];  // this is worst case
int[] OutputData = new int[arrayLength];


float inputTop = 25;
float inputHeight = (windowHeight-70)*2/3;
float outputTop = inputHeight+50;
float outputHeight = (windowHeight-70)*1/3;

float ioLeft = 160, ioWidth = windowWidth-ioLeft-50;
float ioRight = ioLeft+ioWidth;
float pointWidth= (ioWidth)/float(arrayLength-1);

int vertCount = 10;

int nPoints = 0;

float Input1, Setpoint1, Output1;

boolean madeContact =false;
boolean justSent = true;

Serial myPort;

ControlP5 controlP5;
controlP5.Button Submit;
controlP5.Textlabel InLabel, OutLabel, TempLabel, DissOxLabel, OxLabel, CO2Label, SPLabel, PLabel, ILabel, DLabel;
controlP5.Textlabel InTextLabel, OutTextLabel, TempTextLabel, DissOxTextLabel, OxTextLabel, CO2TextLabel, HeadingLabel;
controlP5.Textfield SPField, PField, IField, DField;

PrintWriter output;
PFont AxisFont, TitleFont;

void setup()
{
  frameRate(30);
  surface.setSize(windowWidth , windowHeight);
  println((Object[])Serial.list());                                   // * Initialize Serial
  myPort = new Serial(this, Serial.list()[1], 9600);                //   Communication with
  myPort.stop();
  myPort = new Serial(this, Serial.list()[1], 9600);                //   Communication with
  myPort.bufferUntil('\n');                                           //   the Arduino
  controlP5 = new ControlP5(this);                                  // * Initialize the various

  //HeadingLabel=controlP5.addTextlabel("HEADING","PID Control",20,20).setHeight(100);
  //text("PID Control",20,20);

  InTextLabel=controlP5.addTextlabel("INPUT","INPUT",10,58);
  OutTextLabel=controlP5.addTextlabel("OUTPUT","OUPUT",10,88);
  TempTextLabel=controlP5.addTextlabel("TEMPERATURE","TEMPERATURE",10,118);
  DissOxTextLabel=controlP5.addTextlabel("DISSOLVED OXYGEN","DISSOLVED OXYGEN",10,148);
  OxTextLabel=controlP5.addTextlabel("OXYGEN GAS","OXYGEN GAS",10,178);
  CO2TextLabel=controlP5.addTextlabel("CARBON DIOXIDE GAS","CARBON-DI-OXIDE GAS",10,208);

  InLabel=controlP5.addTextlabel("INPUT VALUE","0.0",120,58);
  OutLabel=controlP5.addTextlabel("OUTPUT VALUE","0.0",120,88);
  TempLabel=controlP5.addTextlabel("TEMPERATURE VALUE","0.0",120,118);
  DissOxLabel=controlP5.addTextlabel("DISSOLVED OXYGEN VALUE","0.0",120,148);
  OxLabel=controlP5.addTextlabel("OXYGEN GAS VALUE","0.0",120,178);
  CO2Label=controlP5.addTextlabel("CARBON DIOXIDE GAS VALUE","0.0",120,208);

  SPLabel=controlP5.addTextlabel("SP","100.00",120,258);                  //
  PLabel=controlP5.addTextlabel("P","2.00",120,308);                    //
  ILabel=controlP5.addTextlabel("I","5.00",120,358);                    //
  DLabel=controlP5.addTextlabel("D","1.00",120,408);                    //

  SPField = controlP5.addTextfield("Setpoint").setPosition(10,255).setSize(80,20);         //   Buttons, Labels, and
  PField = controlP5.addTextfield("Kp (Proportional)").setPosition(10,305).setSize(80,20);          //
  IField = controlP5.addTextfield("Ki (Integral)").setPosition(10,355).setSize(80,20);          //
  DField = controlP5.addTextfield("Kd (Derivative)").setPosition(10,405).setSize(80,20);          //
  Submit = controlP5.addButton("Submit",0.0).setPosition(20,475).setSize(120,20);         //

  AxisFont = loadFont("axis.vlw");
  TitleFont = loadFont("Titles.vlw");

  nextRefresh=millis();
  if (outputFileName!="") output = createWriter(outputFileName);
}

void draw()
{
  background(200);
  drawGraph();
  drawButtonArea();
}

void drawGraph()
{
  //draw Base, gridlines
  stroke(0);
  fill(230);
  rect(ioLeft, inputTop,ioWidth-1 , inputHeight);
  rect(ioLeft, outputTop, ioWidth-1, outputHeight);
  stroke(210);

  //Section Titles
  textFont(TitleFont);
  fill(255);
  text("PID Input / Setpoint",(int)ioLeft+10,(int)inputTop-5);
  text("PID Output",(int)ioLeft+10,(int)outputTop-5);


  //GridLines and Titles
  textFont(AxisFont);
  //horizontal grid lines
  int interval = (int)inputHeight/6;
  for(int i=0;i<7;i++)
  {
    if(i>0&&i<6) line(ioLeft+1,inputTop+i*interval,ioRight-2,inputTop+i*interval);
    text(str((InScaleMax-InScaleMin)/6*(float)(6-i)+InScaleMin),ioRight+6,inputTop+i*interval+5);

  }
  interval = (int)outputHeight/5;
  for(int i=0;i<6;i++)
  {
    if(i>0&&i<5) line(ioLeft+1,outputTop+i*interval,ioRight-2,outputTop+i*interval);
    text(str((OutScaleMax-OutScaleMin)/5*(float)(5-i)+OutScaleMin),ioRight+5,outputTop+i*interval+4);
  }


  //vertical grid lines and TimeStamps
  int elapsedTime = millis();
  interval = (int)(ioWidth/vertCount);
  int shift = elapsedTime*(int)ioWidth / windowSpan;
  shift %=interval;

  int iTimeInterval = windowSpan/vertCount;
  float firstDisplay = (float)(iTimeInterval*(elapsedTime/iTimeInterval))/displayFactor;
  float timeInterval = (float)(iTimeInterval)/displayFactor;
  for(int i=0;i<vertCount;i++)
  {
    int x = (int)ioRight-shift-2-i*interval;

    line(x,inputTop+1,x,inputTop+inputHeight-1);
    line(x,outputTop+1,x,outputTop+outputHeight-1);

    float t = firstDisplay-(float)i*timeInterval;
    if(t>=0)  text(str(t),x,outputTop+outputHeight+10);
  }


  // add the latest data to the data Arrays.  the values need
  // to be massaged to get them to graph correctly.  they
  // need to be scaled to fit where they're going, and
  // because 0, 0 is the top left, we need to flip the values.
  // this is easier than having the user stand on their head
  // to read the graph.
  if(millis() > nextRefresh && madeContact)
  {
    nextRefresh += refreshRate;

    for(int i=nPoints-1;i>0;i--)
    {
      InputData[i]=InputData[i-1];
      SetpointData[i]=SetpointData[i-1];
      OutputData[i]=OutputData[i-1];
    }
    if (nPoints < arrayLength) nPoints++;

    InputData[0] = int(inputHeight)-int(inputHeight*(Input1-InScaleMin)/(InScaleMax-InScaleMin));
    SetpointData[0] =int( inputHeight)-int(inputHeight*(Setpoint1-InScaleMin)/(InScaleMax-InScaleMin));
    OutputData[0] = int(outputHeight)-int(outputHeight*(Output1-OutScaleMin)/(OutScaleMax-OutScaleMin));
  }
  //draw lines for the input, setpoint, and output
  strokeWeight(2);
  for(int i=0; i<nPoints-2; i++)
  {
    int X1 = int(ioRight-2-float(i)*pointWidth);
    int X2 = int(ioRight-2-float(i+1)*pointWidth);
    boolean y1Above, y1Below, y2Above, y2Below;


    //DRAW THE INPUT
    boolean drawLine=true;
    stroke(255,0,0);
    int Y1 = InputData[i];
    int Y2 = InputData[i+1];

    y1Above = (Y1>inputHeight);                     // if both points are outside
    y1Below = (Y1<0);                               // the min or max, don't draw the
    y2Above = (Y2>inputHeight);                     // line.  if only one point is
    y2Below = (Y2<0);                               // outside constrain it to the limit,
    if(y1Above)                                     // and leave the other one untouched.
    {                                               //
      if(y2Above) drawLine=false;                   //
      else if(y2Below) {                            //
        Y1 = (int)inputHeight;                      //
        Y2 = 0;                                     //
      }                                             //
      else Y1 = (int)inputHeight;                   //
    }                                               //
    else if(y1Below)                                //
    {                                               //
      if(y2Below) drawLine=false;                   //
      else if(y2Above) {                            //
        Y1 = 0;                                     //
        Y2 = (int)inputHeight;                      //
      }                                             //
      else Y1 = 0;                                  //
    }                                               //
    else                                            //
    {                                               //
      if(y2Below) Y2 = 0;                           //
      else if(y2Above) Y2 = (int)inputHeight;       //
    }                                               //

    if(drawLine)
    {
      line(X1,Y1+inputTop, X2, Y2+inputTop);
    }

    //DRAW THE SETPOINT
    drawLine=true;
    stroke(0,255,0);
    Y1 = SetpointData[i];
    Y2 = SetpointData[i+1];

    y1Above = (Y1>(int)inputHeight);                // if both points are outside
    y1Below = (Y1<0);                               // the min or max, don't draw the
    y2Above = (Y2>(int)inputHeight);                // line.  if only one point is
    y2Below = (Y2<0);                               // outside constrain it to the limit,
    if(y1Above)                                     // and leave the other one untouched.
    {                                               //
      if(y2Above) drawLine=false;                   //
      else if(y2Below) {                            //
        Y1 = (int)(inputHeight);                    //
        Y2 = 0;                                     //
      }                                             //
      else Y1 = (int)(inputHeight);                 //
    }                                               //
    else if(y1Below)                                //
    {                                               //
      if(y2Below) drawLine=false;                   //
      else if(y2Above) {                            //
        Y1 = 0;                                     //
        Y2 = (int)(inputHeight);                    //
      }                                             //
      else Y1 = 0;                                  //
    }                                               //
    else                                            //
    {                                               //
      if(y2Below) Y2 = 0;                           //
      else if(y2Above) Y2 = (int)(inputHeight);     //
    }                                               //

    if(drawLine)
    {
      line(X1, Y1+inputTop, X2, Y2+inputTop);
    }

    //DRAW THE OUTPUT
    drawLine=true;
    stroke(0,0,255);
    Y1 = OutputData[i];
    Y2 = OutputData[i+1];

    y1Above = (Y1>outputHeight);                   // if both points are outside
    y1Below = (Y1<0);                              // the min or max, don't draw the
    y2Above = (Y2>outputHeight);                   // line.  if only one point is
    y2Below = (Y2<0);                              // outside constrain it to the limit,
    if(y1Above)                                    // and leave the other one untouched.
    {                                              //
      if(y2Above) drawLine=false;                  //
      else if(y2Below) {                           //
        Y1 = (int)outputHeight;                    //
        Y2 = 0;                                    //
      }                                            //
      else Y1 = (int)outputHeight;                 //
    }                                              //
    else if(y1Below)                               //
    {                                              //
      if(y2Below) drawLine=false;                  //
      else if(y2Above) {                           //
        Y1 = 0;                                    //
        Y2 = (int)outputHeight;                    //
      }                                            //
      else Y1 = 0;                                 //
    }                                              //
    else                                           //
    {                                              //
      if(y2Below) Y2 = 0;                          //
      else if(y2Above) Y2 = (int)outputHeight;     //
    }                                              //

    if(drawLine)
    {
      line(X1, outputTop + Y1, X2, outputTop + Y2);
    }
  }
  strokeWeight(1);
}

void drawButtonArea()
{
  stroke(0);
  fill(100);
  rect(0, 0, ioLeft, windowHeight);
  fill(255);
  textFont(TitleFont);
  textSize(20);
  text("PID Control",(int)20,(int)30);
}

// Sending Floating point values to the arduino
// is a huge pain.  if anyone knows an easier
// way please let know.  the way I'm doing it:
// - Take the 6 floats we need to send and
//   put them in a 6 member float array.
// - using the java ByteBuffer class, convert
//   that array to a 24 member byte array
// - send those bytes to the arduino
void Submit(){
  println("Clicked");
  float[] toSend = new float[4];
  toSend[0] = float(SPField.getText());
  toSend[1] = float(PField.getText());
  toSend[2] = float(IField.getText());
  toSend[3] = float(DField.getText());
  myPort.write(floatArrayToByteArray(toSend));
  println(toSend[0], toSend[1], toSend[2], toSend[3]);
  println("Sent Data");
  justSent=true;
}


byte[] floatArrayToByteArray(float[] input)
{
  int len = 4*input.length;
  //int index=0;
  byte[] b = new byte[4];
  byte[] out = new byte[len];
  ByteBuffer buf = ByteBuffer.wrap(b);
  for(int i=0;i<input.length;i++) 
  {
    buf.position(0);
    buf.putFloat(input[i]);
    for(int j=0;j<4;j++) out[j+i*4]=b[3-j];
  }
  return out;
}


void serialEvent(Serial myPort)
{
  String read = myPort.readStringUntil('\n');
  if(outputFileName!="") output.print(str(millis())+ " "+read);
  String[] s = split(read, " ");
  if (s.length == 12)
  {
    Setpoint1 = float(s[2]);           // * pull the information
    Input1 = float(s[3]);              //   we need out of the
    Output1 = float(s[4]);             //   string and put it
    SPLabel.setValue(s[2]);           //   where it's needed
    InLabel.setValue(s[3]);           //
    OutLabel.setValue(trim(s[4]));    //
    PLabel.setValue(trim(s[5]));      //
    ILabel.setValue(trim(s[6]));      //
    DLabel.setValue(trim(s[7]));      //
    TempLabel.setValue(trim(s[8]));      //
    DissOxLabel.setValue(trim(s[9]));      //
    OxLabel.setValue(trim(s[10]));      //
    CO2Label.setValue(trim(s[11]));      //
    
    if(justSent)                      // * if this is the first read
    {                                 //   since we sent values to 
      SPField.setText(trim(s[2]));    //   the arduino,  take the
      //InField.setText(trim(s[2]));    //   current values and put
      //OutField.setText(trim(s[3]));   //   them into the input fields
      PField.setText(trim(s[5]));     //
      IField.setText(trim(s[6]));     //
      DField.setText(trim(s[7]));     //
      justSent=false;                 //
    }                                 //

    if(!madeContact) madeContact=true;
  }
}

void controlEvent(ControlEvent theEvent) {
  if(theEvent.isAssignableFrom(Textfield.class)) {
    println("controlEvent: accessing a string from controller '"
            +theEvent.getName()+"': "
            +theEvent.getStringValue()
            );
  }
}