//
//  ViewController_2D.m
//  FaceLock
//
//  Created by Alan Xu on 3/19/15.
//  Copyright (c) 2015 CBL. All rights reserved.
//

#import "ViewController_2D.h"


@interface ViewController_2D (){
    
}

@end

@implementation ViewController_2D

- (void)viewDidLoad {
    [super viewDidLoad];
    _count = 0;
    _imagename_count = 0;
    CGRect colorFrame = self.view.frame;
    _colorImageView = [[UIImageView alloc]initWithFrame:colorFrame];
    _colorImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:_colorImageView];
    // Create face detector
    _faceCascade = [Utils loadClassifier:@"haarcascade_frontalface_alt2"];
    _eyeCascade = [Utils loadClassifier:@"haarcascade_eye_tree_eyeglasses"];
    //_context = [CIContext contextWithOptions:nil];
    //_faceDectector = [CIDetector detectorOfType:CIDetectorTypeFace context:_context options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    // Call OPENCV video camera
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:_colorImageView];
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset1280x720;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationLandscapeRight;
    self.videoCamera.defaultFPS = 30;
    self.videoCamera.grayscaleMode = NO;
    self.videoCamera.delegate = self;
    
    //if run FaceLock in the ios device first time, uncommend following part.
    /*
    cv::Ptr<cv::face::FaceRecognizer> ini_LBPHFaceRecognizer=cv::face::createLBPHFaceRecognizer();
    [FaceRecognition_2D saveFaceRecognizer:ini_LBPHFaceRecognizer];
    [FaceRecognition_2D loadFaceRecognizer:ini_LBPHFaceRecognizer];
    [FaceRecognition_2D trainFaceRecognizer:ini_LBPHFaceRecognizer andUser:@"xiang" andLabel:1 andTrainNum:9];
    [FaceRecognition_2D trainFaceRecognizer:ini_LBPHFaceRecognizer andUser:@"ha" andLabel:2 andTrainNum:9];
    [FaceRecognition_2D saveFaceRecognizer:ini_LBPHFaceRecognizer];
     */
    
    _LBPHFaceRecognizer=cv::face::createLBPHFaceRecognizer();
    [FaceRecognition_2D loadFaceRecognizer:_LBPHFaceRecognizer];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
//    [_colorImageView setImage:[UIImage imageNamed:@"bg_horizon.jpg"]];
    [self.videoCamera start];
}


#pragma mark -Protocol CvVideoCameraDelegate
#ifdef __cplusplus

- (void) processImage:(cv::Mat &)image{
    _count++;
    cv::Rect roi = cv::Rect(0.25*image.cols,0,image.cols/2,image.rows);
    cv::rectangle(image, roi, cv::Scalar(0, 255, 0), 1, 8);
    cv::Mat image_roi = image(roi);
//    _faceCascade->detectMultiScale(image_roi, _faces, 2, 3, 0, cv::Size(50,50));
//    if (_faces.size() > 0) {
//        NSLog(@"Found %@ faces!\n", @(_faces.size()));
//    }

    // Detection and Recognition every roundly 10 frames
    if (_count == 1) {
        __block cv::Mat image_roi_clone = image_roi.clone();
        //cv::cvtColor(image_roi_clone, image_roi_clone, CV_BGRA2RGB);
        dispatch_queue_t face_recognition_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(face_recognition_queue, ^{
            // Perform long running process
            _faceCascade->detectMultiScale(image_roi_clone, _faces, 2, 3, 0, cv::Size(50,50));
            if (_faces.size() > 0) {
                NSLog(@"Found %@ faces!\n", @(_faces.size()));
            }
            for(int i =0; i <_faces.size(); i++){
                NSString* imagename = [NSString stringWithFormat:@"faces_%.4d.jpg", _imagename_count];
                _imagename_count++;
                cv::Mat face_image=image_roi_clone(_faces[i]).clone();
                cv::cvtColor(image_roi_clone(_faces[i]), face_image, CV_BGRA2RGB);
                [Utils saveMATImage:face_image andName:imagename];
                cv::Mat image_face_roi = image_roi_clone(_faces[i]);
                _eyes.clear();
                _eyeCascade->detectMultiScale(image_face_roi, _eyes);
                if (_eyes.size() > 0) {
                    NSLog(@"Found %@ eyes!\n", @(_eyes.size()));
                }
                
                if (2 == _eyes.size()) {
                    cv::Mat eyeLeft = (cv::Mat_<double>(1,2)<< _eyes[0].x + _eyes[0].width/2, _eyes[0].y + _eyes[0].height/2);
                    cv::Mat eyeRight = (cv::Mat_<double>(1,2)<< _eyes[1].x + _eyes[1].width/2, _eyes[1].y + _eyes[1].height/2);
                    cv::Mat offset =  (cv::Mat_<double>(1,2)<< 0.2, 0.2);
                    cv::Mat dst_sz = (cv::Mat_<double>(1,2)<< 70, 70);
                    cv::Mat normalFaceImg = [Utils normalizeFace:image_roi(_faces[i]) andEyeLeft: eyeLeft andEyeRight: eyeRight andOffset: offset andDstsize: dst_sz];
                    [Utils saveMATImage:normalFaceImg andName:@"NormalFace.jpg"];
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                // Update the UI
                
            });
            _count = 0; //Reset _count
        });
    }

    // Draw face and eyes boundaries
    for(int i =0; i<_faces.size(); i++){
        cv::rectangle(image_roi, _faces[i], cv::Scalar(0, 255, 255), 1, 8);
        cv::Mat image_face_roi = image_roi(_faces[i]);
        for (int j = 0; j<_eyes.size(); j++) {
            cv::Point eye_center( _eyes[j].x + _eyes[j].width/2, _eyes[j].y + _eyes[j].height/2 );
            NSLog(@"%d %d %d %d %d", _count, i, j, eye_center.x, eye_center.y);
            int radius = cvRound((_eyes[j].width + _eyes[j].height)*0.25 );
            cv::circle(image_face_roi, eye_center, radius, cv::Scalar( 255, 0, 255 ), 1, 8);
        }
        NSString *imagename = [NSString stringWithFormat:@"%d.jpg", _imagename_count];
        cv::Mat image_eye_roi = image_roi(_faces[i]).clone();
        [Utils saveMATImage: image_eye_roi andName: imagename];
        
        _eyeCascade->detectMultiScale(image_eye_roi, _eyes);
        NSLog(@"Found %@ eyes!\n", @(_eyes.size()));
        
        for (int j = 0; j<_eyes.size(); j++) {
            cv::Point eye_center( _eyes[j].x + _eyes[j].width/2, _eyes[j].y + _eyes[j].height/2 );
            int radius = cvRound((_eyes[j].width + _eyes[j].height)*0.25 );
            cv::circle(image_eye_roi, eye_center, radius, cv::Scalar( 255, 0, 255 ), 1, 8);
        }
        
        //face recognition
        int label;
        double predicted_confidence;
        cv::Mat newface;
        _LBPHFaceRecognizer->predict(newface,label,predicted_confidence);
        //[_colorImageView setImage:resImage  ];
        NSLog(@"Found %d,with confidence %f \n", label,predicted_confidence);
        if(predicted_confidence>20){//need to update after experiment.
            NSLog(@"Sorry, you can not enter the door.\n");
            AVSpeechSynthesizer *synthesizer = [[AVSpeechSynthesizer alloc]init];
            AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:@"Sorry, you can not enter the door."];
            [utterance setRate:0.1f];
            [synthesizer speakUtterance:utterance];
        }
        else{
            NSLog(@"Welcome Back.\n");
            AVSpeechSynthesizer *synthesizer = [[AVSpeechSynthesizer alloc]init];
            AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:@"Welcome back."];
            [utterance setRate:0.1f];
            [synthesizer speakUtterance:utterance];
        }
        

        

    }
    
    

    /*
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"yiwen10" ofType:@"JPG" ];
    UIImage* resImage = [UIImage imageWithContentsOfFile:filePath];
    cv::Mat newimg=[UIImageCVMatConverter cvMatGrayFromUIImage:resImage];
    int label;
    double predicted_confidence;
    _LBPHFaceRecognizer->predict(newimg,label,predicted_confidence);
    //[_colorImageView setImage:resImage  ];
    NSLog(@"Found %d,with confidence %f \n", label,predicted_confidence);
    if(predicted_confidence>20){//need to update after experiment.
        NSLog(@"Sorry, you can not enter the door.\n");
        AVSpeechSynthesizer *synthesizer = [[AVSpeechSynthesizer alloc]init];
        AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:@"Sorry, you can not enter the door."];
        [utterance setRate:0.1f];
        [synthesizer speakUtterance:utterance];
    }
    else{
        NSLog(@"Welcome Back.\n");
        AVSpeechSynthesizer *synthesizer = [[AVSpeechSynthesizer alloc]init];
        AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:@"Welcome back."];
        [utterance setRate:0.1f];
        [synthesizer speakUtterance:utterance];
    }
    
    */
}

#endif


/*
- (void)startColorCamera {
    BOOL isCamera = [UIImagePickerController isCameraDeviceAvailable:(UIImagePickerControllerCameraDeviceFront)];
    if (!isCamera) {
        NSLog(@"Front Camera unvailuable! Pls Check!");
        return;
    }
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePicker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    //imagePicker.delegate =;
    imagePicker.allowsEditing = YES;
    [self presentViewController:imagePicker animated:YES completion:^{}];
}*/

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
