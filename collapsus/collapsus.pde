/*
 *    Collapsus - Image Stack Differencing
 *    By Masood Kamandy 2011
 *    Additional development by Gottfried Haider 2012
 *
 *    This program compares a series of photographs to a base image. If the pixels change beyond
 *    the set threshold, the pixels are added to a final image, which is the output of the program.
 *
 *    Foobar is free software: you can redistribute it and/or modify it under the terms of the 
 *    GNU General Public License as published by the Free Software Foundation, either version 3 of 
 *    the License, or (at your option) any later version.
 */

// Apologies for the hackish code, hope we can clean this up later :) 
// TODO: include controlP5, FullScreen API For Processing with the sketch

PApplet papplet = this;
import controlP5.*;
ControlP5 cp5;
import fullscreen.*;
SoftFullScreen fs;
Collapse cl;
boolean publish = false;
boolean result = false;
boolean success = false;


void setup()
{
  size(screenWidth, screenHeight, P2D);
  fs = new SoftFullScreen(this);
  fs.enter();
  
  cp5 = new ControlP5(this);
  cp5.setFont(ControlP5.standard56);
  setupDirSelector(dataPath("sample"), null);
}


boolean armMouse = false;    // true if we moved the mouse during the previous frame
int prevMousemove = 0;       // timestamp of when rendering was paused

void draw()
{
  if (cl == null) {
    drawDirSelector();
    return;
  } else if (publish) {
    drawPublishForm();
    return;
  } else if (result) {
    drawResultScreen();
    return;
  }
  
  // stop calculating frames when we've been moving the mouse lately
  if (mouseX != pmouseX || mouseY != pmouseY) {
    if (0 < prevMousemove || armMouse) {
      prevMousemove = millis();
    } else {
      armMouse = true;
    }
  } else {
    armMouse = false;
  }
  
  boolean calculate = true;
  if (0 < prevMousemove) {
    if (millis()-prevMousemove < 1000) {
      calculate = false;
    } else {
      prevMousemove = 0;
      armMouse = false;
    }
  }
  if (calculate) {
    cl.next();
  }
  
  cl.draw();
  drawUI();
}


//
//  Directory Selector
//

PImage baseImg;                          // background image
PImage[] previewImg = new PImage[3];     // three preview images 
ArrayList blendImgFn = new ArrayList();  // list of absolute filenames to compare against baseImg


// needle is the (relative) filename to use or the base image, can be null
boolean setupDirSelector(String path, String needle)
{
  File dir = new File(path);
  String[] children = dir.list();
  if (children == null) {
    println("Cannot open directory "+path);
    return false;
  }
  
  // clear a previous selection
  baseImg = null;
  for (int i=0; i < previewImg.length; i++) {
    previewImg[i] = null;
  }
  blendImgFn.clear();
  
  // iterate over the directory content
  for (int i=0; i < children.length; i++) {
    if (needle == null && baseImg == null) {
      // pick the first best image as background
      PImage tmp = loadImage(path+"/"+children[i]);
      if (tmp != null) {
        baseImg = tmp;
      }
    } else if (needle != null && needle.equals(children[i])) {
      // or the one we are looking for
      PImage tmp = loadImage(path+"/"+children[i]);
      if (tmp != null) {
        baseImg = tmp;
      } else {
        println("Cannot load background "+path+"/"+children[i]);
      }
    } else {
      // check file extension and add to the blend list
      int dot = children[i].lastIndexOf('.');
      if (dot == -1) {
        continue;
      }
      String ext = children[i].substring(dot+1).toLowerCase();
      if (ext.equals("gif") || ext.equals("jpg") || ext.equals("tga") || ext.equals("png")) {
        blendImgFn.add(path+"/"+children[i]);
        // use for preview if necessary
        for (int j=0; j < previewImg.length; j++) {
          if (previewImg[j] == null) {
            previewImg[j] = loadImage(path+"/"+children[i]);
            break;
          }
        }
      }
    }
  }
  return true;
}


void drawDirSelector()
{
  background(0);
  
  // preview
  fill(0);
  stroke(255);
  rect(screenWidth*0.30, screenHeight*0.35-260/8, 260/3, 260/4);
  if (baseImg != null) {
    image(baseImg, screenWidth*0.30+1, screenHeight*0.35-260/8+1, 260/3-1, 260/4-1);  
  }
  for (int i=0; i < 3; i++) {
    rect(screenWidth*0.30+i*10, screenHeight*0.55-200/8+i*10, 200/3, 200/4);
    if (previewImg[i] != null) {
      image(previewImg[i], screenWidth*0.30+i*10+1, screenHeight*0.55-200/8+i*10+1, 200/3-1, 200/4-1);
    }
  }
  fill(255);
  stroke(0);
  textAlign(RIGHT);
  text(blendImgFn.size()+" total", screenWidth*0.30+200/3+20, screenHeight*0.55+200/3);
  
  // controls
  if (cp5.get("dirSelectorBtn") == null) {
    // clear controls
    cp5.remove(this);
    // BUG: remove() should take care of this as well
    if (cp5.getGroup("blendModeLst") != null) {
      cp5.getGroup("blendModeLst").remove(); 
    }
    if (cp5.getGroup("startFrameLst") != null) {
      cp5.getGroup("startFrameLst").remove();
    }
    if (cp5.getGroup("useWindowRb") != null) {
      cp5.getGroup("useWindowRb").remove(); 
    }
    if (cp5.getGroup("outputRb") != null) {
      cp5.getGroup("outputRb").remove(); 
    }
    
    Button b = cp5.addButton("dirSelectorBtn")
                  .setCaptionLabel("Select a different background image")
                  .setPosition(screenWidth*0.50, screenHeight*0.35-260/8)
                  .setSize(210, 20);
    b = cp5.addButton("startBtn")
                  .setCaptionLabel("Start >")
                  .setPosition(screenWidth*0.50, screenHeight*0.55-200/8+25)
                  .setSize(88, 20);
    b.getCaptionLabel().align(CENTER, CENTER);
  }
  // enable and disable the start button
  if (baseImg == null || blendImgFn.size() < 1) {
    cp5.getController("startBtn").lock();
  } else {
    cp5.getController("startBtn").unlock();
  }  
  textAlign(LEFT);
  text("All other images in the directory will be used for comparison", screenWidth*0.50, screenHeight*0.35-260/8+40);
  
  // label
  textAlign(RIGHT);
  text("Collapsus 1.0", screenWidth-20, screenHeight-20);
}


void dirSelectorBtn()
{
  String fn = selectInput("Select a background image");
  if (fn != null) {
    File f = new File(fn);
    setupDirSelector(f.getParent(), f.getName());
  }
}


void startBtn()
{
  // instantiate main class
  cl = new Collapse(baseImg, blendImgFn);
}


//
//  Publish
//

void drawPublishForm()
{
  background(0);

  // controls
  if (cp5.get("submitBtn") == null) {
    // clear controls
    cp5.remove(this);
    // BUG: remove() should take care of this as well
    if (cp5.getGroup("blendModeLst") != null) {
      cp5.getGroup("blendModeLst").remove(); 
    }
    if (cp5.getGroup("startFrameLst") != null) {
      cp5.getGroup("startFrameLst").remove(); 
    }
    if (cp5.getGroup("useWindowRb") != null) {
      cp5.getGroup("useWindowRb").remove(); 
    }
    if (cp5.getGroup("outputRb") != null) {
      cp5.getGroup("outputRb").remove(); 
    }
    
    cp5.addTextfield("author")
       .setPosition(screenWidth/2+50, screenHeight/2-200)
       .setSize(200, 16)
       .setFocus(true);
    
    CheckBox cb = cp5.addCheckBox("showAuthor")
                     .setPosition(screenWidth/2+50, screenHeight/2-150)
                     .addItem("Show name on site beneath image for credit", 0);
    cb.activate(0);
    
    cp5.addTextfield("title")
       .setPosition(screenWidth/2+50, screenHeight/2-100)
       .setSize(200, 16)
       .setLabel("Image title");
    
    cp5.addTextfield("location")
       .setPosition(screenWidth/2+50, screenHeight/2-50)
       .setSize(200, 16);
    
    cp5.addTextfield("camera")
       .setPosition(screenWidth/2+50, screenHeight/2)
       .setSize(200, 16)
       .setLabel("Camera / Imaging Device Used");

    cp5.addTextfield("email")
       .setPosition(screenWidth/2+50, screenHeight/2+50)
       .setSize(200, 16)
       .setLabel("Email address");
    
    cp5.addCheckBox("newsletter")
                     .setPosition(screenWidth/2+50, screenHeight/2+100)
                     .addItem("I would like to receive updates via email about Collapsus", 0);
    
    cp5.addTextlabel("note")
       .setText("IMAGES CREATED WITH 'COLLAPSUS' WILL ALWAYS BE OWNED BY YOU. BY PUBLISHING TO THE COLLAPSUS WEBSITE, YOU ARE GIVING US PERMISSION TO DISPLAY YOUR WORK ON THE SITE. FROM JUNE 9, 2012 UNTIL SEPTEMBER 16, 2012, THE PHOTOGRAPHS THAT ARE SUBMITTED AND ARE FEATURED WILL BE SCREENED ON ROTATING ON A MONITOR AT THE DOCUMENTA(13) EXHIBITION IN KASSEL, GERMANY.")
       .setPosition(screenWidth/2+50, screenHeight/2+150)
       .setSize(screenWidth/2-150, screenHeight/2-100)
       .setMultiline(true)
       .setFont(ControlP5.standard56);
    
    cp5.addButton("submitBtn")
       .setCaptionLabel("Submit")
       .setPosition(screenWidth/2+50, screenHeight/2+225)
       .setSize(100, 20);
  }
  
  // scale and display thumbnail
  PImage img = cl.out;
  int w = cl.out.width;
  int h = cl.out.height;
  float aspect = (float)w/h;
  if (w < h) {
    h = 400;
    w = (int)(h*aspect);
  } else {
    w = 400;
    h = (int)(w/aspect);
  }
  image(img, screenWidth/2-450, screenHeight/2-200, w, h);
}


void submitBtn()
{
  // write to temporary file
  File f = new File(savePath(".upload.png"));
  f.delete();
  cl.out.save(savePath(".upload.png"));
  byte b[] = loadBytes(".upload.png");
  if (b == null) {
    return;
  }
  
  boolean ret = false;
  try{
    URL u = new URL("http://collapsus.org/upload.php");
    URLConnection c = u.openConnection();
    
    c.setDoOutput(true);
    c.setDoInput(true);
    c.setUseCaches(false);
    
    // set request headers
    c.setRequestProperty("Content-Type", "multipart/form-data; boundary=AXi93A");
    
    // open a stream which can write to the url
    DataOutputStream dstream = new DataOutputStream(c.getOutputStream());
    
    Textfield t = (Textfield)cp5.get("author");
    dstream.writeBytes("--AXi93A\r\n");
    dstream.writeBytes("Content-Disposition: form-data; name=\"author\"\r\n\r\n");
    dstream.writeBytes(t.getText()+"\r\n");
    dstream.writeBytes("--AXi93A\r\n");
    
    CheckBox cb = (CheckBox)cp5.get("showAuthor");
    dstream.writeBytes("--AXi93A\r\n");
    dstream.writeBytes("Content-Disposition: form-data; name=\"show_author\"\r\n\r\n");
    if (cb.getState(0) == true) {
      dstream.writeBytes("1\r\n");
    } else {
      dstream.writeBytes("0\r\n");      
    }
    dstream.writeBytes("--AXi93A\r\n");
    
    t = (Textfield)cp5.get("title");
    dstream.writeBytes("--AXi93A\r\n");
    dstream.writeBytes("Content-Disposition: form-data; name=\"title\"\r\n\r\n");
    dstream.writeBytes(t.getText()+"\r\n");
    dstream.writeBytes("--AXi93A\r\n");
    
    t = (Textfield)cp5.get("location");
    dstream.writeBytes("--AXi93A\r\n");
    dstream.writeBytes("Content-Disposition: form-data; name=\"location\"\r\n\r\n");
    dstream.writeBytes(t.getText()+"\r\n");
    dstream.writeBytes("--AXi93A\r\n");
    
    t = (Textfield)cp5.get("camera");
    dstream.writeBytes("--AXi93A\r\n");
    dstream.writeBytes("Content-Disposition: form-data; name=\"camera\"\r\n\r\n");
    dstream.writeBytes(t.getText()+"\r\n");
    dstream.writeBytes("--AXi93A\r\n");
    
    t = (Textfield)cp5.get("location");
    dstream.writeBytes("--AXi93A\r\n");
    dstream.writeBytes("Content-Disposition: form-data; name=\"location\"\r\n\r\n");
    dstream.writeBytes(t.getText()+"\r\n");
    dstream.writeBytes("--AXi93A\r\n");

    t = (Textfield)cp5.get("email");
    dstream.writeBytes("--AXi93A\r\n");
    dstream.writeBytes("Content-Disposition: form-data; name=\"email\"\r\n\r\n");
    dstream.writeBytes(t.getText()+"\r\n");
    dstream.writeBytes("--AXi93A\r\n");
    
    cb = (CheckBox)cp5.get("newsletter");
    dstream.writeBytes("--AXi93A\r\n");
    dstream.writeBytes("Content-Disposition: form-data; name=\"newsletter\"\r\n\r\n");
    if (cb.getState(0) == true) {
      dstream.writeBytes("1\r\n");
    } else {
      dstream.writeBytes("0\r\n");      
    }
    dstream.writeBytes("--AXi93A\r\n");
    
    dstream.writeBytes("--AXi93A\r\n");
    dstream.writeBytes("Content-Disposition: form-data; name=\"image\"; filename=image.png\r\nContent-Type: image/png\r\nContent-Transfer-Encoding: binary\r\n\r\n");
    dstream.write(b, 0, b.length);
    dstream.writeBytes("\r\n--AXi93A--\r\n\r\n");
    dstream.flush();
    dstream.close();
    
    // read the output from the URL
    try{
      BufferedReader in = new BufferedReader(new InputStreamReader(c.getInputStream()));
      String l = in.readLine();
      if (l != null && 0 < l.length()) {
        ret = true;
        println("Server returned "+l);
      }
    } catch(Exception e) {
      e.printStackTrace();
    }
  } catch(Exception e) {
    e.printStackTrace();
  }
  
  // delete file again
  if (ret) {
    f = new File(savePath(".upload.png"));
    f.delete();
  }
  
  publish = false;
  result = true;
  success = ret;
}


//
//  Result
//

void drawResultScreen()
{
  background(0);
  
  // controls
  if (cp5.get("backBtn2") == null) {
    // clear controls
    cp5.remove(this);
    // BUG: remove() should take care of this as well
    if (cp5.getGroup("blendModeLst") != null) {
      cp5.getGroup("blendModeLst").remove(); 
    }
    if (cp5.getGroup("startFrameLst") != null) {
      cp5.getGroup("startFrameLst").remove(); 
    }
    if (cp5.getGroup("useWindowRb") != null) {
      cp5.getGroup("useWindowRb").remove(); 
    }
    if (cp5.getGroup("outputRb") != null) {
      cp5.getGroup("outputRb").remove(); 
    }
    
    Button b = cp5.addButton("backBtn2")
            .setCaptionLabel("Back")
            .setPosition(screenWidth/2+50, screenHeight/2+90)
            .setSize(100, 20);
  }
  
  textAlign(LEFT);
  fill(255);
  noStroke();
  if (success) {
    text("Success", screenWidth/2+50, screenHeight/2);
    text("Thanks for uploading your image to http://collapsus.org/.", screenWidth/2+50, screenHeight/2+50);
  } else {
    text("Error", screenWidth/2+50, screenHeight/2);
    text("Something went wrong uploading your image. Please try again later or manually send us the image by email.", screenWidth/2+50, screenHeight/2+50);
  }
}


void backBtn2() {
  cl = null;
}



//
//  Main
//

void drawUI()
{
  // background for the controls
  fill(0, 0, 0, 200);
  noStroke();
  rect(screenWidth-140, 0, 140, screenHeight);
  
  // controls
  if (cp5.get("backBtn") == null) {
    // clear controls
    cp5.remove(this);
    // BUG: remove() should take care of this as well
    if (cp5.getGroup("blendModeLst") != null) {
      cp5.getGroup("blendModeLst").remove(); 
    }
    if (cp5.getGroup("startFrameLst") != null) {
      cp5.getGroup("startFrameLst").remove(); 
    }
    if (cp5.getGroup("useWindowRb") != null) {
      cp5.getGroup("useWindowRb").remove(); 
    }
    if (cp5.getGroup("outputRb") != null) {
      cp5.getGroup("outputRb").remove(); 
    }
    
    // the order of controls is important here for overlapping
    
    cp5.addTextlabel("completeLabel")
       .setText("0%")
       .setPosition(20, screenHeight-25);
    
    Button b;
    b = cp5.addButton("avgBtn")
           .setCaptionLabel("Show Average")
           .setPosition(screenWidth-120, 207)
           .setSize(100, 20);
    
    b.getCaptionLabel().align(CENTER, CENTER);
    b = cp5.addButton("backBtn")
            .setCaptionLabel("Back")
            .setPosition(screenWidth-120, screenHeight-120)
            .setSize(100, 20);
    b.getCaptionLabel().align(CENTER, CENTER);
    b = cp5.addButton("saveBtn")
            .setCaptionLabel("Save image")
            .setPosition(screenWidth-120, screenHeight-80)
            .setSize(100, 20);
    b.getCaptionLabel().align(CENTER, CENTER);
    b = cp5.addButton("uploadBtn")
            .setCaptionLabel("Submit image")
            .setPosition(screenWidth-120, screenHeight-40)
            .setSize(100, 20);
    b.getCaptionLabel().align(CENTER, CENTER);
    
    cp5.addTextlabel("outputLabel")
       .setText("OUTPUT")
       .setPosition(screenWidth-120, 354);
    
    RadioButton r = cp5.addRadioButton("outputRb")
                       .setPosition(screenWidth-120, 375)
                       .setSize(10, 9)
                       .addItem("INDIVIDUAL FRAMES", 0);
                       //.addItem("MOVIE", 1);
    
    //cp5.addTextlabel("fpsLabel")
    //   .setText("SECS PER FRAME")
    //   .setPosition(screenWidth-120, 390);
    
    //Slider s = cp5.addSlider("fpsSlider")
    //              .setPosition(screenWidth-120, 405)
    //              .setRange(0.1, 10)
    //              .setSize(100, 20)
    //              .setValue(1.0);
    //s.getCaptionLabel().hide();
    
    cp5.addTextlabel("useWindowRbLabel")
       .setText("LOOK AT")
       .setPosition(screenWidth-120, 270);
    
    r = cp5.addRadioButton("useWindowRb")
                       .setPosition(screenWidth-120, 291)
                       .setSize(10, 9)
                       .addItem("ALL IMAGES", 0)
                       .addItem("A NUMBER AT A TIME", 1);
    r.activate(0);
    
    Slider s = cp5.addSlider("windowSlider")
                  .setPosition(screenWidth-120, 312)
                  .setRange(2, 100)
                  .setSize(100, 20)
                  .setValue(2);
    s.getCaptionLabel().hide();
    
    cp5.addTextlabel("threshSliderLabel")
       .setText("THRESHOLD")
       .setPosition(screenWidth-120, 81);
       
    s = cp5.addSlider("threshSlider")
                  .setPosition(screenWidth-120, 102)
                  .setRange(0, 765)
                  .setSize(100, 20)
                  .setValue(cl.getThresh());
    s.getCaptionLabel().hide();
    
    cp5.addTextlabel("blendModeLstLabel")
       .setText("BLEND USING")
       .setPosition(screenWidth-120, 144);
    
    DropdownList ddl = cp5.addDropdownList("blendModeLst")
                          .setPosition(screenWidth-120, 186)
                          .setSize(100, screenHeight-180-20-20)
                          .setBarHeight(20)
                          .setItemHeight(20);
    ddl.captionLabel().set("Blend mode");
    ddl.captionLabel().style().marginTop = 6;
    String[] modes = cl.blendModes();
    for (int i=0; i < modes.length; i++) {
      ddl.addItem(modes[i], i);
      if (modes[i].equals(cl.getBlendMode())) {
        ddl.setIndex(i);
      }
    }
    
    cp5.addTextlabel("startFrameLstLabel")
    .setText("START WITH")
    .setPosition(screenWidth-120, 20);
       
    ddl = cp5.addDropdownList("startFrameLst")
             .setPosition(screenWidth-120, 60)
             .setSize(100, screenHeight-60-20-20)
             .setBarHeight(20)
             .setItemHeight(20);
    ddl.captionLabel().set("Start with");
    ddl.captionLabel().style().marginTop = 6;
    ddl.addItem("Black", 0);
    if (cl.getFirstFrame().equals("black")) {
      ddl.setIndex(0);
    }
    ddl.addItem("50% Grey", 1);
    if (cl.getFirstFrame().equals("50% grey")) {
      ddl.setIndex(1);
    }
    ddl.addItem("White", 2);
    if (cl.getFirstFrame().equals("white")) {
      ddl.setIndex(2);
    }
    ddl.addItem("Background", 3);
    if (cl.getFirstFrame().equals("background")) {
      ddl.setIndex(3);
    }
    ddl.addItem("Alpha", 4);
    if (cl.getFirstFrame().equals("alpha")) {
      ddl.setIndex(4);
    }
  }
  
  // hide average button when we're in that mode
  Button b = (Button)cp5.get("avgBtn");
  if (cl.isAvg()) {
    b.setVisible(false);
  } else {
    b.setVisible(true);
  }
  // restore button labels
  b = (Button)cp5.get("saveBtn");
  b.setCaptionLabel("Save image");
  b = (Button)cp5.get("uploadBtn");
  b.setCaptionLabel("Submit image");
  // update percentage
  Textlabel tl = (Textlabel)cp5.get("completeLabel");
  tl.setText(cl.getProgressString());
}


void controlEvent(ControlEvent e) {
  // handle the dropdown lists
  if (e.getName().equals("blendModeLst")) {
    DropdownList ddl = (DropdownList)e.getGroup();
    if (cl != null) {
      cl.setBlendMode(ddl.getItem((int)ddl.getValue()).getText());
      cl.reset();
    }
  } else if (e.getName().equals("startFrameLst")) {
    DropdownList ddl = (DropdownList)e.getGroup();
    if (cl != null) {
      cl.setFirstFrame(ddl.getItem((int)ddl.getValue()).getText());
      cl.reset();
    }
  }
}


void threshSlider(float val)
{
  if (cl != null) {
    cl.setThresh((int)val);
    cl.reset();
  }
}


void useWindowRb(int val)
{
  if (val == 0) {
    cl.setWindow(0);
  } else if (val == 1) {
    Slider s = (Slider)(cp5.get("windowSlider"));
    cl.setWindow((int)s.getValue());
  } else {
    RadioButton rb = (RadioButton)(cp5.get("useWindowRb"));
    rb.activate(0);
  }
}


void windowSlider(float val)
{
  RadioButton rb = (RadioButton)(cp5.get("useWindowRb"));
  if (rb.getValue() == 1.0) {
    cl.setWindow((int)val);
  }
}


void outputRb(int val)
{
  if (val == 0) {
    cl.setOutput(true, false, 0.0);
  } else if (val == 1) {
    Slider s = (Slider)cp5.get("fpsSlider");
    cl.setOutput(false, true, 1.0/s.getValue());
  } else {
    cl.setOutput(false, false, 0.0);
  }
}


void fpsSlider(float val)
{
  RadioButton rb = (RadioButton)(cp5.get("outputRb"));
  if (rb.getValue() == 1.0) {
    cl.setOutput(false, true, 1.0/val);
  }
}


void avgBtn()
{
  cl.requestAvg();
}


void backBtn()
{
  cl = null;
}


void saveBtn()
{
  cl.saveImage();
  // visual notification (not visible when changed before saving and back afterwards)
  Button b = (Button)cp5.get("saveBtn");
  b.setCaptionLabel("Done");
}


void uploadBtn()
{
  publish = true;
  /*
  if (cl.uploadImage()) {
    Button b = (Button)cp5.get("uploadBtn");
    b.setCaptionLabel("Success");
  } else {
    Button b = (Button)cp5.get("uploadBtn");
    b.setCaptionLabel("Error");    
  }
  */
}


//
//  Main Class
//

class Collapse
{
  PImage bg;
  ArrayList files;
  int cur;
  PImage out;
  PImage[] buffer;
  int inBuffer;
  String name;
  // tweakables
  int bufferSize;
  String firstMode;
  int thresh;
  String threshMode;
  String blendMode;
  boolean saveFrames;
  boolean saveMovie;
  float saveMovieFps;
  boolean requestAvg;
  boolean doAvg;
  int[] avgSumA;
  int[] avgSumR;
  int[] avgSumG;
  int[] avgSumB;
  
  Collapse(PImage _bg, ArrayList _files)
  {
    bg = _bg;
    bg.loadPixels();
    files = _files;
    // tweakables
    bufferSize = 0;
    firstMode = "background";
    thresh = 0;
    threshMode = "binary";
    blendMode = "difference";
    saveFrames = false;
    //saveMovie = false;
    //saveMovieFps = 0.0;
    requestAvg = false;
    doAvg = false;
    reset();
  }
  
  void reset()
  {
    cur = 0;
    out = new PImage(bg.width, bg.height, ARGB);
    if (0 < bufferSize) {
      buffer = new PImage[bufferSize];
      inBuffer = 0;
    } else {
      buffer = null;
      inBuffer = 0;
    }
    name = String.format("%04d", year())+String.format("%02d", month())+String.format("%02d", day())+String.format("%02d", hour())+String.format("%02d", minute())+String.format("%02d", second());
    if (requestAvg) {
      doAvg = true;
      requestAvg = false;
      avgSumA = new int[bg.width*bg.height];
      avgSumR = new int[bg.width*bg.height];
      avgSumG = new int[bg.width*bg.height];
      avgSumB = new int[bg.width*bg.height];
    } else {
      doAvg = false;
      avgSumA = null;
      avgSumR = null;
      avgSumG = null;
      avgSumB = null;
    }
  }
  
  boolean next()
  {
    if (files.size() < cur) {
      // finished
      return false;
    }
   
    if (doAvg) {
      nextAvg();
    } else {
      nextDifference();
    }
    
    // save individual frames
    if (saveFrames) {
      out.save(savePath(name+"_"+String.format("%03d", cur)+".tga"));
    }
    
    cur++;
    return true;
  }
  
  private void nextAvg()
  {
    PImage curFrame;
    
    if (cur == 0) {
      curFrame = bg;
    } else {
      curFrame = loadFrame((String)files.get(cur-1));
      if (curFrame == null) {
        return;
      }
    }
    
    // add current frame to sum
    for (int i=0; i < bg.width * bg.height; i++) {
      avgSumA[i] += curFrame.pixels[i] >> 24;
      avgSumR[i] += (curFrame.pixels[i] >> 16) & 0xff;
      avgSumG[i] += (curFrame.pixels[i] >> 8) & 0xff;
      avgSumB[i] += curFrame.pixels[i] & 0xff;
    }
    
    // output average
    out.loadPixels();
    for (int i=0; i < bg.width * bg.height; i++) {
      out.pixels[i] = ((avgSumA[i] / (cur + 1)) & 0xff) << 24 | ((avgSumR[i] / (cur + 1)) & 0xff) << 16 | ((avgSumG[i] / (cur + 1)) & 0xff) << 8 | ((avgSumB[i] / (cur + 1)) & 0xff);
    }
    out.updatePixels();
  }
  
  private void nextDifference()
  {
    if (cur == 0) {
      // special case for the first frame
      out = first();
      if (0 < bufferSize) {
        buffer[0] = first();
        buffer[0].loadPixels();
        inBuffer++;
      }
      return;
    }
    
    // load file
    PImage curFrame = loadFrame((String)files.get(cur-1));
    if (curFrame == null) {
      return;
    }
    
    // handle sliding window
    // shift array
    for (int i=inBuffer-1; 0 <= i; i--) {
      if (i+1 < bufferSize) {
        buffer[i+1] = buffer[i];
      }
    }
   // add a blank frame
    if (0 < bufferSize) {
      buffer[0] = first();
      buffer[0].loadPixels();
      if (inBuffer < bufferSize) {
        inBuffer++;
      }
    }
    
    // compare with background
    PImage screenFrame = new PImage(bg.width, bg.height, ARGB);
    screenFrame.loadPixels();
    for (int i=0; i < bg.width * bg.height; i++) {
      screenFrame.pixels[i] = comparePixels(bg.pixels[i], curFrame.pixels[i]);
    }
    
    // blend with aggregate output
    if (bufferSize == 0) {
      out.loadPixels();
      for (int i=0; i < bg.width * bg.height; i++) {
        out.pixels[i] = blendPixels(out.pixels[i], screenFrame.pixels[i]);
      }
      out.updatePixels();
    }
    
    // sliding window blend
    for (int i=0; i < inBuffer; i++) {
      for (int j=0; j < bg.width * bg.height; j++) {
        buffer[i].pixels[j] = blendPixels(buffer[i].pixels[j], screenFrame.pixels[j]);
      }
    }
    // output oldest image in buffer in this case
    if (0 < inBuffer) {
      buffer[inBuffer-1].updatePixels();
      out = buffer[inBuffer-1];
    }
  }
  
  private PImage loadFrame(String fn)
  {
    PImage ret = loadImage(fn);
    if (ret == null) {
      return null;
    }
    if (ret.width != bg.width || ret.height != bg.height) {
      // intelligent resize and center
      PImage tmp = createImage(bg.width, bg.height, ARGB);
      int w, h;
      if (bg.width - ret.width < bg.height - ret.height) {
        w = bg.width;
        h = (int)(w * ((float)ret.height / ret.width));
      } else {
        h = bg.height;
        w = (int)(h * ((float)ret.width / ret.height));      
      }
      tmp.copy(ret, 0, 0, ret.width, ret.height, floor((bg.width - w) / 2), floor((bg.height - h) / 2), w, h);
      ret = tmp;
    }
    ret.loadPixels();
    return ret;
  }
  
  private PImage first()
  {
    PImage img = new PImage(bg.width, bg.height, ARGB);
    if (firstMode.equals("50% grey")) {
      img.loadPixels();
      for (int i=0; i < img.width * img.height; i++) {
        img.pixels[i] = (255 << 24) | (127 << 16) | (127 << 8) | (127);
      }
      img.updatePixels();
    } else if (firstMode.equals("white")) {
      img.loadPixels();
      for (int i=0; i < img.width*img.height; i++) {
        img.pixels[i] = (255 << 24) | (255 << 16) | (255 << 8) | (255);
      }
      img.updatePixels();
    } else if (firstMode.equals("background")) {
      img.copy(bg, 0, 0, bg.width, bg.height, 0, 0, img.width, img.height);
    } else if (firstMode.equals("alpha")) {
      // do nothing
    } else {
      // black
      img.loadPixels();
      for (int i=0; i < img.width*img.height; i++) {
        img.pixels[i] = (255 << 24);
      }
      img.updatePixels();
    }
    return img;
  }
  
  private int comparePixels(int a, int b)
  {
    // a is base/background
    // b is blend
    
    // old behavior:
    // alpha is 255 or 0 if at least one of the channels differs more than threshAlpha
    // color channels are considered individually, if the difference is not large enough the channel get's set to 0 (black)
    
    // apart from alpha 255 (which excludes it in the blending) we could also return black or white
    // or make the alpha ..
    
    int _a[] = new int[4];
    int _b[] = new int[4];
    for (int i=0; i < 4; i++) {
      _a[i] = (a >> ((3 - i) * 8)) & 0xff;
      _b[i] = (b >> ((3 - i) * 8)) & 0xff;
    }
    
    int diff = abs(_a[1] - _b[1]) + abs(_a[2] - _b[2]) + abs(_a[3] + _b[3]);
    
    if (threshMode == "proportional") {
      if (0 < thresh && diff < thresh) {
        // return alpha 0 if the difference to the background is not large enough
        return 0;
      } else {
        if (0 < thresh) {
          // ceil is to prevent we're rounding to zero here
          int alpha = ceil(255 * (((float)diff - thresh) / (765 - thresh)));
          return (alpha << 24) | (_b[1] << 16) | (_b[2] << 8) | _b[3];
        } else {
          return b;
        }
      }     
    } else {
      // binary
      if (0 < thresh && diff < thresh) {
        // return alpha 0 if the difference to the background is not large enough
        return 0;
      } else {
        return b;
      }
    }
  }
  
  private int blendPixels(int a, int b)
  {
    // see http://www.pegtop.net/delphi/articles/blendmodes/index.htm
    // a is base/background
    // b is blend
    int _a[] = new int[4];
    int _b[] = new int[4];
    int _c[] = new int[4];
    for (int i=0; i < 4; i++) {
      _a[i] = (a >> ((3 - i) * 8)) & 0xff;
      _b[i] = (b >> ((3 - i) * 8)) & 0xff;
    }
    
    // not sure if this logic is right
    if (_a[0] == 0 && _b[0] == 0) {
      return 0;
    } else if (_a[0] == 0) {
      return b;
    } else if (_b[0] == 0) {
      return a;
    }
    
    if (blendMode.equals("normal")) {
      for (int i=1; i < 4; i++) {
        _c[i] = _b[i];
      }
    } else if (blendMode.equals("average")) {
      for (int i=1; i < 4; i++) {
        _c[i] = (_a[i] + _b[i]) >> 1;
      }
    } else if (blendMode.equals("multiply")) {
      // does not work very well
      for (int i=1; i < 4; i++) {
        _c[i] = (_a[i] * _b[i]) >> 8;
      }
    } else if (blendMode.equals("screen")) {
      for (int i=1; i < 4; i++) {
        _c[i] = 255 - ((255 - _a[i]) * (255 - _b[i]) >> 8);
      }
    } else if (blendMode.equals("darken")) {
      // does not work very well
      for (int i=1; i < 4; i++) {
        if (_a[i] < _b[i]) {
          _c[i] = _a[i];
        } else {
          _c[i] = _b[i];
        }
      }
    } else if (blendMode.equals("lighten")) {
      for (int i=1; i < 4; i++) {
        if (_a[i] < _b[i]) {
          _c[i] = _b[i];
        } else {
          _c[i] = _a[i];
        }
      }
    } else if (blendMode.equals("difference")) {
      for (int i=1; i < 4; i++) {
        _c[i] = abs(_a[i] - _b[i]);
      }
    } else if (blendMode.equals("negation")) {
      for (int i=1; i < 4; i++) {
        _c[i] = 255 - abs(255 - _a[i] - _b[i]);
      }
    } else if (blendMode.equals("exclusion")) {
      for (int i=1; i < 4; i++) {
        _c[i] = _a[i] + _b[i] - (_a[i] * _b[i] >> 7);
      }
    } else if (blendMode.equals("overlay")) {
      // does not work very well
      for (int i=1; i < 4; i++) {
        if (_a[i] < 127) {
          _c[i] = _a[i] * _b[i] >> 7;
        } else {
          _c[i] = 255 - ((255 - _a[i]) * (255 - _b[i]) >> 7);
        }
      }
    } else if (blendMode.equals("hard light")) {
      for (int i=1; i < 4; i++) {
        if (_b[i] < 127) {
          _c[i] = _a[i] * _b[i] >> 7;
        } else {
          _c[i] = 255 - ((255 - _a[i]) * (255 - _b[i]) >> 7);
        }
      }
    } else if (blendMode.equals("soft light")) {
      // does not work very well
      for (int i=1; i < 4; i++) {
        int c = _a[i] * _b[i] >> 8;
        _c[i] = c + _a[i] * (255 - ((255 - _a[i]) * (255 - _b[i]) >> 8) - c) >> 8;
      }
    } else if (blendMode.equals("dodge")) {
      for (int i=1; i < 4; i++) {
        if (_b[i] == 255) {
          _c[i] = 255;  
        } else {
          int c = (_a[i] << 8) / (255 - _b[i]);
          if (255 < c) {
            _c[i] = 255;
          } else {
            _c[i] = c;
          }
        }
      }
    } else if (blendMode.equals("burn")) {
      for (int i=1; i < 4; i++) {
        if (_b[i] == 0) {
          _c[i] = 0;  
        } else {
          int c = 255 - (((255 - _a[i]) << 8) / _b[i]);
          if (c < 0) {
            _c[i] = 0;
          } else {
            _c[i] = c;
          }
        }
      }
    } else if (blendMode.equals("cycle")) {
      for (int i=1; i < 4; i++) {
        _c[i] = (_a[i] + _b[i] / 2) % 255;
      }      
    }

    // we could make this max() configurable at one point    
    return (max(_a[0], _b[0]) << 24) | (_c[1] & 0xff) << 16 | (_c[2] & 0xff) << 8 | (_c[3] & 0xff);
  }
  
  void draw()
  {
    // draw black background
    background(0);
    
    // calculate output image dimensions
    int imgW, imgH;
    if (width - out.width < height - out.height) {
      imgW = width;
      imgH = (int)(imgW * ((float)out.height / out.width));
    } else {
      imgH = height;
      imgW = (int)(imgH * ((float)out.width / out.height));      
    }
    
    // draw checkerbox background
    /*
    for (int x=0; x < imgW; x += 20) {
      for (int y=0; y < imgH; y += 20) {
        fill(color(0xee, 0xee, 0xee));
        rect((screenWidth - imgW) / 2 + x, (screenHeight - imgH) / 2 + y, min(10, imgW-x), min(10, imgH-y));
        rect((screenWidth - imgW) / 2 + x + 10, (screenHeight - imgH) / 2 + y + 10, min(10, imgW-x-10), min(10, imgH-y-10));
        fill(color(0xff, 0xff, 0xff));
        rect((screenWidth - imgW) / 2 + x + 10, (screenHeight - imgH) / 2 + y, min(10, imgW-x-10), min(10, imgH-y));
        rect((screenWidth - imgW) / 2 + x, (screenHeight - imgH) / 2 + y + 10, min(10, imgW-x), min(10, imgH-y-10));
      }
    }
    */
    
    // resize and center image
    image(out, (screenWidth - imgW) / 2, (screenHeight - imgH) / 2, imgW, imgH);
  }
  
  void setFirstFrame(String m)
  {
    firstMode = m.toLowerCase();
  }
  
  String getFirstFrame()
  {
    return firstMode;
  }
  
  void setThresh(int t)
  {
    thresh = t;  
  }
  
  int getThresh()
  {
    return thresh;  
  }
  
  String[] blendModes()
  {
    String[] ret = {"normal", "average", "multiply", "screen", "darken", "lighten", "difference", "negation", "exclusion", "overlay", "hard light", "soft light", "dodge", "burn", "cycle"};
    return ret;
  }
  
  void setBlendMode(String m)
  {
    blendMode = m.toLowerCase();
  }
  
  String getBlendMode()
  {
    return blendMode;
  }
  
  void setWindow(int w)
  {
    if (w != bufferSize) {
      bufferSize = w;
      reset();
    }
  }
  
  int getWindow()
  {
    return bufferSize;
  }
  
  float getPercentComplete()
  {
    return ((float)cur / (files.size() + 1)) * 100.0;
  }
  
  String getProgressString()
  {
    if (doAvg) {
      return cur+"/"+(files.size()+1)+" (Average)";
    } else {
      return cur+"/"+(files.size()+1);
    }
  }
  
  void setOutput(boolean frames, boolean movie, float fps)
  {
    if (frames != saveFrames || movie != saveMovie || fps != saveMovieFps) {
      saveFrames = frames;
      saveMovie = movie;
      saveMovieFps = fps;
      reset();
    }
  }
  
  void saveImage()
  {
    // png encoding took 2043ms, tiff 84ms, tga is fast as well
    // unfortunately only png seems to honor the alpha channel
    out.updatePixels();
    out.save(savePath(String.format("%04d", year())+String.format("%02d", month())+String.format("%02d", day())+String.format("%02d", hour())+String.format("%02d", minute())+String.format("%02d", second())+"_snapshot.png"));
  }
    
  boolean isAvg()
  {
    return doAvg;  
  }
  
  void requestAvg()
  {
    requestAvg = true;
    reset();
  }
}
