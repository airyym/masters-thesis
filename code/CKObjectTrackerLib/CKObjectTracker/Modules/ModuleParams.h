//
//  ModuleParams.h
//  CKObjectTrackerLib
//
//  Created by Christoph Kapffer on 25.08.12.
//  Copyright (c) 2012 HTW Berlin. All rights reserved.
//

#ifndef CKObjectTrackerLib_ModuleParams_h
#define CKObjectTrackerLib_ModuleParams_h

#include "ModuleTypes.h"

namespace ck {
    
    struct ModuleParams {
        ModuleType successor;            // OUT: abstract             IN: abstract
        cv::Mat sceneImage;              // OUT: -                    IN: detection, validation, tracking
        cv::Rect searchRect;             // OUT: detection            IN: validation
        cv::Mat homography;              // OUT: validation, tracking IN: tracking
        std::vector<cv::Point2f> points; // OUT: validation, tracking IN: tracking
        bool isObjectPresent;            // OUT: validation, tracking IN: -
        
        ModuleParams() : successor(MODULE_TYPE_EMPTY), homography(cv::Mat()) {};
    };
    
} // end of namespace

#endif