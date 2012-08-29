//
//  main.cpp
//  CKObjectTrackerDemo
//
//  Created by Christoph Kapffer on 17.08.12.
//  Copyright (c) 2012 HTW Berlin. All rights reserved.
//

#include <iostream>
#include <opencv2/opencv.hpp>
#include "ObjectTracker.h"
#include "ObjectTrackerDebugger.h"

using namespace std;
using namespace cv;
using namespace ck;

int main(int argc, const char * argv[])
{
    if(argc != 1) {
        cout << "This program demonstrates the CKObjectTracker library.\n"
        << "Usage: " << argv[0] << " [-help]\n"
        << "You don't need to provide any parameters. The default capture device is used for tracking\n"
        << "-help prints this message\n."
        << "While tracking you can press following keys:\n"
        << "k - produces a key frame, which will represents the object to be tracked.\n"
        << "q - stops playback and quits the application.\n"
        << endl;
        return -1;
    }
    
    VideoCapture capture(0); // open the default camera
    if(!capture.isOpened()) {
        cout << "Could not find a capture device." << endl;
        return -1;
    }
    
    ObjectTracker tracker = ObjectTracker();

    TrackerOutput output;
    TrackerDebugInfo debugInfo;
    vector<TrackerDebugInfoStripped> completeInfo;
    
    Mat frame;
    bool firstRun = true;
    bool endCapture = false;    
    while (!endCapture) {
        if (!capture.read(frame)) {
            cout << "Capture error." << endl;
            endCapture = true;
        }
        
        tracker.trackObjectInVideo(frame, output, debugInfo);
        vector<pair<string, Mat> > debugImages = ObjectTrackerDebugger::debugImages(debugInfo, true, false, true, true, true);
        for (int i = 0; i < debugImages.size(); i++) {
            pair<string, Mat> item = debugImages[i];
            if (firstRun) { namedWindow(item.first); }
            imshow(item.first, item.second);
        }
        firstRun = false;
        
        TrackerDebugInfoStripped stripped = TrackerDebugInfoStripped(debugInfo);
        cout << ObjectTrackerDebugger::debugString(stripped) << endl;
        completeInfo.push_back(stripped);
        
        char key = (char)waitKey(30);
        switch(key)
        {
            case 'k':
                cout << "Took keyframe." << endl;
                tracker.setObject(frame);
                break;
            case 'q':
                cout << "Done." << endl;
                endCapture = true;
                break;
            default:
                break;
        }
    }
    
    cout << "\n" << ObjectTrackerDebugger::debugString(completeInfo) << endl;
    
//    Mat edges;
//    namedWindow("edges",1);
//    for(;;)
//    {
//        Mat frame;
//        capture >> frame; // get a new frame from camera
//        cvtColor(frame, edges, CV_BGR2GRAY);
//        GaussianBlur(edges, edges, Size(7,7), 1.5, 1.5);
//        Canny(edges, edges, 0, 30, 3);
//        imshow("edges", edges);
//        if(waitKey(30) >= 0) break;
//    }
    
    return 0;
}

