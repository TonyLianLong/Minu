//
//  ViewController.swift
//  SwiftOpenCV
//
//  Created by Lee Whitney on 10/28/14.
//  Copyright (c) 2014 WhitneyLand. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet var uiview: UIView!
    
    @IBOutlet weak var imageView: UIImageView!
    var detectedRect: NSMutableArray!
    var captureSession: AVCaptureSession?
    var dataOutput: AVCaptureVideoDataOutput?
    var customPreviewLayer: AVCaptureVideoPreviewLayer?
    var selectedImage : UIImage!
    var words : [Dictionary<String, AnyObject>]?
    var capturedImage: UIImage!
    var croppedImage: UIImage!
    var showImage: UIImage!
    //var imgRectRange : [[NSArray]]! = [[NSArray]]();
    var imgGroupRange : [NSArray]! = [NSArray]();
    var currentIndex : Int = 0;
    var rprogressHud : MBProgressHUD!;
    var cropRect: CGRect!;
    let cropWid:CGFloat = 300;
    let cropHei:CGFloat = 100;
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraSession();
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        imageView.isUserInteractionEnabled = true;
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(self.tapImage(_:)))
        imageView.addGestureRecognizer(singleTap);
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews();
        //customPreviewLayer!.frame = CGRect(x:imageView.frame.minX, y:imageView.frame.minY, width:imageView.frame.size.width, height:imageView.frame.size.height);
    }
    func setupCameraSession() {
        // Session
        self.captureSession = AVCaptureSession()
        self.captureSession!.sessionPreset = AVCaptureSessionPresetMedium
        // Capture device
        let inputDevice: AVCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        var deviceInput = AVCaptureDeviceInput()
        // Device input
        //var deviceInput: AVCaptureDeviceInput? = AVCaptureDeviceInput.deviceInputWithDevice(inputDevice, error: error)
        do {
            deviceInput = try AVCaptureDeviceInput(device: inputDevice)
            
        } catch let error as NSError {
            // Handle errors
            print(error)
        }
        if self.captureSession!.canAddInput(deviceInput) {
            self.captureSession!.addInput(deviceInput)
        }
        // Preview
        customPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        customPreviewLayer!.frame = uiview.bounds
        print(imageView.bounds);
        customPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
        customPreviewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.portrait
        uiview.layer.addSublayer(customPreviewLayer!)
        print("Cam layer added")
        
        self.dataOutput = AVCaptureVideoDataOutput()
        self.dataOutput!.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_32BGRA)
        ]
        
        self.dataOutput!.alwaysDiscardsLateVideoFrames = true
        if self.captureSession!.canAddOutput(dataOutput) {
            self.captureSession!.addOutput(dataOutput)
        }
        self.captureSession!.commitConfiguration()
        let queue = DispatchQueue(label:"VideoQueue",attributes:.concurrent)
        //let delegate = VideoDelegate()
        self.dataOutput!.setSampleBufferDelegate(self, queue: queue)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        captureSession?.startRunning();
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated);
        captureSession?.stopRunning();
    }
    func tapImage(_ sender: UITapGestureRecognizer) {
        let loc = sender.location(in:imageView);
        let imageViewSize = imageView.bounds.size;
        let imageSize = imageView.image?.size;
        let scaleX = (imageSize?.width)!/imageViewSize.width;
        let scaleY = (imageSize?.height)!/imageViewSize.height;
        let touchX = loc.x*scaleX;
        let touchY = loc.y*scaleY;
        print("touch X:\(touchX) touch Y:\(touchY)");
        rprogressHud = MBProgressHUD.showAdded(to: uiview, animated: true)!
        rprogressHud.labelText = "Recognizing..."
        rprogressHud.mode = MBProgressHUDModeIndeterminate
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: { () -> Void in
            var ocr = SwiftOCR(fromImage: self.croppedImage)
            ocr.recognize()
            DispatchQueue.main.sync(execute: { () -> Void in
                self.words = ocr.words
                var text = ocr.recognizedText
                self.performSegue(withIdentifier: "ShowRecognition", sender: text);
                self.rprogressHud.hide(true)
            })
        })
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onTakePictureTapped(_ sender: AnyObject) {
        /*var imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        //change here
        imagePicker.allowsEditing = false
        imagePicker.delegate = self
        self.present(imagePicker, animated: true, completion: nil)*/
        let sheet: UIActionSheet = UIActionSheet();
        let title: String = "Please choose an option";
        sheet.title  = title;
        sheet.delegate = self;
        sheet.addButton(withTitle: "Choose Picture");
        sheet.addButton(withTitle: "Take Picture");
        sheet.addButton(withTitle: "Cancel");
        sheet.cancelButtonIndex = 2;
        sheet.show(in: self.view);
    }
    
    func actionSheet(_ sheet: UIActionSheet!, clickedButtonAt buttonIndex: Int) {
        var imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        
        switch buttonIndex{
            
        case 0:
            imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
            imagePicker.allowsEditing = false
            imagePicker.delegate = self
            self.present(imagePicker, animated: true, completion: nil)
            break;
        case 1:
            imagePicker.sourceType = UIImagePickerControllerSourceType.camera
            imagePicker.allowsEditing = false
            imagePicker.delegate = self
            self.present(imagePicker, animated: true, completion: nil)
            break;
        default:
            break;
        }
    }
    
    @IBAction func onRecognizeTapped(_ sender: AnyObject) {
        
        if((self.selectedImage) != nil){
            var progressHud = MBProgressHUD.showAdded(to: view, animated: true)!
            progressHud.labelText = "Detecting..."
            progressHud.mode = MBProgressHUDModeIndeterminate
            
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: { () -> Void in
                var ocr = SwiftOCR(fromImage: self.selectedImage)
                ocr.recognize()
                
                DispatchQueue.main.sync(execute: { () -> Void in
                    self.imageView.image = ocr.groupedImage
                    
                    progressHud.hide(true);
                    
                    var dprogressHud = MBProgressHUD.showAdded(to: self.view, animated: true)!
                    dprogressHud.labelText = "Recognizing..."
                    dprogressHud.mode = MBProgressHUDModeIndeterminate
                    self.words = ocr.words
                    var text = ocr.recognizedText
                    
                    self.performSegue(withIdentifier: "ShowRecognition", sender: text);
                    
                    dprogressHud.hide(true)
                })
            })
        }else {
            var alert = UIAlertView(title: "SwiftOCR", message: "Please select image", delegate: nil, cancelButtonTitle: "Ok")
            alert.show()
        }
    }
    func imageFromSampleBuffer(sampleBuffer : CMSampleBuffer) -> UIImage
    {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        let context = CGContext(data: baseAddress,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue)!
        let cgImage = context.makeImage()!
        
        CVPixelBufferUnlockBaseAddress(imageBuffer,CVPixelBufferLockFlags(rawValue: 0));
        
        return UIImage(cgImage: cgImage)
    }
    func generateUIImagewithoutRects()->UIImage{
        let imageSize = capturedImage?.size;
        let imgwid = (imageSize?.width)!;
        let imghei = (imageSize?.height)!;
        UIGraphicsBeginImageContextWithOptions(CGSize(width:imgwid,height:imghei), false, 0)
        let pathRect = UIBezierPath(rect: cropRect);//Scan field
        pathRect.lineWidth = 3
        UIColor.white.setStroke() //线条颜色
        pathRect.lineJoinStyle = .round //连接点形状
        pathRect.stroke() //绘制边框
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img;
    }
    func generateUIImagewithRects(_ rects:[CGRect])->UIImage{
        let imageSize = capturedImage?.size;
        let imgwid = (imageSize?.width)!;
        let imghei = (imageSize?.height)!;
        UIGraphicsBeginImageContextWithOptions(CGSize(width:imgwid,height:imghei), false, 0)
        for i in 0..<(rects.count){
            //There will be a biggest rect to full field
            if((rects[i].size.height > cropHei/30) && (rects[i].size.height < cropHei) && (rects[i].size.width > cropWid/30) && (rects[i].size.width < cropWid)){
                let pathRect = UIBezierPath(rect: CGRect(origin:CGPoint(x:rects[i].origin.x+cropRect.minX,y:rects[i].origin.y+cropRect.minY), size:rects[i].size))
                pathRect.lineWidth = 5
                UIColor.blue.setStroke() //线条颜色
                pathRect.lineJoinStyle = .round //连接点形状
                pathRect.stroke() //绘制边框
            }
        }
        let pathRect = UIBezierPath(rect: cropRect);//Scan field
        pathRect.lineWidth = 3
        UIColor.white.setStroke() //线条颜色
        pathRect.lineJoinStyle = .round //连接点形状
        pathRect.stroke() //绘制边框
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img;
    }
    /*func processimgRectRange()->UIImage{
        let imageSize = croppedImage?.size
        let imgwid = (imageSize?.width)!;
        let imghei = (imageSize?.height)!;
        var BorW = 0;
        var Bcount = 0;
        var Wcount = 0;
        for i in 0..<3{
            Bcount += imgRectRange[i][0].count;
            Wcount += imgRectRange[i][1].count;
        }
        if(Bcount >= Wcount){
            BorW = 0;
        }else{
            BorW = 1;
        }
        var rects:[CGRect] = [];
        for i in 0..<imgRectRange[2][BorW].count{
            let x2 = ((imgRectRange[2][BorW][i] as! NSArray)[0] as! NSNumber).intValue;
            let y2 = ((imgRectRange[2][BorW][i] as! NSArray)[1] as! NSNumber).intValue;
            let w2 = ((imgRectRange[2][BorW][i] as! NSArray)[2] as! NSNumber).intValue;
            let h2 = ((imgRectRange[2][BorW][i] as! NSArray)[3] as! NSNumber).intValue;
            let rect2 = CGRect(x:x2,y:y2,width:w2,height:h2);
            for j in 0..<imgRectRange[0][BorW].count{
                let x0 = ((imgRectRange[0][BorW][j] as! NSArray)[0] as! NSNumber).intValue;
                let y0 = ((imgRectRange[0][BorW][j] as! NSArray)[1] as! NSNumber).intValue;
                let w0 = ((imgRectRange[0][BorW][j] as! NSArray)[2] as! NSNumber).intValue;
                let h0 = ((imgRectRange[0][BorW][j] as! NSArray)[3] as! NSNumber).intValue;
                let rect0 = CGRect(x:x0,y:y0,width:w0,height:h0);
                if(rect2.intersects(rect0)){
                    rects.append(rect2);
                    continue;
                }
            }
            for j in 0..<imgRectRange[1][BorW].count{
                let x1 = ((imgRectRange[1][BorW][j] as! NSArray)[0] as! NSNumber).intValue;
                let y1 = ((imgRectRange[1][BorW][j] as! NSArray)[1] as! NSNumber).intValue;
                let w1 = ((imgRectRange[1][BorW][j] as! NSArray)[2] as! NSNumber).intValue;
                let h1 = ((imgRectRange[1][BorW][j] as! NSArray)[3] as! NSNumber).intValue;
                let rect1 = CGRect(x:x1,y:y1,width:w1,height:h1);
                if(rect2.intersects(rect1)){
                    rects.append(rect2);
                    continue;
                }
            }
        }
        return generateUIImagewithRects(rects);
    }*/
    func processimgGroupRange()->UIImage{
        var rects:[CGRect] = [CGRect]();
        for i in 0..<imgGroupRange[2].count{
            rects.append(imgGroupRange[2][i] as! CGRect);
        }
        return generateUIImagewithRects(rects);//unprocessed
    }
    func crop(_ contextImage:UIImage, _ rect:CGRect)->UIImage {
        //let contextImage: UIImage = UIImage(cgImage: image.cgImage!)
        let contextSize: CGSize = contextImage.size
        // Create bitmap image from context using the rect
        let imageRef: CGImage = contextImage.cgImage!.cropping(to: rect)!
        // Create a new image based on the imageRef and rotate back to the original orientation
        let croppedImage: UIImage = UIImage(cgImage: imageRef, scale: contextImage.scale, orientation: contextImage.imageOrientation)
        return croppedImage
    }
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!)
    {
        print("Get")
        capturedImage = imageFromSampleBuffer(sampleBuffer:sampleBuffer)
        capturedImage = capturedImage.easyTurn()!
        cropRect = CGRect(x:capturedImage.size.width/2-cropWid/2,y:capturedImage.size.height/2-cropHei/2,width:cropWid,height:cropHei);
        croppedImage = crop(capturedImage,cropRect)
        //let imageSize = capturedImage?.size
        var ocr = SwiftOCR(fromImage: self.croppedImage)
        let detectedGroupArr = ocr.detectGroup();
        imgGroupRange.append(detectedGroupArr);
        if(imgGroupRange.count==3){
            showImage = generateUIImagewithoutRects();//processimgGroupRange();
            DispatchQueue.main.async(execute: { () -> Void in
                self.imageView.image = self.showImage;
            });
            imgGroupRange = [NSArray]();
             //[[NSArray]]();
        }
        /*let detectedRectArr = ocr.detectRect();
        imgRectRange.append(detectedRectArr);
        if(imgRectRange.count==3){
            showImage = processimgRectRange();
            DispatchQueue.main.async(execute: { () -> Void in
                self.imageView.image = self.showImage;
            })
            imgRectRange = [[NSArray]]();
        }*/
        /*if(detectedRectArr[0].count >= detectedRectArr[1].count){
            detectedRect = detectedRectArr[0];
        }else{
            detectedRect = detectedRectArr[1];
        }
        print(((detectedRect[0] as! NSArray)[0] as! NSNumber).intValue)
        print("Image width:\(imgwid)");
        print("Image height:\(imghei)");
        UIGraphicsBeginImageContextWithOptions(CGSize(width:imgwid,height:imghei), false, 0)
        let pathRect = UIBezierPath(rect: CGRect(x: 0, y: 0, width: imgwid, height:imghei))
        //For edge
        pathRect.lineWidth = 3
        UIColor.blue.setStroke() //线条颜色
        pathRect.stroke() //绘制边框
        print(detectedRect.count)
        for i in 0..<(detectedRect.count){
            let x = ((detectedRect[i] as! NSArray)[0] as! NSNumber).intValue;
            let y = ((detectedRect[i] as! NSArray)[1] as! NSNumber).intValue;
            let w = ((detectedRect[i] as! NSArray)[2] as! NSNumber).intValue;
            let h = ((detectedRect[i] as! NSArray)[3] as! NSNumber).intValue;
            /*print("x \(x)");
            print("y \(y)");
            print("w \(w)");
            print("h \(h)");*/
            let pathRect = UIBezierPath(rect: CGRect(x: x, y: y, width: w, height: h))
            pathRect.lineWidth = 3
            UIColor.green.setStroke() //线条颜色
            pathRect.lineJoinStyle = .round //连接点形状
            pathRect.stroke() //绘制边框
        }
        capturedImage = UIGraphicsGetImageFromCurrentImageContext()
        //Replace original image
        UIGraphicsEndImageContext()*/
    }
    func imagePickerController(_ picker: UIImagePickerController!, didFinishPickingImage image: UIImage!, editingInfo: NSDictionary!) {
        print("Image selected");
        selectedImage = image;
        picker.dismiss(animated: true, completion: nil);
        imageView.image = selectedImage;
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var vc =  segue.destination as! DetailViewController
        vc.recognizedText = sender as! String!
    }
}

